import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { checkAuth } from '@/lib/auth-check'
import { safeEqual } from '@/lib/security-utils'

// ─── Allowed Command Types (restricted set) ───────────────────────────────
const ALLOWED_COMMAND_TYPES = new Set([
  'PING',
  'RUN_EDR_SCAN',
  'UPDATE_AGENT',
  'RESTART_AGENT',
])

// Maximum payload size: 512KB
const MAX_PAYLOAD_SIZE = 512 * 1024

// POST /api/agents/[id]/command
// Portal sends a command to an agent — REQUIRES ADMIN AUTH
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  // ─── Auth Check ────────────────────────────────────────────────────────
  const authFail = checkAuth(request)
  if (authFail) return authFail

  try {
    const { id } = await params
    const body = await request.json()
    const { type, payload } = body

    if (!type) {
      return NextResponse.json(
        { error: 'Missing required field: type' },
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

    // ─── Payload Size Validation ─────────────────────────────────────────
    if (payload) {
      const payloadSize = typeof payload === 'string'
        ? Buffer.byteLength(payload, 'utf-8')
        : Buffer.byteLength(JSON.stringify(payload), 'utf-8')

      if (payloadSize > MAX_PAYLOAD_SIZE) {
        return NextResponse.json(
          { error: `Payload exceeds maximum size of 512KB (${Math.round(payloadSize / 1024)}KB)` },
          { status: 413 }
        )
      }
    }

    // Verify agent exists
    const agent = await db.agent.findUnique({
      where: { id },
    })

    if (!agent) {
      return NextResponse.json({ error: 'Agent not found' }, { status: 404 })
    }

    // Create command with audit trail
    const command = await db.command.create({
      data: {
        agentId: id,
        type,
        payload: payload ? JSON.stringify(payload) : null,
        status: 'pending',
        createdBy: 'admin', // Auth-verified admin
      },
    })

    return NextResponse.json({ command })
  } catch (error) {
    console.error('Create agent command error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
