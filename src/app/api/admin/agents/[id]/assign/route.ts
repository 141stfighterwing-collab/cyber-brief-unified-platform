import { NextResponse } from 'next/server'
import { db } from '@/lib/db'

// POST /api/admin/agents/[id]/assign — Assign agent to tenant
export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const body = await request.json()
    const { tenantId } = body

    if (!tenantId) {
      return NextResponse.json(
        { success: false, error: 'tenantId is required.' },
        { status: 400 }
      )
    }

    // Verify agent exists
    const agent = await db.agent.findUnique({
      where: { id },
      include: { tenant: true },
    })

    if (!agent) {
      return NextResponse.json(
        { success: false, error: 'Agent not found.' },
        { status: 404 }
      )
    }

    // Verify tenant exists and is active
    const tenant = await db.tenant.findUnique({
      where: { id: tenantId },
      include: {
        _count: { select: { agents: true } },
      },
    })

    if (!tenant) {
      return NextResponse.json(
        { success: false, error: 'Tenant not found.' },
        { status: 404 }
      )
    }

    if (!tenant.active) {
      return NextResponse.json(
        { success: false, error: 'Tenant is not active.' },
        { status: 400 }
      )
    }

    // Check agent limit
    if (tenant._count.agents >= tenant.maxAgents) {
      return NextResponse.json(
        {
          success: false,
          error: `Tenant has reached the maximum number of agents (${tenant.maxAgents}). Upgrade the plan to add more agents.`,
        },
        { status: 400 }
      )
    }

    // Update agent tenant assignment
    const updated = await db.agent.update({
      where: { id },
      data: { tenantId },
      include: {
        tenant: {
          select: {
            id: true,
            name: true,
            slug: true,
          },
        },
      },
    })

    return NextResponse.json({
      success: true,
      message: agent.tenantId
        ? `Agent reassigned from "${agent.tenant.name}" to "${tenant.name}".`
        : `Agent assigned to "${tenant.name}".`,
      data: updated,
    })
  } catch (error) {
    console.error('Assign agent error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}
