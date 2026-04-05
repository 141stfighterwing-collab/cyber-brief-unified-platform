import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { rateLimit, getClientIp, rateLimitResponse } from '@/lib/rate-limit'
import { checkAuth, AuthError } from '@/lib/auth-check'
import { safeEqual } from '@/lib/security-utils'

// ─── Allowed Command Types ───────────────────────────────────────────────────
const ALLOWED_COMMAND_TYPES = new Set([
  'PING',
  'RUN_EDR_SCAN',
  'RUN_CUSTOM_SCRIPT',
  'COLLECT_FILE',
  'KILL_PROCESS',
  'DISABLE_SERVICE',
  'BLOCK_IP',
  'UPDATE_AGENT',
  'RESTART_AGENT',
  'UNINSTALL_AGENT',
])

// Rate limiter for POST (admin commands): 20 commands per minute per IP
const commandPostRateLimit = rateLimit({ maxRequests: 20, windowMs: 60 * 1000 })

// Max payload size for RUN_CUSTOM_SCRIPT: 1MB
const MAX_CUSTOM_SCRIPT_PAYLOAD = 1024 * 1024 // 1MB

// GET /api/agents/commands?agentId=xxx&authToken=xxx
// Returns pending commands for the agent
export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url)
    const agentId = searchParams.get('agentId')
    const authToken = searchParams.get('authToken')

    if (!agentId || !authToken) {
      return NextResponse.json(
        { error: 'Missing required query params: agentId, authToken' },
        { status: 400 }
      )
    }

    // Verify agent and token
    const agent = await db.agent.findUnique({
      where: { agentId },
    })

    if (!agent) {
      return NextResponse.json({ error: 'Agent not found' }, { status: 404 })
    }

    // SECURITY: Timing-safe token comparison
    if (!safeEqual(authToken, agent.authToken)) {
      return NextResponse.json({ error: 'Invalid auth token' }, { status: 401 })
    }

    // Fetch pending commands
    const pendingCommands = await db.command.findMany({
      where: {
        agentId: agent.id,
        status: 'pending',
      },
      orderBy: { createdAt: 'asc' },
    })

    // Mark them as executing
    if (pendingCommands.length > 0) {
      await db.command.updateMany({
        where: {
          id: { in: pendingCommands.map((c: { id: string }) => c.id) },
        },
        data: {
          status: 'executing',
          executedAt: new Date(),
        },
      })
    }

    const commands = pendingCommands.map((c: { id: string; type: string; payload: string | null }) => ({
      id: c.id,
      type: c.type,
      payload: c.payload,
    }))

    return NextResponse.json({ commands })
  } catch (error) {
    console.error('Fetch commands error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

// POST /api/agents/commands
// Create a new command for an agent (from portal) — REQUIRES ADMIN AUTH
export async function POST(request: NextRequest) {
  try {
    // ─── Rate Limiting ───────────────────────────────────────────────────
    const clientIp = getClientIp(request)
    const rlResult = commandPostRateLimit.check(clientIp)
    if (!rlResult.allowed) {
      return rateLimitResponse(rlResult)
    }

    // ─── Admin Auth Check ────────────────────────────────────────────────
    const authFail = checkAuth(request)
    if (authFail) return authFail

    const body = await request.json()
    const { agentId, type, payload } = body

    if (!agentId || !type) {
      return NextResponse.json(
        { error: 'Missing required fields: agentId, type' },
        { status: 400 }
      )
    }

    // ─── Command Type Whitelist ──────────────────────────────────────────
    if (!ALLOWED_COMMAND_TYPES.has(type)) {
      return NextResponse.json(
        { error: `Invalid command type: ${type}. Allowed: ${[...ALLOWED_COMMAND_TYPES].join(', ')}` },
        { status: 400 }
      )
    }

    // ─── Payload Size Validation for RUN_CUSTOM_SCRIPT ──────────────────
    if (type === 'RUN_CUSTOM_SCRIPT' && payload) {
      const payloadSize = typeof payload === 'string'
        ? Buffer.byteLength(payload, 'utf-8')
        : Buffer.byteLength(JSON.stringify(payload), 'utf-8')

      if (payloadSize > MAX_CUSTOM_SCRIPT_PAYLOAD) {
        return NextResponse.json(
          { error: `RUN_CUSTOM_SCRIPT payload exceeds maximum size of 1MB (${Math.round(payloadSize / 1024)}KB)` },
          { status: 413 }
        )
      }
    }

    // Verify agent exists
    const agent = await db.agent.findUnique({
      where: { agentId },
    })

    if (!agent) {
      return NextResponse.json({ error: 'Agent not found' }, { status: 404 })
    }

    // Create command
    const command = await db.command.create({
      data: {
        agentId: agent.id,
        type,
        payload: payload ? JSON.stringify(payload) : null,
        status: 'pending',
      },
    })

    return NextResponse.json({ command })
  } catch (error) {
    if (error instanceof AuthError) {
      return NextResponse.json(
        { success: false, error: error.message },
        { status: 401, headers: { 'WWW-Authenticate': 'Bearer' } }
      )
    }
    console.error('Create command error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
