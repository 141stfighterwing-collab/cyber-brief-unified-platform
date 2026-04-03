'use client'

import { useState } from 'react'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Terminal, AlertTriangle, RefreshCw, Play } from 'lucide-react'
import type { Agent } from './types'

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

export { C2CommandDialog }
