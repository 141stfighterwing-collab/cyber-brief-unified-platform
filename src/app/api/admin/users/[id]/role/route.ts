import { NextResponse } from 'next/server'
import { db } from '@/lib/db'

// POST /api/admin/users/[id]/role — Change user role
export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const body = await request.json()
    const { role } = body

    const validRoles = ['user', 'admin', 'super_admin']
    if (!role || !validRoles.includes(role)) {
      return NextResponse.json(
        { success: false, error: `Invalid role. Must be one of: ${validRoles.join(', ')}` },
        { status: 400 }
      )
    }

    // Verify user exists
    const user = await db.user.findUnique({ where: { id } })
    if (!user) {
      return NextResponse.json(
        { success: false, error: 'User not found.' },
        { status: 404 }
      )
    }

    const updated = await db.user.update({
      where: { id },
      data: { role },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
        updatedAt: true,
      },
    })

    return NextResponse.json({
      success: true,
      message: `User role updated to "${role}".`,
      data: updated,
    })
  } catch (error) {
    console.error('Change user role error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}
