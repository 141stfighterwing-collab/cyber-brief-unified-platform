'use client'

import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Progress } from '@/components/ui/progress'
import { Monitor, Cpu, HardDrive, Wifi, Shield, Terminal, Clock } from 'lucide-react'
import type { Agent } from './types'
import { statusDotColors, relativeTime } from './helpers'

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

export { AgentCard }
export type { AgentCardProps }
