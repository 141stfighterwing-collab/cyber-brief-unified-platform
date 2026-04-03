import type { ScanSeverity, CommandStatus, AgentStatus } from './types'

// ─── Helpers ─────────────────────────────────────────────────────────────────

export function relativeTime(date: Date): string {
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffSec = Math.floor(diffMs / 1000)
  const diffMin = Math.floor(diffSec / 60)
  const diffHr = Math.floor(diffMin / 60)
  const diffDay = Math.floor(diffHr / 24)

  if (diffSec < 60) return `${diffSec}s ago`
  if (diffMin < 60) return `${diffMin}m ago`
  if (diffHr < 24) return `${diffHr}h ago`
  return `${diffDay}d ago`
}

export const severityColors: Record<ScanSeverity, string> = {
  critical: 'bg-red-500/10 text-red-500 border-red-500/20',
  high: 'bg-orange-500/10 text-orange-500 border-orange-500/20',
  medium: 'bg-yellow-500/10 text-yellow-500 border-yellow-500/20',
  low: 'bg-blue-500/10 text-blue-500 border-blue-500/20',
  info: 'bg-muted text-muted-foreground border-border',
}

export const commandStatusColors: Record<CommandStatus, string> = {
  pending: 'bg-yellow-500/10 text-yellow-500 border-yellow-500/20',
  running: 'bg-blue-500/10 text-blue-500 border-blue-500/20',
  completed: 'bg-green-500/10 text-green-500 border-green-500/20',
  failed: 'bg-red-500/10 text-red-500 border-red-500/20',
  cancelled: 'bg-muted text-muted-foreground border-border',
}

export const statusDotColors: Record<AgentStatus, string> = {
  online: 'bg-green-500',
  offline: 'bg-red-500',
  warning: 'bg-yellow-500',
}

// ─── Recharts Tooltip Style ──────────────────────────────────────────────────

export const chartTooltipStyle = {
  backgroundColor: 'oklch(0.17 0.01 155)',
  border: '1px solid oklch(0.28 0.015 155)',
  borderRadius: '8px',
  fontSize: '12px',
}

export const chartLabelStyle = { color: 'oklch(0.95 0.01 155)' }

export const chartTickStyle = { fontSize: 11, fill: 'oklch(0.5 0.02 155)' as const }
