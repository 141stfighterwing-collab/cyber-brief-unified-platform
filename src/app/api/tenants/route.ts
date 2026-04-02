import { NextResponse } from 'next/server'
import { db } from '@/lib/db'

// POST /api/tenants — Create a new tenant
export async function POST(request: Request) {
  try {
    const body = await request.json()

    // Role check via query param or body (simplified auth for API)
    const { searchParams } = new URL(request.url)
    const requesterRole = searchParams.get('role') || body.requesterRole

    if (!requesterRole || !['admin', 'super_admin'].includes(requesterRole)) {
      return NextResponse.json(
        { success: false, error: 'Unauthorized. Requires admin or super_admin role.' },
        { status: 403 }
      )
    }

    const { name, slug, description, plan, maxAgents } = body

    if (!name || typeof name !== 'string' || name.trim().length === 0) {
      return NextResponse.json(
        { success: false, error: 'Tenant name is required.' },
        { status: 400 }
      )
    }

    // Auto-generate slug if not provided
    let tenantSlug = slug?.trim() || ''
    if (!tenantSlug) {
      tenantSlug = name
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '')
        .substring(0, 50)

      // Ensure uniqueness by appending random suffix if needed
      const existing = await db.tenant.findUnique({ where: { slug: tenantSlug } })
      if (existing) {
        tenantSlug = `${tenantSlug}-${Date.now().toString(36)}`
      }
    }

    // Check slug uniqueness
    const slugExists = await db.tenant.findUnique({ where: { slug: tenantSlug } })
    if (slugExists) {
      return NextResponse.json(
        { success: false, error: 'A tenant with this slug already exists.' },
        { status: 409 }
      )
    }

    const tenant = await db.tenant.create({
      data: {
        name: name.trim(),
        slug: tenantSlug,
        description: description?.trim() || null,
        plan: plan || 'free',
        maxAgents: maxAgents ?? 10,
      },
    })

    return NextResponse.json(
      { success: true, data: tenant },
      { status: 201 }
    )
  } catch (error) {
    console.error('Create tenant error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}

// GET /api/tenants — List all tenants
export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url)
    const userId = searchParams.get('userId')
    const requesterRole = searchParams.get('role')

    // Build query
    const where: Record<string, unknown> = { active: true }

    // If not super_admin and userId is provided, filter to their tenants
    if (requesterRole !== 'super_admin' && userId) {
      where.users = {
        some: { userId },
      }
    }

    const tenants = await db.tenant.findMany({
      where,
      include: {
        _count: {
          select: {
            users: true,
            agents: true,
            reports: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    })

    return NextResponse.json({ success: true, data: tenants })
  } catch (error) {
    console.error('List tenants error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}
