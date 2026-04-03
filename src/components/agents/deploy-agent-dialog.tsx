'use client'

import { useState } from 'react'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { useAppStore } from '@/lib/store'
import {
  Monitor,
  Terminal,
  Command,
  Network,
  Server,
  Download,
  Info,
  Building2,
  ShieldCheck,
} from 'lucide-react'
import { CopyButton } from './copy-button'

// ─── Deploy Agent Dialog ────────────────────────────────────────────────────

function DeployAgentDialog() {
  const [open, setOpen] = useState(false)
  const [platform, setPlatform] = useState<'exe' | 'ps1' | 'linux' | 'docker'>('exe')
  const { currentTenantId, user } = useAppStore()

  const serverUrl = typeof window !== 'undefined' ? window.location.origin : ''
  const tenantToken = currentTenantId || 'TENANT_TOKEN'
  const companyName = user?.company || 'Your Organization'

  // Build download URLs with tenant token and company signature
  const companyParams = currentTenantId
    ? `&companyId=${encodeURIComponent(currentTenantId)}&companyName=${encodeURIComponent(companyName)}`
    : ''
  const downloadUrls = {
    exe: `${serverUrl}/api/agents/install-script?platform=windows-exe&token=${tenantToken}${companyParams}`,
    ps1: `${serverUrl}/api/agents/install-script?platform=windows&token=${tenantToken}${companyParams}`,
    linux: `${serverUrl}/api/agents/install-script?platform=linux&token=${tenantToken}${companyParams}`,
    docker: `${serverUrl}/api/agents/install-script?platform=docker&token=${tenantToken}${companyParams}`,
  }

  // One-liner install commands per platform
  const oneLiners = {
    exe: `Invoke-WebRequest -Uri '${downloadUrls.exe}' -OutFile 'build-exe.ps1'; .\\build-exe.ps1; .\\dist\\CBUP-Agent.exe -ServerUrl '${serverUrl}' -Token ${tenantToken} -Install`,
    ps1: `Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-WebRequest -Uri '${downloadUrls.ps1}' -OutFile 'CBUP-Agent.ps1'; .\\CBUP-Agent.ps1 -ServerUrl '${serverUrl}' -Token ${tenantToken} -Install`,
    linux: `curl -fsSL '${downloadUrls.linux}' | sudo bash`,
    docker: `docker run -d --name cbup-agent --restart unless-stopped -e CBUP_SERVER_URL='${serverUrl}' -e CBUP_AUTH_TOKEN='${tenantToken}' cbup/agent:latest`,
  }

  // Platform-specific prerequisites
  const prerequisites = {
    exe: [
      'Windows 10/11 or Windows Server 2016+',
      'PowerShell 5.1+ with ps2exe module',
      'Administrator privileges',
      '.NET Framework 4.5+',
    ],
    ps1: [
      'Windows 10/11 or Windows Server 2016+',
      'PowerShell 5.1+',
      'Administrator privileges',
      '.NET Framework 4.5+',
    ],
    linux: [
      'Ubuntu 18.04+, Debian 10+, RHEL 8+, or compatible',
      'Bash 4.0+',
      'Root/sudo privileges',
      'curl or wget',
    ],
    docker: [
      'Docker 20.10+',
      'Docker Compose v2+ (optional, for compose mode)',
      'Host access for process/network monitoring',
    ],
  }

  const activePrereqs = prerequisites[platform]
  const activeDownloadUrl = downloadUrls[platform]

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="bg-primary hover:bg-primary/90 text-primary-foreground">
          <Download className="h-4 w-4 mr-1.5" />
          Deploy New Agent
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-3xl border-border/50 bg-card max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Server className="h-4 w-4 text-primary" />
            Deploy New Agent
          </DialogTitle>
          <DialogDescription>
            Install the CBUP endpoint monitoring agent for{' '}
            <span className="text-primary font-medium">{companyName}</span>.
            Scripts are pre-configured with your tenant registration token.
          </DialogDescription>
        </DialogHeader>

        {/* Tenant Info + Company Signature */}
        {currentTenantId && (
          <div className="rounded-lg border border-primary/20 bg-primary/5 p-3 space-y-2">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Building2 className="h-4 w-4 text-primary shrink-0" />
                <div className="text-xs text-primary/80">
                  <span className="font-medium text-primary">Tenant:</span>{' '}
                  {currentTenantId.slice(0, 8)}...{currentTenantId.slice(-4)}
                  {' · '}
                  <span className="font-medium text-primary">Company:</span> {companyName}
                </div>
              </div>
            </div>
            {/* Company signature badge */}
            <div className="flex items-center gap-2 ml-6">
              <ShieldCheck className="h-3.5 w-3.5 text-green-400 shrink-0" />
              <span className="text-[11px] text-green-400/90 font-medium">
                Signed for: {companyName}
              </span>
              <Badge variant="outline" className="bg-green-500/10 text-green-500 border-green-500/20 text-[10px] ml-1">CBUP SIGNED</Badge>
            </div>
          </div>
        )}

        <div className="space-y-4 py-1">
          {/* Platform Tabs */}
          <Tabs value={platform} onValueChange={(v) => setPlatform(v as typeof platform)} className="space-y-4">
            <TabsList className="bg-muted/50">
              <TabsTrigger value="exe" className="text-xs">
                <Monitor className="h-3.5 w-3.5 mr-1" />
                Windows EXE
              </TabsTrigger>
              <TabsTrigger value="ps1" className="text-xs">
                <Terminal className="h-3.5 w-3.5 mr-1" />
                Windows PowerShell
              </TabsTrigger>
              <TabsTrigger value="linux" className="text-xs">
                <Command className="h-3.5 w-3.5 mr-1" />
                Linux
              </TabsTrigger>
              <TabsTrigger value="docker" className="text-xs">
                <Network className="h-3.5 w-3.5 mr-1" />
                Docker
              </TabsTrigger>
            </TabsList>

            {/* ─── Windows EXE Tab ──────────────────────────────────── */}
            <TabsContent value="exe" className="space-y-4">
              {/* Download Button */}
              <div className="flex items-center gap-3">
                <Badge variant="outline" className="bg-green-500/10 text-green-500 border-green-500/20 text-[10px]">RECOMMENDED</Badge>
                <span className="text-sm font-semibold">Build from Source (EXE)</span>
              </div>
              <p className="text-xs text-muted-foreground">
                Download the build script which compiles CBUP-Agent.ps1 into a standalone .exe using ps2exe.
                The compiled EXE runs as a Windows service with no PowerShell dependency at runtime.
              </p>

              {/* One-Liner */}
              <div className="space-y-2">
                <label className="text-sm font-semibold">One-Liner Build & Install</label>
                <div className="relative">
                  <pre className="rounded-lg bg-background border border-border/50 p-3 text-xs font-mono overflow-x-auto pr-10 whitespace-pre-wrap break-all">
                    {oneLiners.exe}
                  </pre>
                  <div className="absolute top-2 right-2">
                    <CopyButton text={oneLiners.exe} />
                  </div>
                </div>
              </div>

              {/* Manual Steps */}
              <div className="space-y-2">
                <label className="text-sm font-semibold">Manual Steps</label>
                <div className="relative">
                  <pre className="rounded-lg bg-background border border-border/50 p-3 text-xs font-mono overflow-x-auto pr-10 whitespace-pre-wrap">{`# 1. Download build script
Invoke-WebRequest -Uri '${downloadUrls.exe}' -OutFile 'build-exe.ps1'

# 2. Build the EXE
.\\build-exe.ps1

# 3. Install as service
.\\dist\\CBUP-Agent.exe -ServerUrl '${serverUrl}' -Token ${tenantToken} -Install`}</pre>
                  <div className="absolute top-2 right-2">
                    <CopyButton text={`Invoke-WebRequest -Uri '${downloadUrls.exe}' -OutFile 'build-exe.ps1'\n.\\build-exe.ps1\n.\\dist\\CBUP-Agent.exe -ServerUrl '${serverUrl}' -Token ${tenantToken} -Install`} />
                  </div>
                </div>
              </div>

              {/* Direct Download */}
              <div className="flex items-center gap-2">
                <a
                  href={activeDownloadUrl}
                  download
                  className="inline-flex items-center gap-1.5 rounded-md bg-primary/10 border border-primary/20 px-3 py-1.5 text-xs font-medium text-primary hover:bg-primary/20 transition-colors"
                >
                  <Download className="h-3.5 w-3.5" />
                  Download build-exe.ps1
                </a>
              </div>
            </TabsContent>

            {/* ─── Windows PowerShell Tab ───────────────────────────── */}
            <TabsContent value="ps1" className="space-y-4">
              <div className="flex items-center gap-3">
                <Badge variant="outline" className="bg-blue-500/10 text-blue-500 border-blue-500/20 text-[10px]">POWERShell</Badge>
                <span className="text-sm font-semibold">Direct Script Execution</span>
              </div>
              <p className="text-xs text-muted-foreground">
                Download the PowerShell agent script and run it directly. Requires PowerShell 5.1+ at runtime.
              </p>

              {/* One-Liner */}
              <div className="space-y-2">
                <div className="flex items-center gap-2">
                  <label className="text-sm font-semibold">One-Liner Install</label>
                </div>
                <div className="relative">
                  <pre className="rounded-lg bg-background border border-border/50 p-3 text-xs font-mono overflow-x-auto pr-10 whitespace-pre-wrap break-all">
                    {oneLiners.ps1}
                  </pre>
                  <div className="absolute top-2 right-2">
                    <CopyButton text={oneLiners.ps1} />
                  </div>
                </div>
              </div>

              {/* Manual Steps */}
              <div className="space-y-2">
                <label className="text-sm font-semibold">Manual Steps</label>
                <div className="relative">
                  <pre className="rounded-lg bg-background border border-border/50 p-3 text-xs font-mono overflow-x-auto pr-10 whitespace-pre-wrap">{`# 1. Download script
Invoke-WebRequest -Uri '${downloadUrls.ps1}' -OutFile 'CBUP-Agent.ps1'

# 2. Run interactively (DevMode)
.\\CBUP-Agent.ps1 -ServerUrl '${serverUrl}' -Token ${tenantToken} -DevMode

# 3. Install as service
.\\CBUP-Agent.ps1 -ServerUrl '${serverUrl}' -Token ${tenantToken} -Install`}</pre>
                  <div className="absolute top-2 right-2">
                    <CopyButton text={`Invoke-WebRequest -Uri '${downloadUrls.ps1}' -OutFile 'CBUP-Agent.ps1'\n.\\CBUP-Agent.ps1 -ServerUrl '${serverUrl}' -Token ${tenantToken} -Install`} />
                  </div>
                </div>
              </div>

              {/* Direct Download */}
              <div className="flex items-center gap-2">
                <a
                  href={activeDownloadUrl}
                  download
                  className="inline-flex items-center gap-1.5 rounded-md bg-primary/10 border border-primary/20 px-3 py-1.5 text-xs font-medium text-primary hover:bg-primary/20 transition-colors"
                >
                  <Download className="h-3.5 w-3.5" />
                  Download CBUP-Agent.ps1
                </a>
              </div>
            </TabsContent>

            {/* ─── Linux Tab ────────────────────────────────────────── */}
            <TabsContent value="linux" className="space-y-4">
              <div className="flex items-center gap-3">
                <Badge variant="outline" className="bg-orange-500/10 text-orange-500 border-orange-500/20 text-[10px]">LINUX</Badge>
                <span className="text-sm font-semibold">Bash Shell Script</span>
              </div>
              <p className="text-xs text-muted-foreground">
                Deploy the agent on Linux endpoints using a bash script. Supports Ubuntu, Debian, RHEL, and compatible distributions.
              </p>

              {/* One-Liner */}
              <div className="space-y-2">
                <label className="text-sm font-semibold">One-Liner Install</label>
                <div className="relative">
                  <pre className="rounded-lg bg-background border border-border/50 p-3 text-xs font-mono overflow-x-auto pr-10 whitespace-pre-wrap break-all">
                    {oneLiners.linux}
                  </pre>
                  <div className="absolute top-2 right-2">
                    <CopyButton text={oneLiners.linux} />
                  </div>
                </div>
              </div>

              {/* Manual Steps */}
              <div className="space-y-2">
                <label className="text-sm font-semibold">Manual Steps</label>
                <div className="relative">
                  <pre className="rounded-lg bg-background border border-border/50 p-3 text-xs font-mono overflow-x-auto pr-10 whitespace-pre-wrap">{`# 1. Download script
curl -fsSL '${downloadUrls.linux}' -o cbup-agent-linux.sh

# 2. Review and execute
chmod +x cbup-agent-linux.sh
sudo ./cbup-agent-linux.sh --server '${serverUrl}' --token ${tenantToken}`}</pre>
                  <div className="absolute top-2 right-2">
                    <CopyButton text={`curl -fsSL '${downloadUrls.linux}' -o cbup-agent-linux.sh\nchmod +x cbup-agent-linux.sh\nsudo ./cbup-agent-linux.sh --server '${serverUrl}' --token ${tenantToken}`} />
                  </div>
                </div>
              </div>

              {/* Direct Download */}
              <div className="flex items-center gap-2">
                <a
                  href={activeDownloadUrl}
                  download
                  className="inline-flex items-center gap-1.5 rounded-md bg-primary/10 border border-primary/20 px-3 py-1.5 text-xs font-medium text-primary hover:bg-primary/20 transition-colors"
                >
                  <Download className="h-3.5 w-3.5" />
                  Download cbup-agent-linux.sh
                </a>
              </div>
            </TabsContent>

            {/* ─── Docker Tab ───────────────────────────────────────── */}
            <TabsContent value="docker" className="space-y-4">
              <div className="flex items-center gap-3">
                <Badge variant="outline" className="bg-cyan-500/10 text-cyan-500 border-cyan-500/20 text-[10px]">CONTAINER</Badge>
                <span className="text-sm font-semibold">Docker Deployment</span>
              </div>
              <p className="text-xs text-muted-foreground">
                Run the CBUP agent as a Docker container. Ideal for containerized environments, CI/CD pipelines,
                or quick testing. Includes a docker-compose option for production deployments.
              </p>

              {/* Docker Run */}
              <div className="space-y-2">
                <label className="text-sm font-semibold">Docker Run</label>
                <div className="relative">
                  <pre className="rounded-lg bg-background border border-border/50 p-3 text-xs font-mono overflow-x-auto pr-10 whitespace-pre-wrap break-all">
                    {oneLiners.docker}
                  </pre>
                  <div className="absolute top-2 right-2">
                    <CopyButton text={oneLiners.docker} />
                  </div>
                </div>
              </div>

              {/* Docker Compose */}
              <div className="space-y-2">
                <label className="text-sm font-semibold">Docker Compose</label>
                <div className="relative">
                  <pre className="rounded-lg bg-background border border-border/50 p-3 text-xs font-mono overflow-x-auto pr-10 whitespace-pre-wrap">{`cat > docker-compose.yml << 'EOF'
version: "3.8"
services:
  cbup-agent:
    image: cbup/agent:latest
    container_name: cbup-agent
    restart: unless-stopped
    environment:
      - CBUP_SERVER_URL=${serverUrl}
      - CBUP_AUTH_TOKEN=${tenantToken}
      - CBUP_LOG_LEVEL=info
      - CBUP_INTERVAL=30
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
    security_opt:
      - no-new-privileges:true
    read_only: true
    cap_drop:
      - ALL
    cap_add:
      - NET_ADMIN
      - SYS_PTRACE
EOF

docker compose up -d`}</pre>
                  <div className="absolute top-2 right-2">
                    <CopyButton text={`cat > docker-compose.yml << 'EOF'\nversion: "3.8"\nservices:\n  cbup-agent:\n    image: cbup/agent:latest\n    container_name: cbup-agent\n    restart: unless-stopped\n    environment:\n      - CBUP_SERVER_URL=${serverUrl}\n      - CBUP_AUTH_TOKEN=${tenantToken}\n      - CBUP_LOG_LEVEL=info\n      - CBUP_INTERVAL=30\nEOF\ndocker compose up -d`} />
                  </div>
                </div>
              </div>

              {/* Direct Download */}
              <div className="flex items-center gap-2">
                <a
                  href={activeDownloadUrl}
                  download
                  className="inline-flex items-center gap-1.5 rounded-md bg-primary/10 border border-primary/20 px-3 py-1.5 text-xs font-medium text-primary hover:bg-primary/20 transition-colors"
                >
                  <Download className="h-3.5 w-3.5" />
                  Download docker setup script
                </a>
              </div>
            </TabsContent>
          </Tabs>

          {/* Prerequisites (platform-specific) */}
          <div className="rounded-lg border border-blue-500/20 bg-blue-500/5 p-3 space-y-2">
            <div className="flex items-start gap-2">
              <Info className="h-4 w-4 text-blue-400 mt-0.5 shrink-0" />
              <div className="text-xs text-blue-200/70 space-y-1">
                <p><strong className="text-blue-300">Prerequisites ({platform === 'exe' ? 'Windows EXE' : platform === 'ps1' ? 'Windows PS1' : platform === 'linux' ? 'Linux' : 'Docker'}):</strong></p>
                <ul className="list-disc list-inside space-y-0.5 pl-1">
                  {activePrereqs.map((prereq, idx) => (
                    <li key={idx}>{prereq}</li>
                  ))}
                </ul>
                <p className="mt-1"><strong className="text-blue-300">Firewall:</strong> Ensure outbound HTTPS (443) is allowed to the CBUP server</p>
                <p><strong className="text-blue-300">Anti-Virus:</strong> You may need to add an exclusion for the agent installation path</p>
              </div>
            </div>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}

export { DeployAgentDialog }
