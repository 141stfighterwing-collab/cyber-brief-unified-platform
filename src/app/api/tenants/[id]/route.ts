import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { checkAuth } from '@/lib/auth-check'

// GET /api/tenants/[id] — Get tenant details with agents, users, reports
// SECURITY: Requires admin authentication
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  // ─── Auth Check ───────────────────────────────────────────────────────
  const authFail = checkAuth(request)
  if (authFail) return authFail

  try {
    const { id } = await params

    const tenant = await db.tenant.findUnique({
      where: { id },
      include: {
        users: {
          include: {
            user: {
              select: {
                id: true,
                email: true,
                name: true,
                avatar: true,
                role: true,
                // SECURITY: Never expose passwords
              },
            },
          },
          orderBy: { createdAt: 'asc' },
        },
        agents: {
          select: {
            id: true,
            agentId: true,
            hostname: true,
            osName: true,
            osVersion: true,
            status: true,
            lastSeen: true,
            version: true,
            tags: true,
            // SECURITY: Never expose authTokens
          },
          orderBy: { hostname: 'asc' },
        },
        reports: {
          select: {
            id: true,
            title: true,
            type: true,
            status: true,
            createdAt: true,
            completedAt: true,
          },
          orderBy: { createdAt: 'desc' },
          take: 20,
        },
        _count: {
          select: {
            agents: true,
            users: true,
            reports: true,
          },
        },
      },
    })

    if (!tenant) {
      return NextResponse.json(
        { success: false, error: 'Tenant not found' },
        { status: 404 }
      )
    }

    return NextResponse.json({ success: true, data: tenant })
  } catch (error) {
    console.error('Get tenant error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}

// PUT /api/tenants/[id] — Update tenant settings
// SECURITY: Requires admin authentication
export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  // ─── Auth Check ───────────────────────────────────────────────────────
  const authFail = checkAuth(request)
  if (authFail) return authFail

  try {
    const { id } = await params
    const body = await request.json()

    const tenant = await db.tenant.findUnique({ where: { id } })
    if (!tenant) {
      return NextResponse.json(
        { success: false, error: 'Tenant not found' },
        { status: 404 }
      )
    }

    const updateData: Record<string, unknown> = {}
    if (body.name !== undefined) updateData.name = body.name.trim().substring(0, 255)
    if (body.description !== undefined) updateData.description = body.description?.trim()?.substring(0, 2000) || null

    // Validate plan
    const validPlans = ['free', 'pro', 'enterprise']
    if (body.plan !== undefined) {
      if (!validPlans.includes(body.plan)) {
        return NextResponse.json(
          { success: false, error: `Invalid plan. Must be one of: ${validPlans.join(', ')}` },
          { status: 400 }
        )
      }
      updateData.plan = body.plan
    }

    if (body.maxAgents !== undefined) {
      if (typeof body.maxAgents !== 'number' || body.maxAgents < 1 || body.maxAgents > 10000) {
        return NextResponse.json(
          { success: false, error: 'maxAgents must be between 1 and 10000' },
          { status: 400 }
        )
      }
      updateData.maxAgents = body.maxAgents
    }
    if (body.active !== undefined) updateData.active = body.active

    // If slug is being changed, check uniqueness
    if (body.slug !== undefined && body.slug.trim() !== tenant.slug) {
      if (!/^[a-z0-9][a-z0-9-]{0,49}$/.test(body.slug.trim())) {
        return NextResponse.json(
          { success: false, error: 'Invalid slug format.' },
          { status: 400 }
        )
      }
      const slugExists = await db.tenant.findUnique({ where: { slug: body.slug.trim() } })
      if (slugExists) {
        return NextResponse.json(
          { success: false, error: 'A tenant with this slug already exists.' },
          { status: 409 }
        )
      }
      updateData.slug = body.slug.trim()
    }

    const updated = await db.tenant.update({
      where: { id },
      data: updateData,
    })

    return NextResponse.json({ success: true, data: updated })
  } catch (error) {
    console.error('Update tenant error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}

// DELETE /api/tenants/[id] — Soft-delete tenant (set active=false)
// SECURITY: Requires admin authentication
export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  // ─── Auth Check ───────────────────────────────────────────────────────
  const authFail = checkAuth(request)
  if (authFail) return authFail

  try {
    const { id } = await params

    const tenant = await db.tenant.findUnique({ where: { id } })
    if (!tenant) {
      return NextResponse.json(
        { success: false, error: 'Tenant not found' },
        { status: 404 }
      )
    }

    if (!tenant.active) {
      return NextResponse.json(
        { success: false, error: 'Tenant is already deactivated.' },
        { status: 400 }
      )
    }

    const deactivated = await db.tenant.update({
      where: { id },
      data: { active: false },
    })

    return NextResponse.json({
      success: true,
      message: 'Tenant deactivated successfully.',
      data: deactivated,
    })
  } catch (error) {
    console.error('Delete tenant error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}
