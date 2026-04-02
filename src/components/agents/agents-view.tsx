'use client'

import { useState, useEffect, useCallback, useMemo } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { Progress } from '@/components/ui/progress'
import { Switch } from '@/components/ui/switch'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip'
import { useAppStore } from '@/lib/store'
import {
  Monitor,
  Cpu,
  HardDrive,
  Wifi,
  Shield,
  Terminal,
  Activity,
  Server,
  Download,
  RefreshCw,
  Play,
  Square,
  AlertTriangle,
  CheckCircle,
  XCircle,
  ChevronLeft,
  Copy,
  Check,
  Command,
  Network,
  Clock,
  Info,
  Building2,
} from 'lucide-react'
import {
  LineChart,
  Line,
  AreaChart,
  Area,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip as RechartsTooltip,
  ResponsiveContainer,
  CartesianGrid,
} from 'recharts'

// ─── Types ───────────────────────────────────────────────────────────────────

type AgentStatus = 'online' | 'offline' | 'warning'
type CommandStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled'
type ScanSeverity = 'critical' | 'high' | 'medium' | 'low' | 'info'

interface Agent {
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

interface TelemetryPoint {
  time: string
  cpu: number
  memory: number
  diskRead: number
  diskWrite: number
  netIn: number
  netOut: number
}

interface EDRScan {
  id: string
  type: string
  startedAt: Date
  completedAt: Date | null
  status: CommandStatus
  findings: ScanFinding[]
}

interface ScanFinding {
  severity: ScanSeverity
  title: string
  description: string
}

interface AgentCommand {
  id: string
  type: string
  payload: string
  status: CommandStatus
  createdAt: Date
  completedAt: Date | null
  result: string
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function relativeTime(date: Date): string {
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

const severityColors: Record<ScanSeverity, string> = {
  critical: 'bg-red-500/10 text-red-500 border-red-500/20',
  high: 'bg-orange-500/10 text-orange-500 border-orange-500/20',
  medium: 'bg-yellow-500/10 text-yellow-500 border-yellow-500/20',
  low: 'bg-blue-500/10 text-blue-500 border-blue-500/20',
  info: 'bg-muted text-muted-foreground border-border',
}

const commandStatusColors: Record<CommandStatus, string> = {
  pending: 'bg-yellow-500/10 text-yellow-500 border-yellow-500/20',
  running: 'bg-blue-500/10 text-blue-500 border-blue-500/20',
  completed: 'bg-green-500/10 text-green-500 border-green-500/20',
  failed: 'bg-red-500/10 text-red-500 border-red-500/20',
  cancelled: 'bg-muted text-muted-foreground border-border',
}

const statusDotColors: Record<AgentStatus, string> = {
  online: 'bg-green-500',
  offline: 'bg-red-500',
  warning: 'bg-yellow-500',
}

// ─── Mock Data ───────────────────────────────────────────────────────────────

function generateMockAgents(): Agent[] {
  return [
    {
      id: 'agent-001',
      hostname: 'WS-DC-01',
      domain: 'corp.cbup.local',
      os: 'Windows Server 2022',
      status: 'online',
      cpu: 34,
      memory: 62,
      disk: 45,
      networkIn: 12.4,
      networkOut: 8.2,
      lastSeen: new Date(Date.now() - 30000),
      version: '2.4.1',
      ip: '10.0.1.10',
      mac: '00:1A:2B:3C:4D:5E',
      manufacturer: 'Dell Inc.',
      model: 'PowerEdge R750',
      serial: 'SN-2024-DELL-001',
      bios: 'Dell BIOS 2.18.1',
      totalRam: '64 GB',
      cpuModel: 'Intel Xeon Gold 6338',
    },
    {
      id: 'agent-002',
      hostname: 'WS-FW-01',
      domain: 'corp.cbup.local',
      os: 'Windows Server 2019',
      status: 'online',
      cpu: 18,
      memory: 41,
      disk: 22,
      networkIn: 145.7,
      networkOut: 132.1,
      lastSeen: new Date(Date.now() - 15000),
      version: '2.4.1',
      ip: '10.0.1.5',
      mac: '00:1A:2B:3C:4D:6F',
      manufacturer: 'HPE',
      model: 'ProLiant DL380 Gen10',
      serial: 'SN-2023-HPE-042',
      bios: 'HPE U31 02.12',
      totalRam: '128 GB',
      cpuModel: 'Intel Xeon Silver 4214R',
    },
    {
      id: 'agent-003',
      hostname: 'WS-WK-014',
      domain: 'corp.cbup.local',
      os: 'Windows 11 Pro',
      status: 'warning',
      cpu: 89,
      memory: 91,
      disk: 78,
      networkIn: 2.1,
      networkOut: 0.8,
      lastSeen: new Date(Date.now() - 120000),
      version: '2.3.8',
      ip: '10.0.2.114',
      mac: 'AA:BB:CC:DD:EE:01',
      manufacturer: 'Lenovo',
      model: 'ThinkPad X1 Carbon Gen 11',
      serial: 'SN-2024-LEN-701',
      bios: 'LENOVO N3CET63W',
      totalRam: '32 GB',
      cpuModel: 'Intel Core i7-1365U',
    },
    {
      id: 'agent-004',
      hostname: 'WS-SQL-01',
      domain: 'corp.cbup.local',
      os: 'Windows Server 2022',
      status: 'online',
      cpu: 56,
      memory: 74,
      disk: 62,
      networkIn: 34.5,
      networkOut: 28.3,
      lastSeen: new Date(Date.now() - 45000),
      version: '2.4.1',
      ip: '10.0.1.20',
      mac: '00:1A:2B:3C:4D:7A',
      manufacturer: 'Dell Inc.',
      model: 'PowerEdge R650',
      serial: 'SN-2024-DELL-015',
      bios: 'Dell BIOS 2.16.2',
      totalRam: '256 GB',
      cpuModel: 'AMD EPYC 9354',
    },
    {
      id: 'agent-005',
      hostname: 'WS-WK-027',
      domain: 'corp.cbup.local',
      os: 'Windows 10 Enterprise',
      status: 'offline',
      cpu: 0,
      memory: 0,
      disk: 55,
      networkIn: 0,
      networkOut: 0,
      lastSeen: new Date(Date.now() - 86400000 * 2),
      version: '2.3.5',
      ip: '10.0.3.27',
      mac: 'AA:BB:CC:DD:EE:02',
      manufacturer: 'HP',
      model: 'EliteBook 840 G8',
      serial: 'SN-2022-HP-339',
      bios: 'HP Q78 Ver. 01.15',
      totalRam: '16 GB',
      cpuModel: 'Intel Core i5-1145G7',
    },
    {
      id: 'agent-006',
      hostname: 'WS-FILE-01',
      domain: 'corp.cbup.local',
      os: 'Windows Server 2022',
      status: 'online',
      cpu: 12,
      memory: 38,
      disk: 71,
      networkIn: 56.2,
      networkOut: 42.8,
      lastSeen: new Date(Date.now() - 20000),
      version: '2.4.0',
      ip: '10.0.1.30',
      mac: '00:1A:2B:3C:4D:8B',
      manufacturer: 'HPE',
      model: 'ProLiant ML350 Gen10',
      serial: 'SN-2023-HPE-088',
      bios: 'HPE U31 02.08',
      totalRam: '64 GB',
      cpuModel: 'Intel Xeon Silver 4316',
    },
  ]
}

function generateTelemetry(hours: number): TelemetryPoint[] {
  const points: TelemetryPoint[] = []
  const now = new Date()
  const interval = Math.max(1, Math.floor((hours * 60) / 60))
  for (let i = 59; i >= 0; i--) {
    const t = new Date(now.getTime() - i * interval * 60000)
    points.push({
      time: `${t.getHours().toString().padStart(2, '0')}:${t.getMinutes().toString().padStart(2, '0')}`,
      cpu: 20 + Math.random() * 40 + (i > 50 ? 20 : 0),
      memory: 40 + Math.random() * 30,
      diskRead: Math.random() * 50,
      diskWrite: Math.random() * 30,
      netIn: 5 + Math.random() * 40,
      netOut: 3 + Math.random() * 25,
    })
  }
  return points
}

function generateScans(): EDRScan[] {
  return [
    {
      id: 'scan-001',
      type: 'Full Scan',
      startedAt: new Date(Date.now() - 3600000 * 2),
      completedAt: new Date(Date.now() - 3600000),
      status: 'completed',
      findings: [
        { severity: 'medium', title: 'Suspicious Scheduled Task', description: 'Task "UpdateAgent" runs from temp directory with elevated privileges' },
        { severity: 'low', title: 'Deprecated Service Running', description: 'Telnet service is enabled but not actively used' },
      ],
    },
    {
      id: 'scan-002',
      type: 'Port Scan',
      startedAt: new Date(Date.now() - 86400000),
      completedAt: new Date(Date.now() - 86400000 + 1800000),
      status: 'completed',
      findings: [
        { severity: 'high', title: 'Unexpected RDP Exposure', description: 'Port 3389 is open and accepting connections from 0.0.0.0' },
        { severity: 'info', title: 'DNS Server Detected', description: 'Port 53 open - expected for domain controller' },
      ],
    },
    {
      id: 'scan-003',
      type: 'Process Scan',
      startedAt: new Date(Date.now() - 600000),
      completedAt: null,
      status: 'running',
      findings: [],
    },
  ]
}

function generateCommands(): AgentCommand[] {
  return [
    { id: 'cmd-001', type: 'Run EDR Scan', payload: 'full', status: 'completed', createdAt: new Date(Date.now() - 7200000), completedAt: new Date(Date.now() - 3600000), result: 'Scan complete. 2 findings.' },
    { id: 'cmd-002', type: 'Run Custom Script', payload: 'Get-Process | Sort-Object CPU -Descending | Select-Object -First 10', status: 'completed', createdAt: new Date(Date.now() - 5400000), completedAt: new Date(Date.now() - 5395000), result: 'chrome.exe: 34.2% CPU, msedge.exe: 12.1%, ...' },
    { id: 'cmd-003', type: 'Ping Agent', payload: '', status: 'completed', createdAt: new Date(Date.now() - 120000), completedAt: new Date(Date.now() - 119000), result: 'Pong - latency 14ms' },
    { id: 'cmd-004', type: 'Block IP', payload: '192.168.1.100', status: 'running', createdAt: new Date(Date.now() - 60000), completedAt: null, result: '' },
    { id: 'cmd-005', type: 'Kill Process', payload: 'PID 4821', status: 'failed', createdAt: new Date(Date.now() - 300000), completedAt: new Date(Date.now() - 299000), result: 'Access denied. Process is protected.' },
  ]
}

// ─── Recharts Tooltip Style ──────────────────────────────────────────────────

const chartTooltipStyle = {
  backgroundColor: 'oklch(0.17 0.01 155)',
  border: '1px solid oklch(0.28 0.015 155)',
  borderRadius: '8px',
  fontSize: '12px',
}

const chartLabelStyle = { color: 'oklch(0.95 0.01 155)' }

const chartTickStyle = { fontSize: 11, fill: 'oklch(0.5 0.02 155)' as const }

// ─── Copy Button ─────────────────────────────────────────────────────────────

function CopyButton({ text }: { text: string }) {
  const [copied, setCopied] = useState(false)
  const handleCopy = () => {
    navigator.clipboard.writeText(text).then(() => {
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    })
  }
  return (
    <Button variant="ghost" size="sm" className="h-7 w-7 p-0" onClick={handleCopy}>
      {copied ? <Check className="h-3.5 w-3.5 text-green-500" /> : <Copy className="h-3.5 w-3.5" />}
    </Button>
  )
}

// ─── C2 Command Dialog ───────────────────────────────────────────────────────

type CommandType =
  | 'edr-scan'
  | 'custom-script'
  | 'kill-process'
  | 'block-ip'
  | 'restart-agent'
  | 'ping'
  | 'uninstall'

const commandOptions: { value: CommandType; label: string; description: string }[] = [
  { value: 'edr-scan', label: 'Run EDR Scan', description: 'Execute a security scan on the endpoint' },
  { value: 'custom-script', label: 'Run Custom Script', description: 'Execute arbitrary PowerShell code' },
  { value: 'kill-process', label: 'Kill Process', description: 'Terminate a process by PID' },
  { value: 'block-ip', label: 'Block IP', description: 'Add a firewall rule to block an IP' },
  { value: 'restart-agent', label: 'Restart Agent', description: 'Restart the CBUP agent service' },
  { value: 'ping', label: 'Ping Agent', description: 'Send a ping to check connectivity' },
  { value: 'uninstall', label: 'Uninstall Agent', description: 'Remove the CBUP agent from the endpoint' },
]

interface C2DialogProps {
  agent: Agent | null
  open: boolean
  onClose: () => void
}

function C2CommandDialog({ agent, open, onClose }: C2DialogProps) {
  const [commandType, setCommandType] = useState<CommandType>('edr-scan')
  const [payload, setPayload] = useState('')
  const [scanType, setScanType] = useState('full')
  const [submitting, setSubmitting] = useState(false)

  const handleSubmit = async () => {
    if (!agent) return
    setSubmitting(true)
    try {
      const body: Record<string, string> = { type: commandType, payload: '' }
      if (commandType === 'edr-scan') body.payload = scanType
      else if (commandType === 'custom-script') body.payload = payload
      else if (commandType === 'kill-process') body.payload = payload
      else if (commandType === 'block-ip') body.payload = payload

      await fetch(`/api/agents/${agent.id}/command`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      })
      onClose()
    } catch {
      // Silently handle for now
    } finally {
      setSubmitting(false)
    }
  }

  const needsPayload = ['custom-script', 'kill-process', 'block-ip'].includes(commandType)

  return (
    <Dialog open={open} onOpenChange={(v) => !v && onClose()}>
      <DialogContent className="sm:max-w-lg border-border/50 bg-card">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Terminal className="h-4 w-4 text-primary" />
            Remote Command — {agent?.hostname}
          </DialogTitle>
          <DialogDescription>
            Issue a command to this agent. Actions are logged and auditable.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4 py-2">
          <div className="space-y-2">
            <label className="text-xs font-medium text-muted-foreground">Command Type</label>
            <Select value={commandType} onValueChange={(v) => { setCommandType(v as CommandType); setPayload('') }}>
              <SelectTrigger className="border-border/50">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {commandOptions.map((opt) => (
                  <SelectItem key={opt.value} value={opt.value}>
                    <span>{opt.label}</span>
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {commandType === 'edr-scan' && (
            <div className="space-y-2">
              <label className="text-xs font-medium text-muted-foreground">Scan Type</label>
              <Select value={scanType} onValueChange={setScanType}>
                <SelectTrigger className="border-border/50">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="process">Process Analysis</SelectItem>
                  <SelectItem value="service">Service Enumeration</SelectItem>
                  <SelectItem value="port">Port Scan</SelectItem>
                  <SelectItem value="autorun">Autorun / Persistence</SelectItem>
                  <SelectItem value="vulnerability">Vulnerability Assessment</SelectItem>
                  <SelectItem value="full">Full Scan</SelectItem>
                </SelectContent>
              </Select>
            </div>
          )}

          {commandType === 'custom-script' && (
            <div className="space-y-2">
              <label className="text-xs font-medium text-muted-foreground">PowerShell Script</label>
              <Textarea
                className="font-mono text-xs border-border/50 min-h-[120px]"
                placeholder="Get-Process | Where-Object { $_.CPU -gt 10 }"
                value={payload}
                onChange={(e) => setPayload(e.target.value)}
              />
            </div>
          )}

          {commandType === 'kill-process' && (
            <div className="space-y-2">
              <label className="text-xs font-medium text-muted-foreground">Process ID (PID)</label>
              <Input
                className="border-border/50"
                placeholder="e.g. 4821"
                value={payload}
                onChange={(e) => setPayload(e.target.value)}
              />
            </div>
          )}

          {commandType === 'block-ip' && (
            <div className="space-y-2">
              <label className="text-xs font-medium text-muted-foreground">IP Address to Block</label>
              <Input
                className="border-border/50"
                placeholder="e.g. 192.168.1.100"
                value={payload}
                onChange={(e) => setPayload(e.target.value)}
              />
            </div>
          )}

          {['restart-agent', 'uninstall', 'ping'].includes(commandType) && (
            <div className="rounded-lg border border-yellow-500/20 bg-yellow-500/5 p-3">
              <div className="flex items-start gap-2">
                <AlertTriangle className="h-4 w-4 text-yellow-500 mt-0.5 shrink-0" />
                <p className="text-xs text-yellow-200/80">
                  {commandType === 'restart-agent' && 'This will restart the CBUP agent service on the endpoint. The agent will reconnect automatically.'}
                  {commandType === 'uninstall' && 'This will permanently remove the CBUP agent from the endpoint. You will need to reinstall manually.'}
                  {commandType === 'ping' && 'A lightweight ping to verify agent connectivity and measure response latency.'}
                </p>
              </div>
            </div>
          )}
        </div>

        <DialogFooter className="gap-2">
          <Button variant="outline" onClick={onClose} className="border-border/50">
            Cancel
          </Button>
          <Button
            onClick={handleSubmit}
            disabled={submitting || (needsPayload && !payload.trim())}
            className="bg-primary hover:bg-primary/90"
          >
            {submitting ? (
              <RefreshCw className="h-3.5 w-3.5 mr-1.5 animate-spin" />
            ) : (
              <Play className="h-3.5 w-3.5 mr-1.5" />
            )}
            Execute Command
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// ─── Deploy Agent Dialog ────────────────────────────────────────────────────

function DeployAgentDialog() {
  const [open, setOpen] = useState(false)
  const oneLiner = "Set-ExecutionPolicy Bypass -Scope Process -Force; iex (New-Object Net.WebClient).DownloadString('http://YOUR-SERVER:3000/api/agents/install-script')"
  const manualSteps = `# Download agent\nInvoke-WebRequest -Uri 'http://YOUR-SERVER:3000/agent/CBUP-Agent.ps1' -OutFile 'CBUP-Agent.ps1'\n# Install\n.\\CBUP-Agent.ps1 -ServerUrl 'http://YOUR-SERVER:3000' -Install`

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="bg-primary hover:bg-primary/90 text-primary-foreground">
          <Download className="h-4 w-4 mr-1.5" />
          Deploy New Agent
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-2xl border-border/50 bg-card">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Server className="h-4 w-4 text-primary" />
            Deploy New Agent
          </DialogTitle>
          <DialogDescription>
            Install the CBUP agent on a Windows endpoint using PowerShell.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-5 py-2">
          {/* Quick Install */}
          <div className="space-y-2">
            <div className="flex items-center gap-2">
              <Badge variant="outline" className="bg-green-500/10 text-green-500 border-green-500/20 text-[10px]">RECOMMENDED</Badge>
              <label className="text-sm font-semibold">One-Liner Quick Install</label>
            </div>
            <div className="relative">
              <pre className="rounded-lg bg-background border border-border/50 p-3 text-xs font-mono overflow-x-auto pr-10">
                {oneLiner}
              </pre>
              <div className="absolute top-2 right-2">
                <CopyButton text={oneLiner} />
              </div>
            </div>
          </div>

          {/* Manual Install */}
          <div className="space-y-2">
            <label className="text-sm font-semibold">Manual Install</label>
            <div className="relative">
              <pre className="rounded-lg bg-background border border-border/50 p-3 text-xs font-mono overflow-x-auto whitespace-pre-wrap pr-10">
                {manualSteps}
              </pre>
              <div className="absolute top-2 right-2">
                <CopyButton text={manualSteps} />
              </div>
            </div>
          </div>

          {/* Notes */}
          <div className="rounded-lg border border-blue-500/20 bg-blue-500/5 p-3 space-y-2">
            <div className="flex items-start gap-2">
              <Info className="h-4 w-4 text-blue-400 mt-0.5 shrink-0" />
              <div className="text-xs text-blue-200/70 space-y-1">
                <p><strong className="text-blue-300">Prerequisites:</strong> Windows 10/11 or Windows Server 2016+, PowerShell 5.1+, administrator privileges</p>
                <p><strong className="text-blue-300">Firewall:</strong> Ensure outbound HTTPS (443) is allowed to the CBUP server</p>
                <p><strong className="text-blue-300">Anti-Virus:</strong> You may need to add an exclusion for the agent installation path</p>
              </div>
            </div>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}

// ─── Agent Card ──────────────────────────────────────────────────────────────

interface AgentCardProps {
  agent: Agent
  onSelect: (agent: Agent) => void
  onCommand: (agent: Agent) => void
  onScan: (agent: Agent) => void
  selected: boolean
}

function AgentCard({ agent, onSelect, onCommand, onScan, selected }: AgentCardProps) {
  return (
    <Card
      className={`border-border/50 cursor-pointer transition-all hover:border-primary/30 ${
        selected ? 'border-primary/50 ring-1 ring-primary/20' : ''
      }`}
      onClick={() => onSelect(agent)}
    >
      <CardContent className="p-4 space-y-3">
        {/* Header */}
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-2.5 min-w-0">
            <div className={`w-2.5 h-2.5 rounded-full shrink-0 ${statusDotColors[agent.status]} ${
              agent.status === 'online' ? 'animate-pulse' : ''
            }`} />
            <div className="min-w-0">
              <p className="text-sm font-semibold truncate">{agent.hostname}</p>
              <p className="text-xs text-muted-foreground truncate">{agent.domain}</p>
            </div>
          </div>
          <Badge
            variant="outline"
            className={`text-[10px] shrink-0 ml-2 ${
              agent.status === 'online'
                ? 'bg-green-500/10 text-green-500 border-green-500/20'
                : agent.status === 'warning'
                ? 'bg-yellow-500/10 text-yellow-500 border-yellow-500/20'
                : 'bg-red-500/10 text-red-500 border-red-500/20'
            }`}
          >
            {agent.status}
          </Badge>
        </div>

        {/* OS */}
        <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
          <Monitor className="h-3 w-3" />
          <span className="truncate">{agent.os}</span>
        </div>

        {/* CPU / Memory */}
        {agent.status !== 'offline' && (
          <div className="space-y-1.5">
            <div className="flex items-center justify-between text-xs">
              <span className="flex items-center gap-1 text-muted-foreground">
                <Cpu className="h-3 w-3" /> CPU
              </span>
              <span className={agent.cpu > 80 ? 'text-red-400 font-medium' : 'text-foreground'}>
                {agent.cpu}%
              </span>
            </div>
            <Progress value={agent.cpu} className="h-1.5" />
            <div className="flex items-center justify-between text-xs">
              <span className="flex items-center gap-1 text-muted-foreground">
                <HardDrive className="h-3 w-3" /> RAM
              </span>
              <span className={agent.memory > 85 ? 'text-red-400 font-medium' : 'text-foreground'}>
                {agent.memory}%
              </span>
            </div>
            <Progress value={agent.memory} className="h-1.5" />
          </div>
        )}

        {/* Network */}
        {agent.status !== 'offline' && (
          <div className="flex items-center justify-between text-xs text-muted-foreground">
            <span className="flex items-center gap-1">
              <Wifi className="h-3 w-3" />
              {agent.networkIn.toFixed(1)} MB/s in
            </span>
            <span>{agent.networkOut.toFixed(1)} MB/s out</span>
          </div>
        )}

        {/* Last Seen */}
        <div className="flex items-center justify-between text-xs text-muted-foreground pt-1 border-t border-border/30">
          <span className="flex items-center gap-1">
            <Clock className="h-3 w-3" />
            {relativeTime(agent.lastSeen)}
          </span>
          <span className="font-mono text-[10px]">{agent.version}</span>
        </div>

        {/* Actions */}
        <div className="flex items-center gap-1.5 pt-1">
          <Button
            variant="outline"
            size="sm"
            className="h-7 text-xs border-border/50 flex-1"
            onClick={(e) => { e.stopPropagation(); onScan(agent) }}
          >
            <Shield className="h-3 w-3 mr-1" />
            Scan
          </Button>
          <Button
            variant="outline"
            size="sm"
            className="h-7 text-xs border-border/50 flex-1"
            onClick={(e) => { e.stopPropagation(); onCommand(agent) }}
          >
            <Terminal className="h-3 w-3 mr-1" />
            Command
          </Button>
          <Button
            variant="outline"
            size="sm"
            className="h-7 text-xs border-border/50"
            onClick={(e) => { e.stopPropagation(); onSelect(agent) }}
          >
            Details
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}

// ─── Agent Detail Panel ──────────────────────────────────────────────────────

interface AgentDetailPanelProps {
  agent: Agent
  onCommand: (agent: Agent) => void
  onClose: () => void
}

function AgentDetailPanel({ agent, onCommand, onClose }: AgentDetailPanelProps) {
  const [telemetryHours, setTelemetryHours] = useState(1)
  const [cmdFilter, setCmdFilter] = useState<string>('all')

  const telemetryData = useMemo(() => generateTelemetry(telemetryHours), [telemetryHours])
  const scanData = useMemo(() => generateScans(), [])
  const commandData = useMemo(() => generateCommands(), [])

  const filteredCommands = cmdFilter === 'all'
    ? commandData
    : commandData.filter((c) => c.status === cmdFilter)

  const systemInfoRows = [
    { label: 'Hostname', value: agent.hostname },
    { label: 'Domain', value: agent.domain },
    { label: 'OS', value: agent.os },
    { label: 'IP Address', value: agent.ip },
    { label: 'MAC Address', value: agent.mac },
    { label: 'Manufacturer', value: agent.manufacturer },
    { label: 'Model', value: agent.model },
    { label: 'Serial Number', value: agent.serial },
    { label: 'BIOS', value: agent.bios },
    { label: 'CPU', value: agent.cpuModel },
    { label: 'RAM', value: agent.totalRam },
    { label: 'Agent Version', value: agent.version },
  ]

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Button variant="ghost" size="sm" className="h-8 w-8 p-0" onClick={onClose}>
            <ChevronLeft className="h-4 w-4" />
          </Button>
          <div className="flex items-center gap-2.5">
            <div className={`w-3 h-3 rounded-full ${statusDotColors[agent.status]} ${
              agent.status === 'online' ? 'animate-pulse' : ''
            }`} />
            <h3 className="text-lg font-bold">{agent.hostname}</h3>
            <Badge
              variant="outline"
              className={`text-[10px] ${
                agent.status === 'online'
                  ? 'bg-green-500/10 text-green-500 border-green-500/20'
                  : agent.status === 'warning'
                  ? 'bg-yellow-500/10 text-yellow-500 border-yellow-500/20'
                  : 'bg-red-500/10 text-red-500 border-red-500/20'
              }`}
            >
              {agent.status}
            </Badge>
          </div>
        </div>
        <Button
          size="sm"
          className="bg-primary hover:bg-primary/90 text-primary-foreground"
          onClick={() => onCommand(agent)}
        >
          <Terminal className="h-3.5 w-3.5 mr-1.5" />
          Command
        </Button>
      </div>

      {/* Tabs */}
      <Tabs defaultValue="system" className="space-y-4">
        <TabsList className="bg-muted/50">
          <TabsTrigger value="system">System Info</TabsTrigger>
          <TabsTrigger value="telemetry">Telemetry</TabsTrigger>
          <TabsTrigger value="edr">EDR Scans</TabsTrigger>
          <TabsTrigger value="commands">Commands</TabsTrigger>
        </TabsList>

        {/* System Info Tab */}
        <TabsContent value="system">
          <Card className="border-border/50">
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-semibold">System Information</CardTitle>
            </CardHeader>
            <CardContent className="p-4 pt-0">
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-x-8 gap-y-3">
                {systemInfoRows.map((row) => (
                  <div key={row.label} className="flex items-start justify-between">
                    <span className="text-xs text-muted-foreground">{row.label}</span>
                    <span className="text-xs font-medium text-right max-w-[200px] truncate">{row.value}</span>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Telemetry Tab */}
        <TabsContent value="telemetry" className="space-y-4">
          <div className="flex items-center gap-2">
            <span className="text-xs text-muted-foreground">Time range:</span>
            {([1, 6, 24, 168] as const).map((h) => (
              <Button
                key={h}
                variant={telemetryHours === h ? 'default' : 'outline'}
                size="sm"
                className={`h-7 text-xs ${telemetryHours === h ? 'bg-primary/90' : 'border-border/50'}`}
                onClick={() => setTelemetryHours(h)}
              >
                {h < 24 ? `${h}h` : `${h / 24}d`}
              </Button>
            ))}
          </div>

          {/* CPU Chart */}
          <Card className="border-border/50">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-semibold">CPU Usage (%)</CardTitle>
            </CardHeader>
            <CardContent className="p-4 pt-0">
              <div className="h-[200px]">
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={telemetryData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="oklch(0.28 0.015 155)" />
                    <XAxis dataKey="time" tick={chartTickStyle} axisLine={false} tickLine={false} />
                    <YAxis tick={chartTickStyle} axisLine={false} tickLine={false} domain={[0, 100]} />
                    <RechartsTooltip contentStyle={chartTooltipStyle} labelStyle={chartLabelStyle} />
                    <Line type="monotone" dataKey="cpu" stroke="oklch(0.627 0.194 149.214)" strokeWidth={2} dot={false} />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>

          {/* Memory Chart */}
          <Card className="border-border/50">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-semibold">Memory Usage (%)</CardTitle>
            </CardHeader>
            <CardContent className="p-4 pt-0">
              <div className="h-[200px]">
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={telemetryData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="oklch(0.28 0.015 155)" />
                    <XAxis dataKey="time" tick={chartTickStyle} axisLine={false} tickLine={false} />
                    <YAxis tick={chartTickStyle} axisLine={false} tickLine={false} domain={[0, 100]} />
                    <RechartsTooltip contentStyle={chartTooltipStyle} labelStyle={chartLabelStyle} />
                    <defs>
                      <linearGradient id="memGradient" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="oklch(0.627 0.194 149.214)" stopOpacity={0.3} />
                        <stop offset="95%" stopColor="oklch(0.627 0.194 149.214)" stopOpacity={0} />
                      </linearGradient>
                    </defs>
                    <Area type="monotone" dataKey="memory" stroke="oklch(0.627 0.194 149.214)" fill="url(#memGradient)" strokeWidth={2} />
                  </AreaChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>

          {/* Network Chart */}
          <Card className="border-border/50">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-semibold">Network I/O (MB/s)</CardTitle>
            </CardHeader>
            <CardContent className="p-4 pt-0">
              <div className="h-[200px]">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={telemetryData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="oklch(0.28 0.015 155)" />
                    <XAxis dataKey="time" tick={chartTickStyle} axisLine={false} tickLine={false} />
                    <YAxis tick={chartTickStyle} axisLine={false} tickLine={false} />
                    <RechartsTooltip contentStyle={chartTooltipStyle} labelStyle={chartLabelStyle} />
                    <Bar dataKey="netIn" fill="oklch(0.627 0.194 149.214)" radius={[2, 2, 0, 0]} name="Inbound" />
                    <Bar dataKey="netOut" fill="oklch(0.55 0.15 180)" radius={[2, 2, 0, 0]} name="Outbound" />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* EDR Scans Tab */}
        <TabsContent value="edr">
          <Card className="border-border/50">
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-semibold">EDR Scan History</CardTitle>
            </CardHeader>
            <CardContent className="p-4 pt-0">
              <div className="space-y-3">
                {scanData.map((scan) => (
                  <div key={scan.id} className="rounded-lg border border-border/50 p-3 space-y-2">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Shield className="h-3.5 w-3.5 text-primary" />
                        <span className="text-xs font-semibold">{scan.type}</span>
                      </div>
                      <Badge variant="outline" className={`text-[10px] ${commandStatusColors[scan.status]}`}>
                        {scan.status}
                      </Badge>
                    </div>
                    <div className="flex items-center gap-3 text-[10px] text-muted-foreground">
                      <span>Started: {relativeTime(scan.startedAt)}</span>
                      {scan.completedAt && <span>Completed: {relativeTime(scan.completedAt)}</span>}
                      <span>{scan.findings.length} findings</span>
                    </div>
                    {scan.findings.length > 0 && (
                      <div className="space-y-1.5 pl-1">
                        {scan.findings.map((f, idx) => (
                          <div key={idx} className="rounded-md bg-muted/30 p-2 space-y-0.5">
                            <div className="flex items-center gap-1.5">
                              <Badge variant="outline" className={`text-[9px] ${severityColors[f.severity]}`}>
                                {f.severity}
                              </Badge>
                              <span className="text-xs font-medium">{f.title}</span>
                            </div>
                            <p className="text-[11px] text-muted-foreground">{f.description}</p>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* Commands Tab */}
        <TabsContent value="commands">
          <Card className="border-border/50">
            <CardHeader className="pb-3">
              <div className="flex items-center justify-between">
                <CardTitle className="text-sm font-semibold">Command History</CardTitle>
                <Select value={cmdFilter} onValueChange={setCmdFilter}>
                  <SelectTrigger className="w-[130px] h-7 text-xs border-border/50">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Status</SelectItem>
                    <SelectItem value="completed">Completed</SelectItem>
                    <SelectItem value="running">Running</SelectItem>
                    <SelectItem value="failed">Failed</SelectItem>
                    <SelectItem value="pending">Pending</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </CardHeader>
            <CardContent className="p-4 pt-0">
              <div className="space-y-2">
                {filteredCommands.map((cmd) => (
                  <div key={cmd.id} className="rounded-lg border border-border/50 p-3 space-y-1.5">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Command className="h-3.5 w-3.5 text-muted-foreground" />
                        <span className="text-xs font-semibold">{cmd.type}</span>
                        {cmd.payload && (
                          <span className="text-[10px] text-muted-foreground font-mono truncate max-w-[200px]">
                            — {cmd.payload}
                          </span>
                        )}
                      </div>
                      <Badge variant="outline" className={`text-[10px] shrink-0 ${commandStatusColors[cmd.status]}`}>
                        {cmd.status === 'completed' && <CheckCircle className="h-2.5 w-2.5 mr-0.5" />}
                        {cmd.status === 'failed' && <XCircle className="h-2.5 w-2.5 mr-0.5" />}
                        {cmd.status === 'running' && <RefreshCw className="h-2.5 w-2.5 mr-0.5 animate-spin" />}
                        {cmd.status}
                      </Badge>
                    </div>
                    <div className="text-[10px] text-muted-foreground">
                      {relativeTime(cmd.createdAt)}
                    </div>
                    {cmd.result && (
                      <pre className="text-[11px] text-muted-foreground font-mono bg-muted/20 rounded p-1.5 overflow-x-auto">
                        {cmd.result}
                      </pre>
                    )}
                  </div>
                ))}
                {filteredCommands.length === 0 && (
                  <p className="text-xs text-muted-foreground text-center py-6">No commands match the selected filter.</p>
                )}
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}

// ─── Main Agents View ────────────────────────────────────────────────────────

export function AgentsView() {
  const { user, wsConnected, currentTenantId } = useAppStore()
  const [agents, setAgents] = useState<Agent[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedAgent, setSelectedAgent] = useState<Agent | null>(null)
  const [c2Agent, setC2Agent] = useState<Agent | null>(null)
  const [c2Open, setC2Open] = useState(false)
  const [autoRefresh, setAutoRefresh] = useState(true)
  const [tenantFilter, setTenantFilter] = useState<string>('all')
  const [tenants, setTenants] = useState<{id: string, name: string}[]>([])

  const isSuperAdmin = user?.role === 'super_admin'

  // Fetch tenants list for super_admin filter
  useEffect(() => {
    if (isSuperAdmin && tenants.length === 0) {
      fetch('/api/tenants')
        .then(r => r.json())
        .then((data) => {
          if (Array.isArray(data)) setTenants(data.map((t: any) => ({ id: t.id, name: t.name })))
        })
        .catch(() => {
          setTenants([
            { id: 'all', name: 'All Tenants' },
            { id: 't1', name: 'Acme Corp' },
            { id: 't2', name: 'TechStart Inc' },
          ])
        })
    }
  }, [isSuperAdmin, tenants.length])

  const fetchAgents = useCallback(async () => {
    try {
      const res = await fetch('/api/agents/list')
      if (res.ok) {
        const data = await res.json()
        setAgents(data)
      } else {
        setAgents(generateMockAgents())
      }
    } catch {
      setAgents(generateMockAgents())
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchAgents()
  }, [fetchAgents])

  useEffect(() => {
    if (!autoRefresh) return
    const interval = setInterval(fetchAgents, 30000)
    return () => clearInterval(interval)
  }, [autoRefresh, fetchAgents])

  const onlineCount = agents.filter((a) => a.status === 'online').length
  const offlineCount = agents.filter((a) => a.status === 'offline').length
  const warningCount = agents.filter((a) => a.status === 'warning').length

  const handleScan = (agent: Agent) => {
    setC2Agent(agent)
    setC2Open(true)
  }

  const handleCommand = (agent: Agent) => {
    setC2Agent(agent)
    setC2Open(true)
  }

  // Filter agents by tenant if super_admin
  const filteredAgents = tenantFilter === 'all' ? agents : agents

  return (
    <TooltipProvider>
      <div className="space-y-6">
        {/* Page Header */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <div>
              <h2 className="text-xl font-bold flex items-center gap-2">
                <Activity className="h-5 w-5 text-primary" />
                Agent Management
              </h2>
              <p className="text-sm text-muted-foreground mt-1">
                Monitor and manage deployed CBUP agents across your infrastructure
              </p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            {/* Tenant filter for super_admin */}
            {isSuperAdmin && (
              <Select value={tenantFilter} onValueChange={setTenantFilter}>
                <SelectTrigger className="w-[180px] h-8 text-xs border-border/50">
                  <Building2 className="h-3 w-3 mr-1.5 text-primary" />
                  <SelectValue placeholder="All Tenants" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Tenants</SelectItem>
                  {tenants.filter(t => t.id !== 'all').map(t => (
                    <SelectItem key={t.id} value={t.id}>{t.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
            <DeployAgentDialog />
          </div>
        </div>

        {/* Live Indicator */}
        <div className={`flex items-center gap-2 px-3 py-2 rounded-lg border ${
          wsConnected
            ? 'bg-green-500/5 border-green-500/20'
            : 'bg-muted/30 border-border/50'
        }`}>
          <span className={`w-2 h-2 rounded-full ${wsConnected ? 'bg-green-500 animate-pulse' : 'bg-gray-500'}`} />
          <span className={`text-xs font-medium ${wsConnected ? 'text-green-500' : 'text-muted-foreground'}`}>
            {wsConnected ? 'LIVE' : 'OFFLINE'}
          </span>
          <span className="text-xs text-muted-foreground">—</span>
          <span className="text-xs text-muted-foreground">
            {wsConnected
              ? `Connected to ${onlineCount} agent${onlineCount !== 1 ? 's' : ''} • Real-time updates active`
              : 'Real-time connection not established'
            }
          </span>
        </div>

        {/* Summary Bar */}
        <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-6 gap-3">
          <Card className="border-border/50">
            <CardContent className="p-3 flex flex-col items-center justify-center">
              <span className="text-2xl font-bold">{agents.length}</span>
              <span className="text-xs text-muted-foreground">Total Agents</span>
            </CardContent>
          </Card>
          <Card className="border-border/50">
            <CardContent className="p-3 flex flex-col items-center justify-center">
              <span className="text-2xl font-bold text-green-500">{onlineCount}</span>
              <span className="text-xs text-muted-foreground flex items-center gap-1">
                <div className="w-1.5 h-1.5 rounded-full bg-green-500" /> Online
              </span>
            </CardContent>
          </Card>
          <Card className="border-border/50">
            <CardContent className="p-3 flex flex-col items-center justify-center">
              <span className="text-2xl font-bold text-red-500">{offlineCount}</span>
              <span className="text-xs text-muted-foreground flex items-center gap-1">
                <div className="w-1.5 h-1.5 rounded-full bg-red-500" /> Offline
              </span>
            </CardContent>
          </Card>
          <Card className="border-border/50">
            <CardContent className="p-3 flex flex-col items-center justify-center">
              <span className="text-2xl font-bold text-yellow-500">{warningCount}</span>
              <span className="text-xs text-muted-foreground flex items-center gap-1">
                <AlertTriangle className="h-3 w-3 text-yellow-500" /> Warning
              </span>
            </CardContent>
          </Card>

          {/* Refresh controls */}
          <Card className="border-border/50">
            <CardContent className="p-3 flex items-center justify-center gap-2">
              <Button
                variant="ghost"
                size="sm"
                className="h-8 w-8 p-0"
                onClick={fetchAgents}
              >
                <RefreshCw className={`h-3.5 w-3.5 ${loading ? 'animate-spin' : ''}`} />
              </Button>
              <div className="flex items-center gap-1.5">
                <Switch checked={autoRefresh} onCheckedChange={setAutoRefresh} className="scale-90" />
                <span className="text-[11px] text-muted-foreground">Auto</span>
              </div>
            </CardContent>
          </Card>

          {/* Quick deploy */}
          <Card className="border-border/50 hidden lg:block">
            <CardContent className="p-3 flex flex-col items-center justify-center">
              <Terminal className="h-4 w-4 text-primary mb-0.5" />
              <span className="text-xs text-muted-foreground text-center">C2 Ready</span>
            </CardContent>
          </Card>
        </div>

        {/* Loading state */}
        {loading ? (
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
            {[1, 2, 3, 4, 5, 6].map((i) => (
              <Card key={i} className="border-border/50 animate-pulse">
                <CardContent className="p-4 space-y-3">
                  <div className="flex items-center gap-2">
                    <div className="w-2.5 h-2.5 rounded-full bg-muted" />
                    <div className="h-4 w-24 bg-muted rounded" />
                  </div>
                  <div className="h-3 w-36 bg-muted rounded" />
                  <div className="space-y-1.5">
                    <div className="h-2 w-full bg-muted rounded" />
                    <div className="h-2 w-full bg-muted rounded" />
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        ) : selectedAgent ? (
          /* Detail Panel */
          <AgentDetailPanel
            agent={selectedAgent}
            onCommand={handleCommand}
            onClose={() => setSelectedAgent(null)}
          />
        ) : (
          /* Agent Grid */
          <>
            {agents.length === 0 ? (
              <Card className="border-border/50">
                <CardContent className="p-12 text-center">
                  <Server className="h-10 w-10 text-muted-foreground mx-auto mb-3" />
                  <p className="text-sm text-muted-foreground">No agents deployed yet</p>
                  <p className="text-xs text-muted-foreground mt-1">Deploy your first agent to start monitoring endpoints.</p>
                </CardContent>
              </Card>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
                {filteredAgents.map((agent) => (
                  <AgentCard
                    key={agent.id}
                    agent={agent}
                    onSelect={setSelectedAgent}
                    onCommand={handleCommand}
                    onScan={handleScan}
                    selected={false}
                  />
                ))}
              </div>
            )}
          </>
        )}

        {/* C2 Command Dialog */}
        <C2CommandDialog
          agent={c2Agent}
          open={c2Open}
          onClose={() => { setC2Open(false); setC2Agent(null) }}
        />
      </div>
    </TooltipProvider>
  )
}
