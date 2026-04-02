import { NextResponse } from 'next/server'
import { getDbStatus } from '@/lib/db'

export async function GET() {
  try {
    const status = await getDbStatus()
    return NextResponse.json(status)
  } catch (error) {
    console.error('DB status error:', error)
    return NextResponse.json(
      {
        provider: 'unknown',
        display: 'Unknown',
        connected: false,
        tables: [],
        counts: {},
      },
      { status: 500 }
    )
  }
}
