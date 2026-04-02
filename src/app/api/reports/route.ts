import { NextResponse } from 'next/server'
import { db } from '@/lib/db'

// GET /api/reports — List reports
export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url)
    const tenantId = searchParams.get('tenantId')
    const type = searchParams.get('type')
    const limit = parseInt(searchParams.get('limit') || '20', 10)
    const page = parseInt(searchParams.get('page') || '1', 10)

    // Build filter
    const where: Record<string, unknown> = {}
    if (tenantId) where.tenantId = tenantId
    if (type) where.type = type

    const skip = (page - 1) * limit

    const [reports, total] = await Promise.all([
      db.securityReport.findMany({
        where,
        include: {
          tenant: {
            select: {
              id: true,
              name: true,
              slug: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      db.securityReport.count({ where }),
    ])

    return NextResponse.json({
      success: true,
      data: reports,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    })
  } catch (error) {
    console.error('List reports error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}
