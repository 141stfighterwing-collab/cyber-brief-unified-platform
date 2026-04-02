import { NextResponse } from 'next/server'
import { db } from '@/lib/db'

// GET /api/admin/users — List all users across tenants
export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url)
    const page = parseInt(searchParams.get('page') || '1', 10)
    const limit = parseInt(searchParams.get('limit') || '50', 10)
    const search = searchParams.get('search')
    const role = searchParams.get('role')

    // Build filter
    const where: Record<string, unknown> = {}
    if (role) where.role = role
    if (search) {
      where.OR = [
        { email: { contains: search } },
        { name: { contains: search } },
        { company: { contains: search } },
      ]
    }

    const skip = (page - 1) * limit

    const [users, total] = await Promise.all([
      db.user.findMany({
        where,
        select: {
          id: true,
          email: true,
          name: true,
          company: true,
          role: true,
          avatar: true,
          tier: true,
          createdAt: true,
          updatedAt: true,
          tenants: {
            include: {
              tenant: {
                select: {
                  id: true,
                  name: true,
                  slug: true,
                  plan: true,
                  active: true,
                },
              },
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      db.user.count({ where }),
    ])

    return NextResponse.json({
      success: true,
      data: users,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    })
  } catch (error) {
    console.error('Admin users list error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}
