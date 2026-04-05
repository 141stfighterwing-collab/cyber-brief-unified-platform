import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import wsHub from '@/lib/websocket'
import { safeEqual } from '@/lib/security-utils'
import { rateLimit, getClientIp, rateLimitResponse } from '@/lib/rate-limit'

// Maximum telemetry payload size: 256KB
const MAX_TELEMETRY_SIZE = 256 * 1024

// Rate limiter: 60 heartbeats per minute per IP (agents send every 30s)
const heartbeatRateLimit = rateLimit({ maxRequests: 120, windowMs: 60 * 1000 })

/**
 * Normalizes telemetry from the CBUP Agent's actual format.
 *
 * The agent sends telemetry fields directly:
 *   { AgentId, Version, CPUTotalPercent, Memory: { UsedPercent, TotalGB, ... },
 *     Disks: [...], Network: [...], ActiveTCPConnections, UptimeSeconds, ... }
 *
 * The old format expected:
 *   { agentId, authToken, telemetry: { cpuPercent, memPercent, ... } }
 *
 * This function handles BOTH formats.
 */
function normalizeTelemetry(body: Record<string, unknown>) {
  // Format 1: Nested telemetry object (old format)
  if (body.telemetry && typeof body.telemetry === 'object') {
    const t = body.telemetry as Record<string, unknown>
    return {
      agentId:     (body.agentId as string) || '',
      authToken:   (body.authToken as string) || '',
      cpuPercent:  (t.cpuPercent as number) ?? null,
      memPercent:  (t.memPercent as number) ?? null,
      memUsedMb:   (t.memUsedMb as number) ?? null,
      memTotalMb:  (t.memTotalMb as number) ?? null,
      diskReadBps: (t.diskReadBps as number) ?? null,
      diskWriteBps: (t.diskWriteBps as number) ?? null,
      netInBps:    (t.netInBps as number) ?? null,
      netOutBps:   (t.netOutBps as number) ?? null,
      diskFreeGb:  (t.diskFreeGb as number) ?? null,
      diskTotalGb: (t.diskTotalGb as number) ?? null,
      activeTcp:   (t.activeTcp as number) ?? null,
      uptime:      (t.uptime as number) ?? null,
      topCpuProcs: (t.topCpuProcs as unknown[]) ?? null,
      topMemProcs: (t.topMemProcs as unknown[]) ?? null,
    }
  }

  // Format 2: CBUP Agent's native format (flat)
  const memory = (body.Memory as Record<string, unknown>) || {}
  const firstDisk = Array.isArray(body.Disks) && body.Disks.length > 0 ? body.Disks[0] as Record<string, unknown> : null

  return {
    agentId:     (body.AgentId as string) || (body.agentId as string) || '',
    authToken:   (body.AuthToken as string) || (body.authToken as string) || '',
    cpuPercent:  (body.CPUTotalPercent as number) ?? null,
    memPercent:  (memory.UsedPercent as number) ?? null,
    memUsedMb:   memory.UsedGB ? Math.round((memory.UsedGB as number) * 1024) : null,
    memTotalMb:  memory.TotalGB ? Math.round((memory.TotalGB as number) * 1024) : null,
    diskReadBps: null,
    diskWriteBps: null,
    netInBps:    null,
    netOutBps:   null,
    diskFreeGb:  firstDisk ? (firstDisk.FreeSpaceGB as number) ?? null : null,
    diskTotalGb: firstDisk ? (firstDisk.TotalSpaceGB as number) ?? null : null,
    activeTcp:   (body.ActiveTCPConnections as number) ?? null,
    uptime:      (body.UptimeSeconds as number) ?? null,
    topCpuProcs: body.TopProcessesByCPU as unknown[] ?? null,
    topMemProcs: body.TopProcessesByMemory as unknown[] ?? null,
  }
}

// POST /api/agents/heartbeat
// Receives telemetry data from agent and broadcasts via WebSocket.
// Supports both the old nested format and the agent's native flat format.
export async function POST(request: NextRequest) {
  try {
    // ─── Rate Limiting ───────────────────────────────────────────────────
    const clientIp = getClientIp(request)
    const rlResult = heartbeatRateLimit.check(clientIp)
    if (!rlResult.allowed) {
      return rateLimitResponse(rlResult)
    }

    // ─── Body Size Validation ─────────────────────────────────────────────
    const contentLength = request.headers.get('content-length')
    if (contentLength && parseInt(contentLength, 10) > MAX_TELEMETRY_SIZE) {
      return NextResponse.json(
        { success: false, error: 'Request body too large' },
        { status: 413 }
      )
    }

    const body = await request.json()

    // Normalize telemetry from either format
    const tel = normalizeTelemetry(body)

    if (!tel.agentId) {
      return NextResponse.json(
        { success: false, error: 'Missing required field: agentId' },
        { status: 400 }
      )
    }

    // ─── Auth: try Bearer token from header, then body authToken ─────────
    let authToken = tel.authToken
    if (!authToken) {
      const authHeader = request.headers.get('authorization')
      if (authHeader && authHeader.startsWith('Bearer ')) {
        authToken = authHeader.substring(7)
      }
      // Also check X-Agent-Id header for token lookup
      if (!authToken) {
        const agentIdFromHeader = request.headers.get('x-agent-id')
        if (agentIdFromHeader) {
          const foundAgent = await db.agent.findUnique({ where: { agentId: agentIdFromHeader } })
          if (foundAgent) authToken = foundAgent.authToken || ''
        }
      }
    }

    // Verify agent exists
    const agent = await db.agent.findUnique({
      where: { agentId: tel.agentId },
    })

    if (!agent) {
      return NextResponse.json(
        { success: false, error: 'Agent not found' },
        { status: 404 }
      )
    }

    // SECURITY: Timing-safe token comparison (skip if no auth token on either side)
    if (authToken && agent.authToken) {
      if (!safeEqual(authToken, agent.authToken)) {
        return NextResponse.json(
          { success: false, error: 'Invalid auth token' },
          { status: 401 }
        )
      }
    }

    // Determine status based on telemetry
    let status = 'online'
    const cpu = tel.cpuPercent ?? 0
    const mem = tel.memPercent ?? 0
    if (cpu > 95 || mem > 98) {
      status = 'critical'
    } else if (cpu > 90 || mem > 95) {
      status = 'warning'
    }

    // Create telemetry record
    await db.telemetry.create({
      data: {
        agentId: agent.id,
        cpuPercent: tel.cpuPercent,
        memPercent: tel.memPercent,
        memUsedMb: tel.memUsedMb,
        memTotalMb: tel.memTotalMb,
        diskReadBps: tel.diskReadBps,
        diskWriteBps: tel.diskWriteBps,
        netInBps: tel.netInBps,
        netOutBps: tel.netOutBps,
        diskFreeGb: tel.diskFreeGb,
        diskTotalGb: tel.diskTotalGb,
        activeTcp: tel.activeTcp,
        uptime: tel.uptime,
        topCpuProcs: tel.topCpuProcs ? JSON.stringify(tel.topCpuProcs) : null,
        topMemProcs: tel.topMemProcs ? JSON.stringify(tel.topMemProcs) : null,
      },
    })

    // Update agent status and lastSeen
    await db.agent.update({
      where: { agentId: tel.agentId },
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
          cpuPercent: tel.cpuPercent,
          memPercent: tel.memPercent,
          memUsedMb: tel.memUsedMb,
          memTotalMb: tel.memTotalMb,
          diskReadBps: tel.diskReadBps,
          diskWriteBps: tel.diskWriteBps,
          netInBps: tel.netInBps,
          netOutBps: tel.netOutBps,
          diskFreeGb: tel.diskFreeGb,
          diskTotalGb: tel.diskTotalGb,
          activeTcp: tel.activeTcp,
          uptime: tel.uptime,
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
