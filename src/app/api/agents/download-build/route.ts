import { NextRequest, NextResponse } from 'next/server'
import { readFileSync, existsSync } from 'fs'
import { join } from 'path'
import { rateLimit, getClientIp, rateLimitResponse } from '@/lib/rate-limit'
import { checkAuth } from '@/lib/auth-check'

// Rate limiter: 20 requests per 5 minutes per IP
const downloadRateLimit = rateLimit({ maxRequests: 20, windowMs: 5 * 60 * 1000 })

// GET /api/agents/download-build
// Serves the build-exe.ps1 script for compiling CBUP Agent into .exe
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

    const buildScript = join(process.cwd(), 'agent', 'build-exe.ps1')

    if (!existsSync(buildScript)) {
      return NextResponse.json({ error: 'Build script not found' }, { status: 404 })
    }

    const buildContent = readFileSync(buildScript, 'utf-8')

    return new NextResponse(buildContent, {
      status: 200,
      headers: {
        'Content-Type': 'text/plain; charset=utf-8',
        'Content-Disposition': 'attachment; filename="build-exe.ps1"',
        'Cache-Control': 'no-cache',
        'X-Content-Type-Options': 'nosniff',
      },
    })
  } catch (error) {
    return NextResponse.json({ error: 'Failed to serve build script' }, { status: 500 })
  }
}
