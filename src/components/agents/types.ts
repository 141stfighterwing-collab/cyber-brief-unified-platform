// ─── Types ───────────────────────────────────────────────────────────────────

export type AgentStatus = 'online' | 'offline' | 'warning'
export type CommandStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled'
export type ScanSeverity = 'critical' | 'high' | 'medium' | 'low' | 'info'

export interface Agent {
  id: string
  hostname: string
  domain: string
  os: string
  status: AgentStatus
  cpu: number
  memory: number
  disk: number
  networkIn: number
  networkOut: number
  lastSeen: Date
  version: string
  ip: string
  mac: string
  manufacturer: string
  model: string
  serial: string
  bios: string
  totalRam: string
  cpuModel: string
}

export interface TelemetryPoint {
  time: string
  cpu: number
  memory: number
  diskRead: number
  diskWrite: number
  netIn: number
  netOut: number
}

export interface EDRScan {
  id: string
  type: string
  startedAt: Date
  completedAt: Date | null
  status: CommandStatus
  findings: ScanFinding[]
}

export interface ScanFinding {
  severity: ScanSeverity
  title: string
  description: string
}

export interface AgentCommand {
  id: string
  type: string
  payload: string
  status: CommandStatus
  createdAt: Date
  completedAt: Date | null
  result: string
}
