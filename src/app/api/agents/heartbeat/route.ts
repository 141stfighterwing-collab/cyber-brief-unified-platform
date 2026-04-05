import { NextResponse } from 'next/server'
import { db } from '@/lib/db'
import wsHub from '@/lib/websocket'
import { safeEqual } from '@/lib/security-utils'

// Maximum telemetry payload size: 256KB
const MAX_TELEMETRY_SIZE = 256 * 1024

// POST /api/agents/heartbeat
// Receives telemetry data from agent and broadcasts via WebSocket
export async function POST(request: Request) {
  try {
    // ─── Body Size Validation ─────────────────────────────────────────────
    const contentLength = request.headers.get('content-length')
    if (contentLength && parseInt(contentLength, 10) > MAX_TELEMETRY_SIZE) {
      return NextResponse.json(
        { success: false, error: 'Request body too large' },
        { status: 413 }
      )
    }

    const body = await request.json()
    const { agentId, authToken, telemetry } = body

    if (!agentId || !authToken || !telemetry) {
      return NextResponse.json(
        { success: false, error: 'Missing required fields: agentId, authToken, telemetry' },
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

    // Determine status based on telemetry
    let status = 'online'
    const cpu = telemetry.cpuPercent ?? 0
    const mem = telemetry.memPercent ?? 0
    if (cpu > 95 || mem > 98) {
      status = 'critical'
    } else if (cpu > 90 || mem > 95) {
      status = 'warning'
    }

    // Create telemetry record
    await db.telemetry.create({
      data: {
        agentId: agent.id,
        cpuPercent: telemetry.cpuPercent ?? null,
        memPercent: telemetry.memPercent ?? null,
        memUsedMb: telemetry.memUsedMb ?? null,
        memTotalMb: telemetry.memTotalMb ?? null,
        diskReadBps: telemetry.diskReadBps ?? null,
        diskWriteBps: telemetry.diskWriteBps ?? null,
        netInBps: telemetry.netInBps ?? null,
        netOutBps: telemetry.netOutBps ?? null,
        diskFreeGb: telemetry.diskFreeGb ?? null,
        diskTotalGb: telemetry.diskTotalGb ?? null,
        activeTcp: telemetry.activeTcp ?? null,
        uptime: telemetry.uptime ?? null,
        topCpuProcs: telemetry.topCpuProcs ? JSON.stringify(telemetry.topCpuProcs) : null,
        topMemProcs: telemetry.topMemProcs ? JSON.stringify(telemetry.topMemProcs) : null,
      },
    })

    // Update agent status and lastSeen
    await db.agent.update({
      where: { agentId },
      data: {
        lastSeen: new Date(),
        status,
      },
    })

    // Broadcast telemetry via WebSocket hub (non-blocking)
    try {
      wsHub.broadcastTelemetry({
        agentId: agent.agentId,
        hostname: agent.hostname,
        tenantId: agent.tenantId,
        status,
        telemetry: {
          cpuPercent: telemetry.cpuPercent,
          memPercent: telemetry.memPercent,
          memUsedMb: telemetry.memUsedMb,
          memTotalMb: telemetry.memTotalMb,
          diskReadBps: telemetry.diskReadBps,
          diskWriteBps: telemetry.diskWriteBps,
          netInBps: telemetry.netInBps,
          netOutBps: telemetry.netOutBps,
          diskFreeGb: telemetry.diskFreeGb,
          diskTotalGb: telemetry.diskTotalGb,
          activeTcp: telemetry.activeTcp,
          uptime: telemetry.uptime,
        },
      })
    } catch (wsError) {
      // Log WebSocket broadcast errors but don't fail the heartbeat
      console.error('[Heartbeat] WebSocket broadcast error:', wsError)
    }

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('Agent heartbeat error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}
