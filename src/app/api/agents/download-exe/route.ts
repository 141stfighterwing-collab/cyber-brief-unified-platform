import { NextRequest, NextResponse } from 'next/server'
import { readFileSync, existsSync } from 'fs'
import { join } from 'path'
import { rateLimit, getClientIp, rateLimitResponse } from '@/lib/rate-limit'
import { checkAuth } from '@/lib/auth-check'

// Rate limiter: 20 requests per 5 minutes per IP
const downloadRateLimit = rateLimit({ maxRequests: 20, windowMs: 5 * 60 * 1000 })

// GET /api/agents/download-exe
// Serves the CBUP Agent PowerShell script + build script as a downloadable bundle
export async function GET(request: NextRequest) {
  try {
    // ─── Rate Limiting ───────────────────────────────────────────────────
    const clientIp = getClientIp(request)
    const rlResult = downloadRateLimit.check(clientIp)
    if (!rlResult.allowed) {
      return rateLimitResponse(rlResult)
    }

    // ─── Admin Auth Check ────────────────────────────────────────────────
    const authFail = checkAuth(request)
    if (authFail) return authFail

    const agentDir = join(process.cwd(), 'agent')
    const agentScript = join(agentDir, 'CBUP-Agent.ps1')
    const buildScript = join(agentDir, 'build-exe.ps1')

    if (!existsSync(agentScript) || !existsSync(buildScript)) {
      return NextResponse.json(
        { error: 'Agent files not found' },
        { status: 404 }
      )
    }

    const agentContent = readFileSync(agentScript, 'utf-8')
    const buildContent = readFileSync(buildScript, 'utf-8')

    // Return the PS1 agent script directly for download
    return new NextResponse(agentContent, {
      status: 200,
      headers: {
        'Content-Type': 'text/plain; charset=utf-8',
        'Content-Disposition': 'attachment; filename="CBUP-Agent.ps1"',
        'Cache-Control': 'no-cache',
        'X-Content-Type-Options': 'nosniff',
      },
    })
  } catch (error) {
    return NextResponse.json({ error: 'Failed to serve agent files' }, { status: 500 })
  }
}
