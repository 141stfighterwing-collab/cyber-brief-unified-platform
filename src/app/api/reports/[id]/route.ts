import { NextResponse } from 'next/server'
import { db } from '@/lib/db'

// GET /api/reports/[id] — Get report details
export async function GET(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params

    const report = await db.securityReport.findUnique({
      where: { id },
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

    if (!report) {
      return NextResponse.json(
        { success: false, error: 'Report not found.' },
        { status: 404 }
      )
    }

    // Parse JSON fields
    const result = {
      ...report,
      data: report.data ? JSON.parse(report.data) : null,
      agentIds: report.agentIds ? JSON.parse(report.agentIds) : [],
    }

    return NextResponse.json({ success: true, data: result })
  } catch (error) {
    console.error('Get report error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}

// DELETE /api/reports/[id] — Delete a report
export async function DELETE(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params

    const report = await db.securityReport.findUnique({ where: { id } })
    if (!report) {
      return NextResponse.json(
        { success: false, error: 'Report not found.' },
        { status: 404 }
      )
    }

    await db.securityReport.delete({ where: { id } })

    return NextResponse.json({
      success: true,
      message: 'Report deleted successfully.',
    })
  } catch (error) {
    console.error('Delete report error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}
