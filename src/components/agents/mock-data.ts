import type { Agent, TelemetryPoint, EDRScan, AgentCommand } from './types'

// ─── Mock Data ───────────────────────────────────────────────────────────────

export function generateMockAgents(): Agent[] {
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

export function generateTelemetry(hours: number): TelemetryPoint[] {
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

export function generateScans(): EDRScan[] {
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

export function generateCommands(): AgentCommand[] {
  return [
    { id: 'cmd-001', type: 'Run EDR Scan', payload: 'full', status: 'completed', createdAt: new Date(Date.now() - 7200000), completedAt: new Date(Date.now() - 3600000), result: 'Scan complete. 2 findings.' },
    { id: 'cmd-002', type: 'Run Custom Script', payload: 'Get-Process | Sort-Object CPU -Descending | Select-Object -First 10', status: 'completed', createdAt: new Date(Date.now() - 5400000), completedAt: new Date(Date.now() - 5395000), result: 'chrome.exe: 34.2% CPU, msedge.exe: 12.1%, ...' },
    { id: 'cmd-003', type: 'Ping Agent', payload: '', status: 'completed', createdAt: new Date(Date.now() - 120000), completedAt: new Date(Date.now() - 119000), result: 'Pong - latency 14ms' },
    { id: 'cmd-004', type: 'Block IP', payload: '192.168.1.100', status: 'running', createdAt: new Date(Date.now() - 60000), completedAt: null, result: '' },
    { id: 'cmd-005', type: 'Kill Process', payload: 'PID 4821', status: 'failed', createdAt: new Date(Date.now() - 300000), completedAt: new Date(Date.now() - 299000), result: 'Access denied. Process is protected.' },
  ]
}
