import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { checkAuth } from '@/lib/auth-check'
import { rateLimit, getClientIp, rateLimitResponse } from '@/lib/rate-limit'

// Rate limiter: 20 tenant operations per 5 minutes per IP
const tenantRateLimit = rateLimit({ maxRequests: 20, windowMs: 5 * 60 * 1000 })

// POST /api/tenants — Create a new tenant
// SECURITY: Requires admin authentication (server-side, not client-provided role)
export async function POST(request: NextRequest) {
  // ─── Rate Limiting ───────────────────────────────────────────────────
  const clientIp = getClientIp(request)
  const rlResult = tenantRateLimit.check(clientIp)
  if (!rlResult.allowed) {
    return rateLimitResponse(rlResult)
  }

  // ─── Auth Check (server-side, NOT client-provided) ───────────────────
  const authFail = checkAuth(request)
  if (authFail) return authFail

  try {
    const body = await request.json()

    const { name, slug, description, plan, maxAgents } = body

    if (!name || typeof name !== 'string' || name.trim().length === 0) {
      return NextResponse.json(
        { success: false, error: 'Tenant name is required.' },
        { status: 400 }
      )
    }

    // Validate plan
    const validPlans = ['free', 'pro', 'enterprise']
    if (plan && !validPlans.includes(plan)) {
      return NextResponse.json(
        { success: false, error: `Invalid plan. Must be one of: ${validPlans.join(', ')}` },
        { status: 400 }
      )
    }

    // Validate maxAgents
    if (maxAgents !== undefined && (typeof maxAgents !== 'number' || maxAgents < 1 || maxAgents > 10000)) {
      return NextResponse.json(
        { success: false, error: 'maxAgents must be a number between 1 and 10000.' },
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

    // Validate slug format
    if (!/^[a-z0-9][a-z0-9-]{0,49}$/.test(tenantSlug)) {
      return NextResponse.json(
        { success: false, error: 'Invalid slug format. Use lowercase alphanumeric characters and hyphens only.' },
        { status: 400 }
      )
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
        name: name.trim().substring(0, 255),
        slug: tenantSlug,
        description: description?.trim()?.substring(0, 2000) || null,
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
// SECURITY: Requires admin authentication
export async function GET(request: NextRequest) {
  // ─── Auth Check ───────────────────────────────────────────────────────
  const authFail = checkAuth(request)
  if (authFail) return authFail

  try {
    const tenants = await db.tenant.findMany({
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
