import { NextRequest, NextResponse } from 'next/server'
import { readFileSync, existsSync } from 'fs'
import { join } from 'path'
import { createHash } from 'crypto'

// ─── Signature Generation ────────────────────────────────────────────────────

const CBUP_VERSION = '2.1.0'
const CBUP_SIGNER = 'CBUP Security Engineering'

function generateSignature(token: string, companyName: string, version: string): string {
  const data = `${token}|${companyName}|${version}|CBUP`
  return createHash('sha256').update(data).digest('hex')
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
  return `$CBUP_SIGNATURE_COMPANY = '${block.companyName}'
$CBUP_SIGNATURE_TENANT_ID = '${block.tenantId}'
$CBUP_SIGNATURE_VERSION = '${block.version}'
$CBUP_SIGNATURE_FINGERPRINT = '${block.signature}'
$CBUP_SIGNATURE_TIMESTAMP = '${block.timestamp}'
$CBUP_SIGNATURE_SIGNED_BY = '${block.signedBy}'
`
}

// GET /api/agents/install-script?platform=linux|windows|windows-exe|windows-tray|docker&token=TOKEN&companyId=ID&companyName=NAME
// Serves agent installation scripts for download/deployment with optional pre-authenticated token
// and company-specific digital signature embedding
export async function GET(request: NextRequest) {
  try {
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

    // Build signature block (backward compatible: generic signature if no companyName)
    const effectiveCompanyName = companyName || 'CBUP Generic Distribution'
    const effectiveCompanyId = companyId || token || 'unknown'
    const signatureBlock = buildSignatureBlock(effectiveCompanyId, effectiveCompanyName, token)

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
        const tokenExport = token
          ? `export CBUP_AUTH_TOKEN="${token}"\nexport CBUP_TENANT_NAME="${effectiveCompanyName}"\nexport CBUP_SIGNATURE="${signatureBlock.signature}"\n`
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
        const tokenHeader = token
          ? `# [CBUP] Pre-authenticated registration token: ${token}\n# This token will be automatically used during registration.\n`
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
        const tokenHeader = token
          ? `# [CBUP] Pre-authenticated registration token: ${token}\n# After building, run: .\\dist\\CBUP-Agent.exe -ServerUrl <URL> -Token ${token} -Install\n`
          : ''

        // Inject EXE metadata variables that the build script can use
        // These set Company, Product, Version, Description for the compiled EXE
        const exeMetadata = `$CBUP_EXE_COMPANY = '${effectiveCompanyName}'
$CBUP_EXE_PRODUCT = 'CBUP Agent - ${effectiveCompanyName}'
$CBUP_EXE_VERSION = '${CBUP_VERSION}'
$CBUP_EXE_DESCRIPTION = 'CBUP Endpoint Agent for ${effectiveCompanyName} | Signed: ${signatureBlock.signature}'
`

        scriptContent =
          signatureComment +
          tokenHeader +
          exeMetadata +
          signatureVars +
          scriptContent

        return new NextResponse(scriptContent, {
          status: 200,
          headers: {
            'Content-Type': 'text/plain; charset=utf-8',
            'Content-Disposition':
              'attachment; filename="build-exe.ps1"',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            Pragma: 'no-cache',
            Expires: '0',
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
        const tokenHeader = token
          ? `# [CBUP] Pre-authenticated registration token: ${token}\n# The tray app monitors the agent service. Use the main agent script/EXE with the token.\n`
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
          },
        })
      }

      // ─── Docker ──────────────────────────────────────────────────────────
      case 'docker': {
        const serverOrigin = request.headers.get('origin') || 'https://your-cbup-server.com'
        const signatureComment = formatSignatureAsComment(signatureBlock, 'docker')
        const envTokenLine = token ? `-e CBUP_AUTH_TOKEN='${token}' \\\n  -e CBUP_TENANT_NAME='${effectiveCompanyName}' \\\n  -e CBUP_SIGNATURE='${signatureBlock.signature}'` : ''
        const dockerCompose = `${signatureComment}# CBUP Agent - Docker Deployment
# ==================================================
${token ? `# Signed for: ${effectiveCompanyName}` : '# Unsigned distribution'}
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
      - CBUP_SERVER_URL=${serverOrigin}${token ? `\n      - CBUP_AUTH_TOKEN=${token}\n      - CBUP_TENANT_NAME=${effectiveCompanyName}\n      - CBUP_SIGNATURE=${signatureBlock.signature}` : ''}
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
${token ? `- This build is signed for: ${effectiveCompanyName} (${signatureBlock.signature.slice(0, 16)}...)` : '- Set CBUP_AUTH_TOKEN to your tenant registration token'}
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
