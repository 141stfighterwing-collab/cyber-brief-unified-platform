import { NextResponse } from 'next/server'
import { db } from '@/lib/db'

// GET /api/reports/[id]/pdf — Generate PDF download
// For now, returns JSON with the report data (PDF generation will be added as an enhancement)
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

    if (report.status === 'generating') {
      return NextResponse.json(
        {
          success: false,
          error: 'Report is still generating. Please try again shortly.',
          status: 'generating',
        },
        { status: 202 }
      )
    }

    if (report.status === 'failed') {
      return NextResponse.json(
        { success: false, error: 'Report generation failed.' },
        { status: 500 }
      )
    }

    // Parse JSON fields
    const reportData = report.data ? JSON.parse(report.data) : null

    // Return JSON representation (placeholder for actual PDF)
    // In a future enhancement, this would use a PDF library to generate an actual PDF
    return NextResponse.json({
      success: true,
      message: 'PDF generation endpoint. Currently returns JSON data.',
      downloadFormat: 'json', // Will be changed to 'pdf' when PDF generation is implemented
      data: {
        id: report.id,
        title: report.title,
        type: report.type,
        status: report.status,
        tenant: report.tenant,
        summary: report.summary,
        reportData,
        generatedAt: report.createdAt,
        completedAt: report.completedAt,
      },
    })
  } catch (error) {
    console.error('Get report PDF error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}
