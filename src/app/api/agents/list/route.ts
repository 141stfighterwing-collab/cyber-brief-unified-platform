import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { checkAuth } from '@/lib/auth-check'

// GET /api/agents/list
// Returns all registered agents with latest telemetry
// SECURITY: Requires admin authentication
export async function GET(request: NextRequest) {
  // ─── Auth Check ────────────────────────────────────────────────────────
  const authFail = checkAuth(request)
  if (authFail) return authFail

  // SECURITY: Never expose authTokens in list responses
  try {
    const agents = await db.agent.findMany({
      orderBy: { lastSeen: 'desc' },
    })

    // Enrich with latest telemetry and counts
    const enrichedAgents = await Promise.all(
      agents.map(async (agent: Record<string, unknown>) => {
        // Get latest telemetry for each agent
        const latestTelemetry = await db.telemetry.findFirst({
          where: { agentId: agent.id as string },
          orderBy: { timestamp: 'desc' },
        })

        const commandCount = await db.command.count({
          where: { agentId: agent.id as string },
        })

        const scanCount = await db.eDRScan.count({
          where: { agentId: agent.id as string },
        })

        return {
          ...agent,
          latestTelemetry,
          commandCount,
          scanCount,
        }
      })
    )

    return NextResponse.json({ agents: enrichedAgents.map((a: Record<string, unknown>) => {
      // SECURITY: Strip auth tokens from response
      const { authToken, ...safe } = a
      return safe
    }) })
  } catch (error) {
    console.error('List agents error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
