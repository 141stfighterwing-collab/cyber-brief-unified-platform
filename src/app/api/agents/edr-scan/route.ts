import { NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { safeEqual } from '@/lib/security-utils'

// Maximum scan result payload: 2MB
const MAX_SCAN_SIZE = 2 * 1024 * 1024

// POST /api/agents/edr-scan
// Agent submits EDR scan results
export async function POST(request: Request) {
  try {
    // ─── Body Size Validation ─────────────────────────────────────────────
    const contentLength = request.headers.get('content-length')
    if (contentLength && parseInt(contentLength, 10) > MAX_SCAN_SIZE) {
      return NextResponse.json(
        { success: false, error: 'Request body too large' },
        { status: 413 }
      )
    }

    const body = await request.json()
    const { agentId, authToken, scanType, findings, summary, durationMs } = body

    if (!agentId || !authToken || !scanType || !findings) {
      return NextResponse.json(
        { success: false, error: 'Missing required fields: agentId, authToken, scanType, findings' },
        { status: 400 }
      )
    }

    // Verify agent and token (timing-safe comparison)
    const agent = await db.agent.findUnique({
      where: { agentId },
    })

    if (!agent) {
      return NextResponse.json(
        { success: false, error: 'Agent not found' },
        { status: 404 }
      )
    }

    // SECURITY: Timing-safe token comparison
    if (!safeEqual(authToken, agent.authToken)) {
      return NextResponse.json(
        { success: false, error: 'Invalid auth token' },
        { status: 401 }
      )
    }

    // Parse findings to check for high-severity items
    const findingsArray = typeof findings === 'string' ? JSON.parse(findings) : findings
    const findingsStr = JSON.stringify(findingsArray)

    // Create EDR scan record
    const scan = await db.eDRScan.create({
      data: {
        agentId: agent.id,
        scanType,
        status: 'completed',
        findings: findingsStr,
        summary: summary ? JSON.stringify(summary) : null,
        durationMs: durationMs ?? null,
        completedAt: new Date(),
      },
    })

    // If findings contain high/critical severity items, create Alert records
    const highSeverityFindings = findingsArray.filter(
      (f: { severity?: string }) => f.severity === 'high' || f.severity === 'critical'
    )

    if (highSeverityFindings.length > 0) {
      await db.alert.createMany({
        data: highSeverityFindings.map((f: { severity?: string; title?: string; description?: string; category?: string }) => ({
          title: f.title || `EDR ${scanType} scan finding`,
          severity: f.severity || 'high',
          source: 'edr-agent',
          description: f.description || `EDR scan detected ${f.severity} severity finding on ${agent.hostname}`,
          category: f.category || 'edr',
        })),
      })
    }

    return NextResponse.json({ success: true, scanId: scan.id })
  } catch (error) {
    console.error('EDR scan submission error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}
