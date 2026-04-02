import { NextResponse } from 'next/server'
import { db } from '@/lib/db'

// GET /api/tenants/[id] — Get tenant details with agents, users, reports
export async function GET(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
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
export async function PUT(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
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
    if (body.name !== undefined) updateData.name = body.name.trim()
    if (body.description !== undefined) updateData.description = body.description?.trim() || null
    if (body.plan !== undefined) updateData.plan = body.plan
    if (body.maxAgents !== undefined) updateData.maxAgents = body.maxAgents
    if (body.active !== undefined) updateData.active = body.active

    // If slug is being changed, check uniqueness
    if (body.slug !== undefined && body.slug.trim() !== tenant.slug) {
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
export async function DELETE(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
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
