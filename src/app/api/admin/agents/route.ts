import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { checkAuth } from '@/lib/auth-check'

// GET /api/admin/agents — All agents across all tenants
// SECURITY: Requires admin authentication
export async function GET(request: NextRequest) {
  // ─── Auth Check ────────────────────────────────────────────────────────
  const authFail = checkAuth(request)
  if (authFail) return authFail

  try {
    const { searchParams } = new URL(request.url)
    const tenantId = searchParams.get('tenantId')
    const status = searchParams.get('status')
    const search = searchParams.get('search')
    const page = parseInt(searchParams.get('page') || '1', 10)
    const limit = parseInt(searchParams.get('limit') || '50', 10)

    // Build filter
    const where: Record<string, unknown> = {}
    if (tenantId) where.tenantId = tenantId
    if (status) where.status = status
    if (search) {
      where.OR = [
        { hostname: { contains: search } },
        { domain: { contains: search } },
        { agentId: { contains: search } },
        { osName: { contains: search } },
      ]
    }

    const skip = (page - 1) * limit

    const [agents, total] = await Promise.all([
      db.agent.findMany({
        where,
        include: {
          tenant: {
            select: {
              id: true,
              name: true,
              slug: true,
              plan: true,
            },
          },
          _count: {
            select: {
              telemetry: true,
              commands: true,
              edrScans: true,
            },
          },
        },
        orderBy: { lastSeen: 'desc' },
        skip,
        take: limit,
      }),
      db.agent.count({ where }),
    ])

    return NextResponse.json({
      success: true,
      data: agents,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    })
  } catch (error) {
    console.error('Admin agents list error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}
