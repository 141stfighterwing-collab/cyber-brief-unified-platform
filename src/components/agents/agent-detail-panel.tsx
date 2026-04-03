'use client'

import { useState, useMemo } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
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
import {
  ChevronLeft,
  Shield,
  Terminal,
  Command,
  CheckCircle,
  XCircle,
  RefreshCw,
} from 'lucide-react'
import type { Agent } from './types'
import {
  statusDotColors,
  commandStatusColors,
  severityColors,
  relativeTime,
  chartTooltipStyle,
  chartLabelStyle,
  chartTickStyle,
} from './helpers'
import { generateTelemetry, generateScans, generateCommands } from './mock-data'

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

export { AgentDetailPanel }
export type { AgentDetailPanelProps }
