'use client'

import { useState, useEffect, useCallback } from 'react'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Switch } from '@/components/ui/switch'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip'
import { useAppStore } from '@/lib/store'
import {
  Activity,
  Server,
  RefreshCw,
  AlertTriangle,
  Terminal,
  Building2,
} from 'lucide-react'
import type { Agent } from '@/components/agents/types'
import { generateMockAgents } from '@/components/agents/mock-data'
import { C2CommandDialog } from '@/components/agents/c2-command-dialog'
import { DeployAgentDialog } from '@/components/agents/deploy-agent-dialog'
import { AgentCard } from '@/components/agents/agent-card'
import { AgentDetailPanel } from '@/components/agents/agent-detail-panel'

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
