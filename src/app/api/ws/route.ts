import { NextResponse } from 'next/server'

// GET /api/ws
// Placeholder endpoint — the actual WebSocket server is managed via the
// wsHub singleton in src/lib/websocket.ts and will be integrated through
// a custom server setup or external WebSocket proxy in production.
export async function GET() {
  return NextResponse.json({
    message: 'WebSocket endpoint',
    info: 'Connect via ws://host/api/ws using a WebSocket client.',
    details: 'The WebSocket hub manages real-time telemetry streaming, command status updates, and EDR scan progress.',
    events: [
      'telemetry',
      'command_status',
      'edr_scan_progress',
      'agent_online',
      'agent_offline',
      'alert_new',
      'report_generated',
    ],
  })
}
