/**
 * WebSocket Hub / Server Singleton for CBUP
 *
 * Manages real-time connections for agent telemetry streaming,
 * command status updates, EDR scan progress, and tenant-scoped broadcasting.
 *
 * This is a singleton that lives in the Node.js process. In production,
 * it would be integrated via a custom server or external WebSocket service.
 * For Next.js 16 dev mode, it can be accessed from API routes.
 */

import type { IncomingMessage } from 'http'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type WsEvent =
  | 'telemetry'
  | 'command_status'
  | 'edr_scan_progress'
  | 'agent_online'
  | 'agent_offline'
  | 'alert_new'
  | 'report_generated'

export interface WsClient {
  id: string
  tenantIds: string[]          // tenant IDs this client is allowed to see
  role: string                 // user role (super_admin sees everything)
  send: (data: string) => void
  alive: boolean
  connectedAt: Date
}

export interface WsMessage {
  event: WsEvent
  tenantId?: string | null
  payload: unknown
  timestamp: string
}

// ---------------------------------------------------------------------------
// WebSocketHub Singleton
// ---------------------------------------------------------------------------

class WebSocketHub {
  private clients: Map<string, WsClient> = new Map()
  private messageQueue: WsMessage[] = []
  private isProcessing = false

  /** Register a new client connection */
  addClient(client: WsClient): void {
    this.clients.set(client.id, client)
    console.log(`[WS] Client ${client.id} connected. Total: ${this.clients.size}`)
  }

  /** Remove a client connection */
  removeClient(clientId: string): void {
    const client = this.clients.get(clientId)
    if (client) {
      client.alive = false
      this.clients.delete(clientId)
      console.log(`[WS] Client ${clientId} disconnected. Total: ${this.clients.size}`)
    }
  }

  /** Get the number of connected clients */
  getClientCount(): number {
    return this.clients.size
  }

  /** Get all connected clients */
  getClients(): WsClient[] {
    return Array.from(this.clients.values())
  }

  /**
   * Broadcast a message to all clients that match the tenant scope.
   *
   * - If no tenantId, broadcasts to ALL clients
   * - super_admin users receive all broadcasts
   * - Regular users only receive broadcasts for tenants they belong to
   */
  broadcast(event: WsEvent, payload: unknown, tenantId?: string | null): void {
    const message: WsMessage = {
      event,
      tenantId: tenantId ?? null,
      payload,
      timestamp: new Date().toISOString(),
    }

    const data = JSON.stringify(message)

    for (const client of this.clients.values()) {
      if (!client.alive) continue

      // super_admin sees everything
      const isSuperAdmin = client.role === 'super_admin'

      // If no tenantId specified, send to everyone
      if (!tenantId) {
        try {
          client.send(data)
        } catch {
          client.alive = false
          this.clients.delete(client.id)
        }
        continue
      }

      // If tenantId specified, only send to clients with access
      if (isSuperAdmin || client.tenantIds.includes(tenantId)) {
        try {
          client.send(data)
        } catch {
          client.alive = false
          this.clients.delete(client.id)
        }
      }
    }

    // Also queue the message for replay/reconnection scenarios
    this.messageQueue.push(message)
    if (this.messageQueue.length > 1000) {
      this.messageQueue = this.messageQueue.slice(-500)
    }
  }

  /**
   * Convenience: Broadcast telemetry update from an agent heartbeat
   */
  broadcastTelemetry(agentData: {
    agentId: string
    hostname: string
    tenantId?: string | null
    status: string
    telemetry: Record<string, unknown>
  }): void {
    this.broadcast('telemetry', agentData, agentData.tenantId)

    // Also broadcast online/offline events
    if (agentData.status === 'online') {
      this.broadcast('agent_online', {
        agentId: agentData.agentId,
        hostname: agentData.hostname,
        status: agentData.status,
      }, agentData.tenantId)
    }
  }

  /**
   * Convenience: Broadcast command status change
   */
  broadcastCommandStatus(commandData: {
    commandId: string
    agentId: string
    tenantId?: string | null
    status: string
    result?: unknown
    error?: string
  }): void {
    this.broadcast('command_status', commandData, commandData.tenantId)
  }

  /**
   * Convenience: Broadcast EDR scan progress
   */
  broadcastEdrScanProgress(scanData: {
    scanId: string
    agentId: string
    tenantId?: string | null
    scanType: string
    status: string
    progress?: number
    findingsCount?: number
  }): void {
    this.broadcast('edr_scan_progress', scanData, scanData.tenantId)
  }

  /**
   * Convenience: Broadcast new alert
   */
  broadcastNewAlert(alertData: {
    alertId: string
    tenantId?: string | null
    title: string
    severity: string
  }): void {
    this.broadcast('alert_new', alertData, alertData.tenantId)
  }

  /**
   * Convenience: Broadcast report generation completion
   */
  broadcastReportGenerated(reportData: {
    reportId: string
    tenantId?: string | null
    title: string
    type: string
    status: string
  }): void {
    this.broadcast('report_generated', reportData, reportData.tenantId)
  }

  /**
   * Get recent messages for replay (useful for reconnection)
   */
  getRecentMessages(limit = 50, tenantId?: string): WsMessage[] {
    let messages = this.messageQueue
    if (tenantId) {
      messages = messages.filter(
        (m) => !m.tenantId || m.tenantId === tenantId
      )
    }
    return messages.slice(-limit)
  }

  /**
   * Clean up dead connections
   */
  cleanup(): number {
    let removed = 0
    for (const [id, client] of this.clients.entries()) {
      if (!client.alive) {
        this.clients.delete(id)
        removed++
      }
    }
    return removed
  }
}

// ---------------------------------------------------------------------------
// Singleton Export
// ---------------------------------------------------------------------------

// Use globalThis to survive hot reloads in dev
const globalForWs = globalThis as unknown as {
  wsHub: WebSocketHub | undefined
}

export const wsHub = globalForWs.wsHub ?? new WebSocketHub()

if (process.env.NODE_ENV !== 'production') {
  globalForWs.wsHub = wsHub
}

export default wsHub
