'use client'

import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
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
  PieChart, Pie, Cell,
  BarChart, Bar,
  XAxis, YAxis, Tooltip as RechartsTooltip,
  ResponsiveContainer,
  CartesianGrid,
  RadarChart, Radar, PolarGrid, PolarAngleAxis, PolarRadiusAxis,
} from 'recharts'
import {
  Crown, Building2, Users, Monitor, Wifi, WifiOff, AlertTriangle,
  Shield, Activity, Plus, Trash2, Edit, Search, RefreshCw, ChevronDown, ChevronUp,
  Terminal, Play, CheckCircle, XCircle, Clock, Eye, Server, Zap,
} from 'lucide-react'
import { useAppStore } from '@/lib/store'

// ─── Chart Styles ────────────────────────────────────────────────────────────

const chartTooltipStyle = {
  backgroundColor: 'oklch(0.17 0.01 155)',
  border: '1px solid oklch(0.28 0.015 155)',
  borderRadius: '8px',
  fontSize: '12px',
}

const chartLabelStyle = { color: 'oklch(0.95 0.01 155)' }
const chartTickStyle = { fontSize: 11, fill: 'oklch(0.5 0.02 155)' as const }

// ─── Types ───────────────────────────────────────────────────────────────────

interface PlatformStats {
  totalTenants: number
  totalUsers: number
  totalEndpoints: number
  onlineEndpoints: number
  offlineEndpoints: number
  activeAlerts: number
  edrScansToday: number
  systemHealth: { apiLatency: number; dbLatency: number; wsConnections: number; queueDepth: number; uptime: string }
  tenantStats: { name: string; agents: number; online: number; users: number }[]
  recentAlerts: { id: string; title: string; severity: string; tenant: string; time: string }[]
  agentStatusDistribution: { name: string; value: number; color: string }[]
}

interface Tenant {
  id: string; name: string; slug: string; description: string; plan: string
  maxAgents: number; agentCount: number; userCount: number; status: string
  createdAt: string
}

interface CrossTenantAgent {
  id: string; hostname: string; tenant: string; os: string; status: string
  cpu: number; memory: number; lastSeen: string; version: string; ip: string
}

interface AdminUser {
  id: string; email: string; name: string; role: string; company: string
  tenants: string[]; createdAt: string
}

interface ActivityEvent {
  id: string; type: string; message: string; tenant: string; timestamp: string; icon: string
}

// ─── Severity / Status Colors ────────────────────────────────────────────────

const severityBadge: Record<string, string> = {
  critical: 'bg-red-500/10 text-red-500 border-red-500/20',
  high: 'bg-orange-500/10 text-orange-500 border-orange-500/20',
  medium: 'bg-yellow-500/10 text-yellow-500 border-yellow-500/20',
  low: 'bg-green-500/10 text-green-500 border-green-500/20',
  info: 'bg-muted text-muted-foreground border-border',
}

const statusBadge: Record<string, string> = {
  active: 'bg-green-500/10 text-green-500 border-green-500/20',
  suspended: 'bg-yellow-500/10 text-yellow-500 border-yellow-500/20',
  trial: 'bg-blue-500/10 text-blue-500 border-blue-500/20',
}

const roleBadge: Record<string, string> = {
  super_admin: 'bg-purple-500/10 text-purple-500 border-purple-500/20',
  admin: 'bg-primary/10 text-primary border-primary/20',
  user: 'bg-muted text-muted-foreground border-border',
}

const agentStatusBadge: Record<string, string> = {
  online: 'bg-green-500/10 text-green-500 border-green-500/20',
  offline: 'bg-red-500/10 text-red-500 border-red-500/20',
  warning: 'bg-yellow-500/10 text-yellow-500 border-yellow-500/20',
  critical: 'bg-orange-500/10 text-orange-500 border-orange-500/20',
}

const planBadge: Record<string, string> = {
  enterprise: 'bg-primary/10 text-primary border-primary/20',
  pro: 'bg-blue-500/10 text-blue-500 border-blue-500/20',
  business: 'bg-amber-500/10 text-amber-500 border-amber-500/20',
  free: 'bg-muted text-muted-foreground border-border',
}

// ─── Mock Activity Events ────────────────────────────────────────────────────

function generateActivityEvents(): ActivityEvent[] {
  return [
    { id: 'ev-1', type: 'agent', message: 'Agent WS-DC-01 registered with Acme Corp', tenant: 'Acme Corp', timestamp: '2 min ago', icon: 'Monitor' },
    { id: 'ev-2', type: 'heartbeat', message: 'Bulk heartbeat received: 3,156 agents online', tenant: 'All', timestamp: '5 min ago', icon: 'Activity' },
    { id: 'ev-3', type: 'alert', message: 'Critical alert: C2 beacon detected on WS-DC-01', tenant: 'Acme Corp', timestamp: '8 min ago', icon: 'AlertTriangle' },
    { id: 'ev-4', type: 'scan', message: 'EDR Full Scan completed on SVR-GLO-003 — 0 findings', tenant: 'Global Financial', timestamp: '15 min ago', icon: 'Shield' },
    { id: 'ev-5', type: 'command', message: 'Command "Block IP 185.220.101.xx" executed on WS-DC-01', tenant: 'Acme Corp', timestamp: '18 min ago', icon: 'Terminal' },
    { id: 'ev-6', type: 'user', message: 'User james.chen@acme.com logged in', tenant: 'Acme Corp', timestamp: '22 min ago', icon: 'Users' },
    { id: 'ev-7', type: 'scan', message: 'Vulnerability assessment scan started for HealthCare Plus', tenant: 'HealthCare Plus', timestamp: '30 min ago', icon: 'Search' },
    { id: 'ev-8', type: 'agent', message: 'Agent LNX-TEC-012 status changed: online → warning', tenant: 'TechStart Inc', timestamp: '35 min ago', icon: 'AlertTriangle' },
    { id: 'ev-9', type: 'report', message: 'Report "EDR Scan Summary" generated for Acme Corp', tenant: 'Acme Corp', timestamp: '45 min ago', icon: 'CheckCircle' },
    { id: 'ev-10', type: 'user', message: 'User sarah.wilson@techstart.io assigned admin role', tenant: 'TechStart Inc', timestamp: '1 hr ago', icon: 'Users' },
    { id: 'ev-11', type: 'command', message: 'Bulk command: Agent update v2.4.1 deployed to 234 endpoints', tenant: 'All', timestamp: '1.5 hr ago', icon: 'Zap' },
    { id: 'ev-12', type: 'alert', message: 'Medium alert: SSH brute force from 45.33.xx.xx blocked', tenant: 'EduNetwork', timestamp: '2 hr ago', icon: 'Shield' },
    { id: 'ev-13', type: 'tenant', message: 'New tenant "SecureNet Demo" created (trial)', tenant: 'Platform', timestamp: '3 hr ago', icon: 'Building2' },
    { id: 'ev-14', type: 'agent', message: 'Agent WS-WK-014 offline for 48h — Escalation triggered', tenant: 'Acme Corp', timestamp: '4 hr ago', icon: 'AlertTriangle' },
    { id: 'ev-15', type: 'system', message: 'Platform maintenance window completed — all services healthy', tenant: 'Platform', timestamp: '6 hr ago', icon: 'Server' },
  ]
}

// ─── Main Component ──────────────────────────────────────────────────────────

export function SuperAdminView() {
  const [stats, setStats] = useState<PlatformStats | null>(null)
  const [tenants, setTenants] = useState<Tenant[]>([])
  const [agents, setAgents] = useState<CrossTenantAgent[]>([])
  const [users, setUsers] = useState<AdminUser[]>([])
  const [activities, setActivities] = useState<ActivityEvent[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function loadData() {
      setLoading(true)
      try {
        const [statsRes, tenantsRes, agentsRes, usersRes] = await Promise.allSettled([
          fetch('/api/admin/stats').then(r => r.json()),
          fetch('/api/tenants').then(r => r.json()),
          fetch('/api/admin/agents').then(r => r.json()),
          fetch('/api/admin/users').then(r => r.json()),
        ])

        if (statsRes.status === 'fulfilled') setStats(statsRes.value)
        if (tenantsRes.status === 'fulfilled') setTenants(Array.isArray(tenantsRes.value) ? tenantsRes.value : [])
        if (agentsRes.status === 'fulfilled') setAgents(Array.isArray(agentsRes.value) ? agentsRes.value : [])
        if (usersRes.status === 'fulfilled') setUsers(Array.isArray(usersRes.value) ? usersRes.value : [])
      } catch {
        // Use fallback defaults
      }
      setActivities(generateActivityEvents())
      setLoading(false)
    }
    loadData()
  }, [])

  if (loading) return <LoadingSkeleton />

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-lg bg-purple-500/10 flex items-center justify-center">
          <Crown className="h-5 w-5 text-purple-500" />
        </div>
        <div>
          <h1 className="text-xl font-bold">Super Admin Console</h1>
          <p className="text-xs text-muted-foreground">Platform-wide management and monitoring</p>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        <StatCard icon={Building2} label="Total Tenants" value={stats?.totalTenants ?? 0} color="purple" />
        <StatCard icon={Users} label="Total Users" value={stats?.totalUsers ?? 0} color="blue" />
        <StatCard icon={Monitor} label="Total Endpoints" value={stats?.totalEndpoints ?? 0} color="green" />
        <StatCard icon={Wifi} label="Online" value={stats?.onlineEndpoints ?? 0} color="emerald" />
        <StatCard icon={WifiOff} label="Offline" value={stats?.offlineEndpoints ?? 0} color="red" />
        <StatCard icon={AlertTriangle} label="Active Alerts" value={stats?.activeAlerts ?? 0} color="amber" />
      </div>

      {/* Tabs */}
      <Tabs defaultValue="overview">
        <TabsList className="bg-muted/50">
          <TabsTrigger value="overview">Overview</TabsTrigger>
          <TabsTrigger value="tenants">Tenants</TabsTrigger>
          <TabsTrigger value="endpoints">All Endpoints</TabsTrigger>
          <TabsTrigger value="users">Users</TabsTrigger>
          <TabsTrigger value="activity">Activity Log</TabsTrigger>
        </TabsList>

        {/* ── Overview Tab ─────────────────────────────────────────── */}
        <TabsContent value="overview" className="space-y-4 mt-4">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            {/* Agent Status Pie */}
            <Card className="border-border/50">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-semibold">Agent Status Distribution</CardTitle>
              </CardHeader>
              <CardContent className="p-4 pt-0">
                <div className="h-[280px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                      <Pie data={stats?.agentStatusDistribution ?? []} cx="50%" cy="50%" innerRadius={60} outerRadius={100} dataKey="value" label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`} labelLine={false}>
                        {(stats?.agentStatusDistribution ?? []).map((entry, idx) => (
                          <Cell key={idx} fill={entry.color} />
                        ))}
                      </Pie>
                      <RechartsTooltip contentStyle={chartTooltipStyle} labelStyle={chartLabelStyle} />
                    </PieChart>
                  </ResponsiveContainer>
                </div>
              </CardContent>
            </Card>

            {/* Top Tenants Bar */}
            <Card className="border-border/50">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-semibold">Top Tenants by Agent Count</CardTitle>
              </CardHeader>
              <CardContent className="p-4 pt-0">
                <div className="h-[280px]">
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={stats?.tenantStats?.slice(0, 8) ?? []} layout="vertical">
                      <CartesianGrid strokeDasharray="3 3" stroke="oklch(0.28 0.015 155)" />
                      <XAxis type="number" tick={chartTickStyle} axisLine={false} tickLine={false} />
                      <YAxis dataKey="name" type="category" width={100} tick={chartTickStyle} axisLine={false} tickLine={false} />
                      <RechartsTooltip contentStyle={chartTooltipStyle} labelStyle={chartLabelStyle} />
                      <Bar dataKey="agents" fill="oklch(0.627 0.194 149.214)" radius={[0, 4, 4, 0]} name="Agents" />
                      <Bar dataKey="online" fill="oklch(0.55 0.15 155)" radius={[0, 4, 4, 0]} name="Online" />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* System Health */}
          {stats?.systemHealth && (
            <Card className="border-border/50">
              <CardHeader className="pb-3">
                <CardTitle className="text-sm font-semibold flex items-center gap-2">
                  <Server className="h-4 w-4 text-primary" />
                  System Health
                </CardTitle>
              </CardHeader>
              <CardContent className="p-4 pt-0">
                <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
                  <HealthMetric label="API Latency" value={`${stats.systemHealth.apiLatency}ms`} status={stats.systemHealth.apiLatency < 50 ? 'good' : 'warning'} />
                  <HealthMetric label="DB Latency" value={`${stats.systemHealth.dbLatency}ms`} status={stats.systemHealth.dbLatency < 20 ? 'good' : 'warning'} />
                  <HealthMetric label="WS Connections" value={stats.systemHealth.wsConnections.toLocaleString()} status={stats.systemHealth.wsConnections > 0 ? 'good' : 'error'} />
                  <HealthMetric label="Queue Depth" value={String(stats.systemHealth.queueDepth)} status={stats.systemHealth.queueDepth < 50 ? 'good' : 'warning'} />
                  <HealthMetric label="Uptime" value={stats.systemHealth.uptime} status="good" />
                </div>
              </CardContent>
            </Card>
          )}

          {/* Recent Alerts Table */}
          <Card className="border-border/50">
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-semibold">Recent Platform Alerts</CardTitle>
            </CardHeader>
            <CardContent className="p-4 pt-0">
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow className="border-border/50 hover:bg-transparent">
                      <TableHead className="text-xs">Severity</TableHead>
                      <TableHead className="text-xs">Alert</TableHead>
                      <TableHead className="text-xs">Tenant</TableHead>
                      <TableHead className="text-xs">Time</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {(stats?.recentAlerts ?? []).map((alert) => (
                      <TableRow key={alert.id} className="border-border/30">
                        <TableCell className="py-2">
                          <Badge variant="outline" className={`text-[10px] ${severityBadge[alert.severity] ?? ''}`}>
                            {alert.severity}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-xs py-2">{alert.title}</TableCell>
                        <TableCell className="text-xs py-2 text-muted-foreground">{alert.tenant}</TableCell>
                        <TableCell className="text-xs py-2 text-muted-foreground">{alert.time}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* ── Tenants Tab ──────────────────────────────────────────── */}
        <TabsContent value="tenants" className="space-y-4 mt-4">
          <div className="flex items-center justify-between">
            <Input placeholder="Search tenants..." className="max-w-sm h-8 text-xs border-border/50" />
            <CreateTenantDialog />
          </div>
          <Card className="border-border/50">
            <CardContent className="p-4">
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow className="border-border/50 hover:bg-transparent">
                      <TableHead className="text-xs">Name</TableHead>
                      <TableHead className="text-xs">Plan</TableHead>
                      <TableHead className="text-xs">Agents</TableHead>
                      <TableHead className="text-xs">Users</TableHead>
                      <TableHead className="text-xs">Status</TableHead>
                      <TableHead className="text-xs">Created</TableHead>
                      <TableHead className="text-xs text-right">Actions</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {tenants.map((tenant) => (
                      <TenantRow key={tenant.id} tenant={tenant} />
                    ))}
                  </TableBody>
                </Table>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* ── All Endpoints Tab ────────────────────────────────────── */}
        <TabsContent value="endpoints" className="space-y-4 mt-4">
          <EndpointsSection agents={agents} />
        </TabsContent>

        {/* ── Users Tab ───────────────────────────────────────────── */}
        <TabsContent value="users" className="space-y-4 mt-4">
          <UsersSection users={users} setUsers={setUsers} />
        </TabsContent>

        {/* ── Activity Log Tab ────────────────────────────────────── */}
        <TabsContent value="activity" className="space-y-4 mt-4">
          <ActivitySection activities={activities} />
        </TabsContent>
      </Tabs>
    </div>
  )
}

// ─── Stat Card ───────────────────────────────────────────────────────────────

function StatCard({ icon: Icon, label, value, color }: { icon: any; label: string; value: number; color: string }) {
  const colorMap: Record<string, string> = {
    purple: 'bg-purple-500/10 text-purple-500',
    blue: 'bg-blue-500/10 text-blue-500',
    green: 'bg-green-500/10 text-green-500',
    emerald: 'bg-emerald-500/10 text-emerald-500',
    red: 'bg-red-500/10 text-red-500',
    amber: 'bg-amber-500/10 text-amber-500',
  }
  return (
    <Card className="border-border/50">
      <CardContent className="p-3 flex items-center gap-3">
        <div className={`w-8 h-8 rounded-lg flex items-center justify-center shrink-0 ${colorMap[color] ?? ''}`}>
          <Icon className="h-4 w-4" />
        </div>
        <div className="min-w-0">
          <p className="text-lg font-bold leading-tight">{value.toLocaleString()}</p>
          <p className="text-[10px] text-muted-foreground leading-tight">{label}</p>
        </div>
      </CardContent>
    </Card>
  )
}

// ─── Health Metric ───────────────────────────────────────────────────────────

function HealthMetric({ label, value, status }: { label: string; value: string; status: 'good' | 'warning' | 'error' }) {
  const colors = { good: 'text-green-500', warning: 'text-yellow-500', error: 'text-red-500' }
  const dots = { good: 'bg-green-500', warning: 'bg-yellow-500', error: 'bg-red-500' }
  return (
    <div className="text-center space-y-1">
      <div className="flex items-center justify-center gap-1.5">
        <span className={`w-2 h-2 rounded-full ${dots[status]} ${status === 'good' ? 'animate-pulse' : ''}`} />
        <span className="text-xs text-muted-foreground">{label}</span>
      </div>
      <p className={`text-lg font-bold ${colors[status]}`}>{value}</p>
    </div>
  )
}

// ─── Tenant Row (expandable) ─────────────────────────────────────────────────

function TenantRow({ tenant }: { tenant: Tenant }) {
  const [expanded, setExpanded] = useState(false)

  return (
    <>
      <TableRow className="border-border/30 cursor-pointer hover:bg-muted/30" onClick={() => setExpanded(!expanded)}>
        <TableCell className="py-2.5">
          <div className="flex items-center gap-2">
            <Building2 className="h-3.5 w-3.5 text-primary" />
            <div>
              <p className="text-xs font-medium">{tenant.name}</p>
              <p className="text-[10px] text-muted-foreground">{tenant.slug}</p>
            </div>
          </div>
        </TableCell>
        <TableCell className="py-2.5">
          <Badge variant="outline" className={`text-[10px] ${planBadge[tenant.plan] ?? ''}`}>
            {tenant.plan}
          </Badge>
        </TableCell>
        <TableCell className="text-xs py-2.5">{tenant.agentCount} / {tenant.maxAgents}</TableCell>
        <TableCell className="text-xs py-2.5">{tenant.userCount}</TableCell>
        <TableCell className="py-2.5">
          <Badge variant="outline" className={`text-[10px] ${statusBadge[tenant.status] ?? ''}`}>
            {tenant.status}
          </Badge>
        </TableCell>
        <TableCell className="text-xs text-muted-foreground py-2.5">{new Date(tenant.createdAt).toLocaleDateString()}</TableCell>
        <TableCell className="py-2.5 text-right">
          <div className="flex items-center justify-end gap-1">
            <Button variant="ghost" size="sm" className="h-7 w-7 p-0" onClick={(e) => { e.stopPropagation() }}>
              <Edit className="h-3.5 w-3.5" />
            </Button>
            <Button variant="ghost" size="sm" className="h-7 w-7 p-0 text-red-500" onClick={(e) => { e.stopPropagation() }}>
              <Trash2 className="h-3.5 w-3.5" />
            </Button>
            {expanded ? <ChevronUp className="h-3.5 w-3.5 text-muted-foreground" /> : <ChevronDown className="h-3.5 w-3.5 text-muted-foreground" />}
          </div>
        </TableCell>
      </TableRow>
      {expanded && (
        <TableRow className="border-border/30 bg-muted/20">
          <TableCell colSpan={7} className="py-3 px-6">
            <div className="text-xs text-muted-foreground space-y-1">
              <p><span className="font-medium text-foreground">Description:</span> {tenant.description}</p>
              <div className="flex items-center gap-4 pt-1">
                <span className="flex items-center gap-1"><Monitor className="h-3 w-3" /> {tenant.agentCount} agents deployed</span>
                <span className="flex items-center gap-1"><Users className="h-3 w-3" /> {tenant.userCount} users</span>
                <span className="flex items-center gap-1"><Clock className="h-3 w-3" /> Created {new Date(tenant.createdAt).toLocaleDateString()}</span>
              </div>
            </div>
          </TableCell>
        </TableRow>
      )}
    </>
  )
}

// ─── Create Tenant Dialog ────────────────────────────────────────────────────

function CreateTenantDialog() {
  const [open, setOpen] = useState(false)
  const [name, setName] = useState('')
  const [slug, setSlug] = useState('')
  const [description, setDescription] = useState('')
  const [plan, setPlan] = useState('pro')
  const [maxAgents, setMaxAgents] = useState('100')
  const [submitting, setSubmitting] = useState(false)

  const handleCreate = async () => {
    setSubmitting(true)
    try {
      await fetch('/api/tenants', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, slug, description, plan, maxAgents: parseInt(maxAgents) }),
      })
      setOpen(false)
      setName(''); setSlug(''); setDescription(''); setPlan('pro'); setMaxAgents('100')
    } catch { /* silent */ }
    setSubmitting(false)
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="bg-primary hover:bg-primary/90 text-primary-foreground h-8 text-xs">
          <Plus className="h-3.5 w-3.5 mr-1.5" />
          Create Tenant
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-md border-border/50 bg-card">
        <DialogHeader>
          <DialogTitle>Create New Tenant</DialogTitle>
          <DialogDescription>Add a new organization to the platform.</DialogDescription>
        </DialogHeader>
        <div className="space-y-3 py-2">
          <div className="space-y-1">
            <label className="text-xs font-medium text-muted-foreground">Name</label>
            <Input className="h-8 text-xs border-border/50" value={name} onChange={(e) => setName(e.target.value)} placeholder="Company Name" />
          </div>
          <div className="space-y-1">
            <label className="text-xs font-medium text-muted-foreground">Slug</label>
            <Input className="h-8 text-xs border-border/50" value={slug} onChange={(e) => setSlug(e.target.value)} placeholder="company-slug" />
          </div>
          <div className="space-y-1">
            <label className="text-xs font-medium text-muted-foreground">Description</label>
            <Input className="h-8 text-xs border-border/50" value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Brief description" />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1">
              <label className="text-xs font-medium text-muted-foreground">Plan</label>
              <Select value={plan} onValueChange={setPlan}>
                <SelectTrigger className="h-8 text-xs border-border/50"><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="free">Free</SelectItem>
                  <SelectItem value="business">Business</SelectItem>
                  <SelectItem value="pro">Pro</SelectItem>
                  <SelectItem value="enterprise">Enterprise</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1">
              <label className="text-xs font-medium text-muted-foreground">Max Agents</label>
              <Input className="h-8 text-xs border-border/50" type="number" value={maxAgents} onChange={(e) => setMaxAgents(e.target.value)} />
            </div>
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => setOpen(false)} className="border-border/50 text-xs">Cancel</Button>
          <Button onClick={handleCreate} disabled={submitting || !name.trim()} className="bg-primary hover:bg-primary/90 text-primary-foreground text-xs">
            {submitting && <RefreshCw className="h-3 w-3 mr-1.5 animate-spin" />}
            Create Tenant
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// ─── Endpoints Section ───────────────────────────────────────────────────────

function EndpointsSection({ agents }: { agents: CrossTenantAgent[] }) {
  const [search, setSearch] = useState('')
  const [tenantFilter, setTenantFilter] = useState('all')
  const [statusFilter, setStatusFilter] = useState('all')
  const [osFilter, setOsFilter] = useState('all')

  const uniqueTenants = [...new Set(agents.map(a => a.tenant))]
  const uniqueOs = [...new Set(agents.map(a => a.os))]

  const filtered = agents.filter(a => {
    if (search && !a.hostname.toLowerCase().includes(search.toLowerCase()) && !a.tenant.toLowerCase().includes(search.toLowerCase())) return false
    if (tenantFilter !== 'all' && a.tenant !== tenantFilter) return false
    if (statusFilter !== 'all' && a.status !== statusFilter) return false
    if (osFilter !== 'all' && a.os !== osFilter) return false
    return true
  })

  return (
    <>
      <div className="flex flex-wrap items-center gap-2">
        <Input placeholder="Search hostname or tenant..." className="max-w-xs h-8 text-xs border-border/50" value={search} onChange={(e) => setSearch(e.target.value)} />
        <Select value={tenantFilter} onValueChange={setTenantFilter}>
          <SelectTrigger className="w-[160px] h-8 text-xs border-border/50"><SelectValue placeholder="All Tenants" /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All Tenants</SelectItem>
            {uniqueTenants.map(t => <SelectItem key={t} value={t}>{t}</SelectItem>)}
          </SelectContent>
        </Select>
        <Select value={statusFilter} onValueChange={setStatusFilter}>
          <SelectTrigger className="w-[120px] h-8 text-xs border-border/50"><SelectValue placeholder="All Status" /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All Status</SelectItem>
            <SelectItem value="online">Online</SelectItem>
            <SelectItem value="offline">Offline</SelectItem>
            <SelectItem value="warning">Warning</SelectItem>
          </SelectContent>
        </Select>
        <Select value={osFilter} onValueChange={setOsFilter}>
          <SelectTrigger className="w-[180px] h-8 text-xs border-border/50"><SelectValue placeholder="All OS" /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All OS</SelectItem>
            {uniqueOs.map(o => <SelectItem key={o} value={o}>{o}</SelectItem>)}
          </SelectContent>
        </Select>
        <Badge variant="outline" className="text-[10px] bg-muted">{filtered.length} agents</Badge>
      </div>
      <Card className="border-border/50">
        <CardContent className="p-4">
          <div className="overflow-x-auto max-h-[500px] overflow-y-auto">
            <Table>
              <TableHeader className="sticky top-0 bg-card z-10">
                <TableRow className="border-border/50 hover:bg-transparent">
                  <TableHead className="text-xs">Hostname</TableHead>
                  <TableHead className="text-xs">Tenant</TableHead>
                  <TableHead className="text-xs">OS</TableHead>
                  <TableHead className="text-xs">Status</TableHead>
                  <TableHead className="text-xs">CPU</TableHead>
                  <TableHead className="text-xs">RAM</TableHead>
                  <TableHead className="text-xs">IP</TableHead>
                  <TableHead className="text-xs">Version</TableHead>
                  <TableHead className="text-xs">Last Seen</TableHead>
                  <TableHead className="text-xs text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filtered.slice(0, 50).map((agent) => (
                  <TableRow key={agent.id} className="border-border/30">
                    <TableCell className="text-xs font-medium py-2">{agent.hostname}</TableCell>
                    <TableCell className="text-xs text-muted-foreground py-2">{agent.tenant}</TableCell>
                    <TableCell className="text-xs py-2">{agent.os}</TableCell>
                    <TableCell className="py-2">
                      <Badge variant="outline" className={`text-[10px] ${agentStatusBadge[agent.status] ?? ''}`}>
                        {agent.status}
                      </Badge>
                    </TableCell>
                    <TableCell className={`text-xs py-2 ${agent.cpu > 80 ? 'text-red-400 font-medium' : ''}`}>{agent.cpu}%</TableCell>
                    <TableCell className={`text-xs py-2 ${agent.memory > 85 ? 'text-red-400 font-medium' : ''}`}>{agent.memory}%</TableCell>
                    <TableCell className="text-xs font-mono text-muted-foreground py-2">{agent.ip}</TableCell>
                    <TableCell className="text-xs font-mono text-muted-foreground py-2">{agent.version}</TableCell>
                    <TableCell className="text-xs text-muted-foreground py-2">{new Date(agent.lastSeen).toLocaleString()}</TableCell>
                    <TableCell className="py-2 text-right">
                      <div className="flex items-center justify-end gap-1">
                        <Button variant="ghost" size="sm" className="h-7 w-7 p-0" title="Scan"><Shield className="h-3 w-3" /></Button>
                        <Button variant="ghost" size="sm" className="h-7 w-7 p-0" title="Command"><Terminal className="h-3 w-3" /></Button>
                        <Button variant="ghost" size="sm" className="h-7 w-7 p-0" title="View"><Eye className="h-3 w-3" /></Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        </CardContent>
      </Card>
    </>
  )
}

// ─── Users Section ───────────────────────────────────────────────────────────

function UsersSection({ users, setUsers }: { users: AdminUser[]; setUsers: (u: AdminUser[]) => void }) {
  const [roleFilter, setRoleFilter] = useState('all')

  const filtered = roleFilter === 'all' ? users : users.filter(u => u.role === roleFilter)

  const handleRoleChange = (userId: string, newRole: string) => {
    setUsers(users.map(u => u.id === userId ? { ...u, role: newRole } : u))
  }

  return (
    <>
      <div className="flex items-center gap-2">
        <Select value={roleFilter} onValueChange={setRoleFilter}>
          <SelectTrigger className="w-[140px] h-8 text-xs border-border/50"><SelectValue placeholder="All Roles" /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All Roles</SelectItem>
            <SelectItem value="super_admin">Super Admin</SelectItem>
            <SelectItem value="admin">Admin</SelectItem>
            <SelectItem value="user">User</SelectItem>
          </SelectContent>
        </Select>
        <Badge variant="outline" className="text-[10px] bg-muted">{filtered.length} users</Badge>
      </div>
      <Card className="border-border/50">
        <CardContent className="p-4">
          <div className="overflow-x-auto max-h-[500px] overflow-y-auto">
            <Table>
              <TableHeader className="sticky top-0 bg-card z-10">
                <TableRow className="border-border/50 hover:bg-transparent">
                  <TableHead className="text-xs">User</TableHead>
                  <TableHead className="text-xs">Email</TableHead>
                  <TableHead className="text-xs">Role</TableHead>
                  <TableHead className="text-xs">Company</TableHead>
                  <TableHead className="text-xs">Tenants</TableHead>
                  <TableHead className="text-xs">Joined</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filtered.map((user) => (
                  <TableRow key={user.id} className="border-border/30">
                    <TableCell className="text-xs font-medium py-2">{user.name}</TableCell>
                    <TableCell className="text-xs text-muted-foreground py-2">{user.email}</TableCell>
                    <TableCell className="py-2">
                      <Select value={user.role} onValueChange={(v) => handleRoleChange(user.id, v)}>
                        <SelectTrigger className={`h-7 w-[120px] text-[10px] border-border/50 ${roleBadge[user.role]}`}>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="user">User</SelectItem>
                          <SelectItem value="admin">Admin</SelectItem>
                          <SelectItem value="super_admin">Super Admin</SelectItem>
                        </SelectContent>
                      </Select>
                    </TableCell>
                    <TableCell className="text-xs py-2">{user.company}</TableCell>
                    <TableCell className="text-xs text-muted-foreground py-2 max-w-[200px] truncate">
                      {user.tenants.length > 1 ? `${user.tenants.length} tenants` : user.tenants[0]}
                    </TableCell>
                    <TableCell className="text-xs text-muted-foreground py-2">{new Date(user.createdAt).toLocaleDateString()}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        </CardContent>
      </Card>
    </>
  )
}

// ─── Activity Section ────────────────────────────────────────────────────────

function ActivitySection({ activities }: { activities: ActivityEvent[] }) {
  const [typeFilter, setTypeFilter] = useState('all')
  const types = [...new Set(activities.map(a => a.type))]

  const filtered = typeFilter === 'all' ? activities : activities.filter(a => a.type === typeFilter)

  const typeIcon: Record<string, any> = {
    agent: Monitor, heartbeat: Activity, alert: AlertTriangle, scan: Shield,
    command: Terminal, user: Users, report: CheckCircle, tenant: Building2, system: Server,
  }

  const typeColor: Record<string, string> = {
    agent: 'text-blue-400', heartbeat: 'text-green-400', alert: 'text-red-400', scan: 'text-primary',
    command: 'text-amber-400', user: 'text-purple-400', report: 'text-emerald-400', tenant: 'text-blue-300', system: 'text-muted-foreground',
  }

  return (
    <>
      <div className="flex items-center gap-2">
        <Select value={typeFilter} onValueChange={setTypeFilter}>
          <SelectTrigger className="w-[150px] h-8 text-xs border-border/50"><SelectValue placeholder="All Events" /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All Events</SelectItem>
            {types.map(t => <SelectItem key={t} value={t}>{t.charAt(0).toUpperCase() + t.slice(1)}</SelectItem>)}
          </SelectContent>
        </Select>
        <Badge variant="outline" className="text-[10px] bg-muted">{filtered.length} events</Badge>
      </div>
      <Card className="border-border/50">
        <CardContent className="p-4">
          <div className="space-y-0">
            {filtered.map((event) => {
              const Icon = typeIcon[event.type] || Activity
              return (
                <div key={event.id} className="flex items-start gap-3 py-3 border-b border-border/30 last:border-0">
                  <div className={`mt-0.5 w-7 h-7 rounded-full bg-muted/50 flex items-center justify-center shrink-0 ${typeColor[event.type] ?? ''}`}>
                    <Icon className="h-3.5 w-3.5" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-xs">{event.message}</p>
                    <div className="flex items-center gap-2 mt-0.5">
                      <span className="text-[10px] text-muted-foreground">{event.tenant}</span>
                      <span className="text-[10px] text-muted-foreground">•</span>
                      <span className="text-[10px] text-muted-foreground">{event.timestamp}</span>
                    </div>
                  </div>
                </div>
              )
            })}
          </div>
        </CardContent>
      </Card>
    </>
  )
}

// ─── Loading Skeleton ────────────────────────────────────────────────────────

function LoadingSkeleton() {
  return (
    <div className="space-y-6 animate-pulse">
      <div className="h-8 w-64 bg-muted rounded" />
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        {Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="h-20 bg-muted rounded-lg" />
        ))}
      </div>
      <div className="h-10 w-96 bg-muted rounded" />
      <div className="h-[400px] bg-muted rounded-lg" />
    </div>
  )
}
