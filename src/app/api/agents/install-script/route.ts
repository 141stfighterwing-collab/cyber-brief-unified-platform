import { NextRequest, NextResponse } from 'next/server'
import { readFileSync, existsSync } from 'fs'
import { join } from 'path'
import { createHash, randomBytes, createHmac } from 'crypto'
import { rateLimit, getClientIp, rateLimitResponse } from '@/lib/rate-limit'
import { checkAuth } from '@/lib/auth-check'

// ─── Signature Generation (HMAC-SHA256) ──────────────────────────────────

const CBUP_VERSION = '2.4.0'
const CBUP_SIGNER = 'CBUP Security Engineering'

// HMAC secret generated once at module load, stored in process.env for consistency
if (!process.env.CBUP_HMAC_SECRET) {
  process.env.CBUP_HMAC_SECRET = randomBytes(32).toString('hex')
  console.warn(
    '[CBUP SECURITY] No CBUP_HMAC_SECRET env var set. Generated a random HMAC secret for this session.\n' +
    '[CBUP SECURITY] Set CBUP_HMAC_SECRET env var for persistent signature verification across restarts.'
  )
}
const CBUP_HMAC_SECRET = process.env.CBUP_HMAC_SECRET

function generateSignature(token: string, companyName: string, version: string): string {
  const data = `${token}|${companyName}|${version}|CBUP`
  return createHmac('sha256', CBUP_HMAC_SECRET).update(data).digest('hex')
}

interface SignatureBlock {
  tenantId: string
  companyName: string
  signature: string
  signedBy: string
  version: string
  timestamp: string
}

function buildSignatureBlock(companyId: string, companyName: string, token: string): SignatureBlock {
  const signature = generateSignature(token, companyName, CBUP_VERSION)
  const timestamp = new Date().toISOString()
  return {
    tenantId: companyId || token,
    companyName,
    signature,
    signedBy: CBUP_SIGNER,
    version: CBUP_VERSION,
    timestamp,
  }
}

function formatSignatureAsComment(
  block: SignatureBlock,
  lang: 'powershell' | 'bash' | 'docker' = 'bash'
): string {
  const lines: string[] = []
  const prefix = lang === 'powershell' ? '# ' : lang === 'docker' ? '# ' : '# '
  lines.push(`${prefix}=================================================================`)
  lines.push(`${prefix} CBUP Company-Signed Distribution`)
  lines.push(`${prefix}=================================================================`)
  lines.push(`${prefix} Company   : ${block.companyName}`)
  lines.push(`${prefix} Tenant ID : ${block.tenantId}`)
  lines.push(`${prefix} Version   : ${block.version}`)
  lines.push(`${prefix} Signed By : ${block.signedBy}`)
  lines.push(`${prefix} Signature : ${block.signature}`)
  lines.push(`${prefix} Timestamp : ${block.timestamp}`)
  lines.push(`${prefix}=================================================================`)
  lines.push(``)
  return lines.join('\n')
}

function formatSignatureAsPsVariables(
  block: SignatureBlock
): string {
  // Escape single quotes for PowerShell single-quoted strings
  const esc = (s: string) => s.replace(/'/g, "''")
  return `$CBUP_SIGNATURE_COMPANY = '${esc(block.companyName)}'
$CBUP_SIGNATURE_TENANT_ID = '${esc(block.tenantId)}'
$CBUP_SIGNATURE_VERSION = '${esc(block.version)}'
$CBUP_SIGNATURE_FINGERPRINT = '${esc(block.signature)}'
$CBUP_SIGNATURE_TIMESTAMP = '${esc(block.timestamp)}'
$CBUP_SIGNATURE_SIGNED_BY = '${esc(block.signedBy)}'
`
}

// ─── Input Validation ─────────────────────────────────────────────────────

const ALLOWED_PLATFORMS = new Set(['linux', 'windows', 'windows-exe', 'windows-tray', 'docker'])
const TOKEN_REGEX = /^[a-zA-Z0-9_-]{8,128}$/
const COMPANY_NAME_REGEX = /^[a-zA-Z0-9][a-zA-Z0-9 '._\-]{0,99}$/

// Rate limiter: 30 requests per 5 minutes per IP
const installScriptRateLimit = rateLimit({ maxRequests: 30, windowMs: 5 * 60 * 1000 })

/**
 * Aggressively sanitize a string for safe embedding in scripts.
 * Strips null bytes, control characters (except newline/tab), and trims.
 */
function sanitizeForScript(value: string): string {
  return value
    .replace(/\x00/g, '')               // Remove null bytes
    .replace(/[\x01-\x08\x0b\x0c\x0e-\x1f\x7f]/g, '') // Remove control chars except \t (0x09), \n (0x0a), \r (0x0d)
    .trim()
}

// GET /api/agents/install-script?platform=linux|windows|windows-exe|windows-tray|docker&token=TOKEN&companyId=ID&companyName=NAME
// Serves agent installation scripts for download/deployment with optional pre-authenticated token
// and company-specific digital signature embedding
export async function GET(request: NextRequest) {
  try {
    // ─── Rate Limiting ───────────────────────────────────────────────────
    const clientIp = getClientIp(request)
    const rlResult = installScriptRateLimit.check(clientIp)
    if (!rlResult.allowed) {
      return rateLimitResponse(rlResult)
    }

    // ─── Input Validation ────────────────────────────────────────────────
    const { searchParams } = new URL(request.url)
    const platform = searchParams.get('platform')
    const token = searchParams.get('token') || ''
    const companyId = searchParams.get('companyId') || ''
    const companyName = searchParams.get('companyName') || ''
    const signatureOnly = searchParams.get('signature') === 'true'

    if (!platform) {
      return NextResponse.json(
        {
          success: false,
          error:
            'Missing required query param: platform. Supported: linux, windows, windows-exe, windows-tray, docker',
        },
        { status: 400 }
      )
    }

    // Whitelist platform parameter
    if (!ALLOWED_PLATFORMS.has(platform)) {
      return NextResponse.json(
        {
          success: false,
          error: `Invalid platform: ${sanitizeForScript(platform)}. Supported: linux, windows, windows-exe, windows-tray, docker`,
        },
        { status: 400 }
      )
    }

    // Validate token format (if provided)
    if (token && !TOKEN_REGEX.test(token)) {
      return NextResponse.json(
        {
          success: false,
          error: 'Invalid token format. Token must be 8-128 alphanumeric characters, underscores, or hyphens.',
        },
        { status: 400 }
      )
    }

    // Validate companyName format (if provided)
    if (companyName && !COMPANY_NAME_REGEX.test(companyName)) {
      return NextResponse.json(
        {
          success: false,
          error: 'Invalid company name. Must be 1-100 chars, alphanumeric with spaces, hyphens, apostrophes, dots, or underscores.',
        },
        { status: 400 }
      )
    }

    // Build signature block (backward compatible: generic signature if no companyName)
    const effectiveCompanyName = sanitizeForScript(companyName || 'CBUP Generic Distribution')
    const effectiveCompanyId = sanitizeForScript(companyId || token || 'unknown')
    const safeToken = sanitizeForScript(token)
    const signatureBlock = buildSignatureBlock(effectiveCompanyId, effectiveCompanyName, safeToken)

    // ─── Content Security Policy Headers ─────────────────────────────────
    const securityHeaders = {
      'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'",
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'Referrer-Policy': 'no-referrer',
      'Permissions-Policy': 'geolocation=(), microphone=(), camera=()',
    }

    // ─── Signature-only metadata endpoint ───────────────────────────────────
    if (signatureOnly) {
      return new NextResponse(JSON.stringify(signatureBlock, null, 2), {
        status: 200,
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Disposition': 'attachment; filename="cbup-signature.json"',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          Pragma: 'no-cache',
          Expires: '0',
          ...securityHeaders,
        },
      })
    }

    const agentDir = join(process.cwd(), 'agent')

    switch (platform) {
      // ─── Linux ───────────────────────────────────────────────────────────
      case 'linux': {
        const scriptPath = join(agentDir, 'cbup-agent-linux.sh')
        if (!existsSync(scriptPath)) {
          return NextResponse.json(
            { success: false, error: 'Linux agent script not found on server' },
            { status: 404 }
          )
        }

        let scriptContent = readFileSync(scriptPath, 'utf-8')

        // Build the header with signature + token
        const signatureComment = formatSignatureAsComment(signatureBlock, 'bash')
        const tokenExport = safeToken
          ? `export CBUP_AUTH_TOKEN="${safeToken}"\nexport CBUP_TENANT_NAME="${effectiveCompanyName}"\nexport CBUP_SIGNATURE="${signatureBlock.signature}"\n`
          : ''

        // Insert after the shebang line if present
        if (scriptContent.startsWith('#!/')) {
          const shebangEnd = scriptContent.indexOf('\n') + 1
          scriptContent =
            scriptContent.slice(0, shebangEnd) +
            signatureComment +
            (tokenExport ? `[CBUP] Pre-authenticated registration token\n${tokenExport}` : '') +
            scriptContent.slice(shebangEnd)
        } else {
          scriptContent = signatureComment + tokenExport + scriptContent
        }

        return new NextResponse(scriptContent, {
          status: 200,
          headers: {
            'Content-Type': 'text/x-shellscript; charset=utf-8',
            'Content-Disposition':
              'attachment; filename="cbup-agent-linux.sh"',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            Pragma: 'no-cache',
            Expires: '0',
            ...securityHeaders,
          },
        })
      }

      // ─── Windows PowerShell ──────────────────────────────────────────────
      case 'windows': {
        const scriptPath = join(agentDir, 'CBUP-Agent.ps1')
        if (!existsSync(scriptPath)) {
          return NextResponse.json(
            { success: false, error: 'Windows agent script not found on server' },
            { status: 404 }
          )
        }

        let scriptContent = readFileSync(scriptPath, 'utf-8')

        // Build the header with signature + token
        const signatureComment = formatSignatureAsComment(signatureBlock, 'powershell')
        const tokenHeader = safeToken
          ? `# [CBUP] Pre-authenticated registration token: ${safeToken}\n# This token will be automatically used during registration.\n`
          : ''

        if (scriptContent.startsWith('#Requires') || scriptContent.startsWith('<#')) {
          // Insert before the param block
          const paramMatch = scriptContent.match(/^param\s*\(/m)
          if (paramMatch && paramMatch.index) {
            scriptContent =
              scriptContent.slice(0, paramMatch.index) +
              signatureComment +
              tokenHeader +
              scriptContent.slice(paramMatch.index)
          } else {
            scriptContent = signatureComment + tokenHeader + scriptContent
          }
        } else {
          scriptContent = signatureComment + tokenHeader + scriptContent
        }

        return new NextResponse(scriptContent, {
          status: 200,
          headers: {
            'Content-Type': 'text/plain; charset=utf-8',
            'Content-Disposition':
              'attachment; filename="CBUP-Agent.ps1"',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            Pragma: 'no-cache',
            Expires: '0',
            ...securityHeaders,
          },
        })
      }

      // ─── Windows EXE Build Script ────────────────────────────────────────
      case 'windows-exe': {
        const scriptPath = join(agentDir, 'build-exe.ps1')
        if (!existsSync(scriptPath)) {
          return NextResponse.json(
            { success: false, error: 'Windows EXE build script not found on server' },
            { status: 404 }
          )
        }

        let scriptContent = readFileSync(scriptPath, 'utf-8')

        // Build the signature header with CBUP-SIGNATURE fingerprint comment
        const signatureComment = formatSignatureAsComment(signatureBlock, 'powershell')
        const signatureVars = formatSignatureAsPsVariables(signatureBlock)
        const tokenHeader = safeToken
          ? `# [CBUP] Pre-authenticated registration token: ${safeToken}\n# After building, run: .\\dist\\CBUP-Agent.exe -ServerUrl <URL> -Token ${safeToken} -Install\n`
          : ''

        // Inject EXE metadata variables that the build script can use
        // These set Company, Product, Version, Description for the compiled EXE
        // Escape single quotes to prevent breaking PowerShell string literals
        const safeCompanyName = effectiveCompanyName.replace(/'/g, "''")
        const safeSignature = signatureBlock.signature.replace(/'/g, "''")

        // Inject server origin so build-exe.ps1 can auto-download agent source files
        const serverOrigin = request.headers.get('host')
          ? `${request.headers.get('x-forwarded-proto') || 'http'}://${request.headers.get('host')}`
          : 'http://localhost:3001'
        const safeServerOrigin = serverOrigin.replace(/'/g, "''")

        const exeMetadata = `$CBUP_SERVER_ORIGIN = '${safeServerOrigin}'
$CBUP_EXE_COMPANY = '${safeCompanyName}'
$CBUP_EXE_PRODUCT = 'CBUP Agent - ${safeCompanyName}'
$CBUP_EXE_VERSION = '${CBUP_VERSION}'
$CBUP_EXE_DESCRIPTION = 'CBUP Endpoint Agent for ${safeCompanyName} | Signed: ${safeSignature}'
`

        // CRITICAL: Variable assignments MUST be inserted AFTER the param() block.
        // PowerShell requires [CmdletBinding()] and param() to be the first
        // non-comment executable statements. Placing $var = '...' before them
        // causes: "Unexpected attribute 'CmdletBinding'" parse error.
        // Strategy: prepend only comments, then find the end of the param()
        // block and insert variables after it.

        // 1. Prepend only comment-based headers (safe before #Requires / param)
        scriptContent = signatureComment + tokenHeader + scriptContent

        // 2. Find the end of the param() block using parenthesis balancing.
        //    The param block contains nested parens (e.g. [Parameter(HelpMessage="...")])
        //    so a simple regex won't work. We count open/close parens from 'param('.
        const paramStart = scriptContent.indexOf('param(')
        if (paramStart >= 0) {
          let depth = 0
          let paramCloseIdx = -1
          for (let i = paramStart; i < scriptContent.length; i++) {
            if (scriptContent[i] === '(') depth++
            else if (scriptContent[i] === ')') {
              depth--
              if (depth === 0) {
                paramCloseIdx = i
                break
              }
            }
          }
          if (paramCloseIdx > 0) {
            // Find the end of the line containing the closing ')'
            const lineEnd = scriptContent.indexOf('\n', paramCloseIdx)
            const insertPoint = lineEnd >= 0 ? lineEnd + 1 : paramCloseIdx + 1
            scriptContent =
              scriptContent.slice(0, insertPoint) +
              '\n# --- Auto-injected company signature metadata ---\n' +
              exeMetadata +
              signatureVars +
              scriptContent.slice(insertPoint)
          }
        } else {
          // Fallback: if we can't find param block, wrap variables in a subexpression
          // so they don't break [CmdletBinding()]. This is a safety net that should
          // never be hit with the standard build-exe.ps1.
          console.warn('[CBUP] Could not find param() block in build-exe.ps1, using fallback insertion')
        }

        return new NextResponse(scriptContent, {
          status: 200,
          headers: {
            'Content-Type': 'text/plain; charset=utf-8',
            'Content-Disposition':
              'attachment; filename="build-exe.ps1"',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            Pragma: 'no-cache',
            Expires: '0',
            ...securityHeaders,
          },
        })
      }

      // ─── Windows System Tray ─────────────────────────────────────────────
      case 'windows-tray': {
        const scriptPath = join(agentDir, 'CBUP-Agent-Tray.ps1')
        if (!existsSync(scriptPath)) {
          return NextResponse.json(
            { success: false, error: 'Windows tray script not found on server' },
            { status: 404 }
          )
        }

        let scriptContent = readFileSync(scriptPath, 'utf-8')

        const signatureComment = formatSignatureAsComment(signatureBlock, 'powershell')
        const tokenHeader = safeToken
          ? `# [CBUP] Pre-authenticated registration token: ${safeToken}\n# The tray app monitors the agent service. Use the main agent script/EXE with the token.\n`
          : ''

        scriptContent = signatureComment + tokenHeader + scriptContent

        return new NextResponse(scriptContent, {
          status: 200,
          headers: {
            'Content-Type': 'text/plain; charset=utf-8',
            'Content-Disposition':
              'attachment; filename="CBUP-Agent-Tray.ps1"',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            Pragma: 'no-cache',
            Expires: '0',
            ...securityHeaders,
          },
        })
      }

      // ─── Docker ──────────────────────────────────────────────────────────
      case 'docker': {
        const serverOrigin = request.headers.get('origin') || 'https://your-cbup-server.com'
        const signatureComment = formatSignatureAsComment(signatureBlock, 'docker')
        const envTokenLine = safeToken ? `-e CBUP_AUTH_TOKEN='${safeToken}' \\\n  -e CBUP_TENANT_NAME='${effectiveCompanyName}' \\\n  -e CBUP_SIGNATURE='${signatureBlock.signature}'` : ''
        const dockerCompose = `${signatureComment}# CBUP Agent - Docker Deployment
# ==================================================
${safeToken ? `# Signed for: ${effectiveCompanyName}` : '# Unsigned distribution'}
#
# Option 1: Docker Run (single container)
# --------------------------------------------------
docker run -d \\
  --name cbup-agent \\
  --restart unless-stopped \\
  -e CBUP_SERVER_URL='${serverOrigin}' \\
${envTokenLine || '  # -e CBUP_AUTH_TOKEN=YOUR_TOKEN \\'}
  -v /var/run/docker.sock:/var/run/docker.sock:ro \\
  -v /proc:/host/proc:ro \\
  -v /sys:/host/sys:ro \\
  cbup/agent:latest

#
# Option 2: Docker Compose
# --------------------------------------------------
cat > docker-compose.yml << 'COMPOSE_EOF'
version: "3.8"

services:
  cbup-agent:
    image: cbup/agent:latest
    container_name: cbup-agent
    restart: unless-stopped
    environment:
      - CBUP_SERVER_URL=${serverOrigin}${safeToken ? `\n      - CBUP_AUTH_TOKEN=${safeToken}\n      - CBUP_TENANT_NAME=${effectiveCompanyName}\n      - CBUP_SIGNATURE=${signatureBlock.signature}` : ''}
      - CBUP_LOG_LEVEL=info
      - CBUP_INTERVAL=30
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
    security_opt:
      - no-new-privileges:true
    read_only: true
    cap_drop:
      - ALL
    cap_add:
      - NET_ADMIN
      - SYS_PTRACE
COMPOSE_EOF

docker compose up -d

#
# Notes:
#   - Replace the CBUP_SERVER_URL with your actual CBUP portal URL
${safeToken ? `- This build is signed for: ${effectiveCompanyName} (${signatureBlock.signature.slice(0, 16)}...)` : '- Set CBUP_AUTH_TOKEN to your tenant registration token'}
#   - Requires Docker 20.10+ and Docker Compose v2+
#   - The agent needs host access for process/network monitoring
#   - Use --privileged mode only if EDR deep scanning is required
#
# Supported environment variables:
#   CBUP_SERVER_URL   CBUP Portal URL (required)
#   CBUP_AUTH_TOKEN   Pre-authenticated registration token
#   CBUP_TENANT_NAME  Company/tenant name for identification
#   CBUP_SIGNATURE    Company-specific signature fingerprint
#   CBUP_LOG_LEVEL    Logging level: debug, info, warn, error (default: info)
#   CBUP_INTERVAL     Telemetry interval in seconds (default: 30)
#   CBUP_SCAN_INTERVAL EDR scan interval in minutes (default: 60, 0=disabled)
#
# Version: ${CBUP_VERSION}
`

        return new NextResponse(dockerCompose, {
          status: 200,
          headers: {
            'Content-Type': 'text/plain; charset=utf-8',
            'Content-Disposition':
              'attachment; filename="cbup-agent-docker.sh"',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            Pragma: 'no-cache',
            Expires: '0',
            ...securityHeaders,
          },
        })
      }

      default: {
        return NextResponse.json(
          {
            success: false,
            error: `Unsupported platform: ${platform}. Supported: linux, windows, windows-exe, windows-tray, docker`,
          },
          { status: 400 }
        )
      }
    }
  } catch (error) {
    console.error('Install script error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}
