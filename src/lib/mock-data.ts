export interface MockAlert {
  id: string
  title: string
  severity: 'critical' | 'high' | 'medium' | 'low'
  source: string
  description: string
  category: string
  createdAt: string
}

export const mockAlerts: MockAlert[] = [
  {
    id: 'a1',
    title: 'CVE-2025-2177: Apache Log4j Remote Code Execution',
    severity: 'critical',
    source: 'NVD',
    description: 'A critical remote code execution vulnerability has been discovered in Apache Log4j 2.x. Attackers can exploit this vulnerability by sending crafted log messages that trigger JNDI lookups, leading to arbitrary code execution. All versions from 2.0-beta9 to 2.24.1 are affected. Immediate patching to 2.24.2 is strongly recommended.',
    category: 'Vulnerability',
    createdAt: '2025-01-15T08:30:00Z',
  },
  {
    id: 'a2',
    title: 'Active Phishing Campaign Targeting Financial Institutions',
    severity: 'high',
    source: 'CISA',
    description: 'A sophisticated phishing campaign is actively targeting employees at major financial institutions. The campaign uses personalized spear-phishing emails mimicking internal HR communications, with malicious Office documents that deploy a known Cobalt Strike beacon.',
    category: 'Phishing',
    createdAt: '2025-01-15T09:15:00Z',
  },
  {
    id: 'a3',
    title: 'Zero-Day Exploit in Microsoft Exchange Server',
    severity: 'critical',
    source: 'Microsoft SSIRP',
    description: 'Microsoft Security Response Center has confirmed an actively exploited zero-day vulnerability in Microsoft Exchange Server that allows remote code execution. The vulnerability, tracked as CVE-2025-26801, has been observed in targeted attacks against government agencies. Emergency patches are being developed.',
    category: 'Zero-Day',
    createdAt: '2025-01-15T10:00:00Z',
  },
  {
    id: 'a4',
    title: 'Ransomware Group "BlackStorm" Targets Healthcare Sector',
    severity: 'high',
    source: 'FBI IC3',
    description: 'The FBI has issued an advisory regarding the BlackStorm ransomware group actively targeting healthcare organizations across North America. The group exploits unpatched VPN appliances and uses double-extortion tactics. Healthcare organizations are urged to review VPN configurations and apply all security patches.',
    category: 'Ransomware',
    createdAt: '2025-01-15T11:30:00Z',
  },
  {
    id: 'a5',
    title: 'Critical Flaw in OpenSSL Allows Certificate Forgery',
    severity: 'critical',
    source: 'OpenSSL Project',
    description: 'A critical vulnerability (CVE-2025-2931) in OpenSSL versions 3.0.0 through 3.0.14 enables attackers to forge X.509 certificates. This could allow man-in-the-middle attacks on TLS connections. Immediate upgrade to OpenSSL 3.0.15 is required.',
    category: 'Vulnerability',
    createdAt: '2025-01-15T12:00:00Z',
  },
  {
    id: 'a6',
    title: 'Supply Chain Attack on Popular NPM Package',
    severity: 'high',
    source: 'Sonatype',
    description: 'A compromised version of the popular NPM package "event-stream-utils" (v5.2.0) was published containing malicious code that steals cryptocurrency wallet credentials. The package has been unpublished but downstream consumers should audit their dependency trees.',
    category: 'Supply Chain',
    createdAt: '2025-01-15T13:45:00Z',
  },
  {
    id: 'a7',
    title: 'Docker Engine Privilege Escalation Vulnerability',
    severity: 'high',
    source: 'Snyk',
    description: 'A privilege escalation vulnerability (CVE-2025-3145) has been identified in Docker Engine versions prior to 25.0.5. Local attackers with access to the Docker socket can escalate privileges to root. Container orchestration platforms should be updated immediately.',
    category: 'Vulnerability',
    createdAt: '2025-01-15T14:20:00Z',
  },
  {
    id: 'a8',
    title: 'New APT Group "GhostPanda" Discovered Targeting Telco',
    severity: 'high',
    source: 'Mandiant',
    description: 'Mandiant researchers have identified a new advanced persistent threat group dubbed "GhostPanda" targeting telecommunications providers in Southeast Asia. The group uses custom malware and living-off-the-land techniques to maintain persistent access and exfiltrate call metadata.',
    category: 'APT',
    createdAt: '2025-01-15T15:00:00Z',
  },
  {
    id: 'a9',
    title: 'WordPress Plugin Mass Compromise Affects 3M Sites',
    severity: 'medium',
    source: 'Wordfence',
    description: 'A mass compromise of WordPress sites has been traced to a backdoor injected into the popular "WP Super Cache" plugin. Approximately 3 million sites are estimated to be affected. Site administrators should update to the latest version and scan for indicators of compromise.',
    category: 'Vulnerability',
    createdAt: '2025-01-15T15:30:00Z',
  },
  {
    id: 'a10',
    title: 'Malicious Chrome Extension Steals Banking Credentials',
    severity: 'medium',
    source: 'Cisco Talos',
    description: 'A malicious Chrome extension posing as a PDF converter has been found stealing banking credentials from over 500,000 users. The extension, "PDF Wizard Pro", uses sophisticated web injection techniques to capture credentials in real-time during banking sessions.',
    category: 'Malware',
    createdAt: '2025-01-15T16:00:00Z',
  },
  {
    id: 'a11',
    title: 'SSH Brute Force Campaign Exploiting Default Credentials',
    severity: 'medium',
    source: 'GreyNoise',
    description: 'A large-scale SSH brute force campaign has been observed targeting internet-facing servers with default credentials. The campaign originates from a botnet of over 100,000 compromised IoT devices and targets common usernames like "admin", "root", and "ubuntu".',
    category: 'Attack',
    createdAt: '2025-01-15T16:30:00Z',
  },
  {
    id: 'a12',
    title: 'Data Breach at Major Cloud Provider Exposes Customer Metadata',
    severity: 'high',
    source: 'Have I Been Pwned',
    description: 'A significant data breach at a major cloud infrastructure provider has exposed customer account metadata including email addresses, company names, and service usage patterns. While no passwords were compromised, the exposed data could be used for targeted social engineering attacks.',
    category: 'Data Breach',
    createdAt: '2025-01-15T17:00:00Z',
  },
  {
    id: 'a13',
    title: 'Critical Kubernetes RBAC Misconfiguration Detected in CI/CD',
    severity: 'medium',
    source: 'Aqua Security',
    description: 'Security researchers have found a commonly used Kubernetes RBAC configuration in popular CI/CD pipeline templates that grants excessive cluster-admin privileges to deployment service accounts. Organizations using Helm charts from affected repositories should review and restrict RBAC permissions.',
    category: 'Misconfiguration',
    createdAt: '2025-01-15T17:30:00Z',
  },
  {
    id: 'a14',
    title: 'New Variant of Emotet Malware Evades Detection',
    severity: 'medium',
    source: 'Malwarebytes',
    description: 'A new variant of the Emotet botnet malware has been detected using novel encryption and obfuscation techniques that allow it to evade detection by over 80% of antivirus solutions. The variant is distributed through malicious email attachments disguised as shipping notifications.',
    category: 'Malware',
    createdAt: '2025-01-15T18:00:00Z',
  },
  {
    id: 'a15',
    title: 'DNS Cache Poisoning Attack on Major ISP',
    severity: 'medium',
    source: 'Cloudflare',
    description: 'A DNS cache poisoning attack has been detected affecting a major ISP in Europe. The attack redirects users to malicious mirror sites for popular banking and e-commerce platforms. Users affected should verify they are connecting to legitimate sites using certificate pinning.',
    category: 'Attack',
    createdAt: '2025-01-15T18:30:00Z',
  },
  {
    id: 'a16',
    title: 'Outdated SSL/TLS Configuration Warning for SaaS Providers',
    severity: 'low',
    source: 'Qualys SSL Labs',
    description: 'Automated scanning has identified that approximately 15% of SaaS providers are still supporting TLS 1.0 or TLS 1.1, which have been deprecated since 2020. Organizations should disable support for legacy protocols and ensure TLS 1.2+ is the minimum configuration.',
    category: 'Configuration',
    createdAt: '2025-01-15T19:00:00Z',
  },
  {
    id: 'a17',
    title: 'Phishing Kit "LockPhish2" Available on Dark Web',
    severity: 'low',
    source: ' Recorded Future',
    description: 'A new phishing kit called "LockPhish2" has been spotted for sale on dark web marketplaces. The kit includes anti-detection features and can generate convincing phishing pages for over 200 popular services. Security teams should update email filters and endpoint protection.',
    category: 'Threat Intel',
    createdAt: '2025-01-15T19:30:00Z',
  },
  {
    id: 'a18',
    title: 'IoT Firmware Update Addresses Critical Botnet Vulnerability',
    severity: 'low',
    source: 'CISA KEV',
    description: 'Multiple IoT device manufacturers have released firmware updates addressing vulnerabilities exploited by the Mirai-based botnet "Mozi". Device administrators should apply available updates and isolate IoT devices on separate network segments.',
    category: 'Vulnerability',
    createdAt: '2025-01-15T20:00:00Z',
  },
]

export interface MockTask {
  id: string
  title: string
  description: string
  status: 'new' | 'in_progress' | 'review' | 'completed'
  priority: 'low' | 'medium' | 'high' | 'critical'
  assignee: string
  dueDate: string
  createdAt: string
}

export const mockTasks: MockTask[] = [
  {
    id: 't1',
    title: 'Patch Apache Log4j to 2.24.2',
    description: 'Update all production servers running Log4j to version 2.24.2 or later. Verify patch deployment across all environments.',
    status: 'in_progress',
    priority: 'critical',
    assignee: 'Sarah Chen',
    dueDate: '2025-01-16T23:59:00Z',
    createdAt: '2025-01-15T08:30:00Z',
  },
  {
    id: 't2',
    title: 'Review Exchange Server emergency patches',
    description: 'Evaluate and test Microsoft emergency patches for CVE-2025-26801 before deploying to production.',
    status: 'new',
    priority: 'critical',
    assignee: 'Mike Rodriguez',
    dueDate: '2025-01-17T23:59:00Z',
    createdAt: '2025-01-15T10:00:00Z',
  },
  {
    id: 't3',
    title: 'Conduct phishing awareness training',
    description: 'Schedule and execute organization-wide phishing simulation and training session in response to active phishing campaign.',
    status: 'in_progress',
    priority: 'high',
    assignee: 'Lisa Park',
    dueDate: '2025-01-20T23:59:00Z',
    createdAt: '2025-01-15T09:15:00Z',
  },
  {
    id: 't4',
    title: 'Audit NPM dependencies for compromised packages',
    description: 'Run full dependency tree audit on all Node.js projects to identify any usage of compromised event-stream-utils package.',
    status: 'review',
    priority: 'high',
    assignee: 'James Wilson',
    dueDate: '2025-01-16T23:59:00Z',
    createdAt: '2025-01-15T13:45:00Z',
  },
  {
    id: 't5',
    title: 'Update Docker Engine on all hosts',
    description: 'Upgrade Docker Engine to version 25.0.5+ across all container hosts to address CVE-2025-3145 privilege escalation.',
    status: 'new',
    priority: 'high',
    assignee: 'David Kim',
    dueDate: '2025-01-18T23:59:00Z',
    createdAt: '2025-01-15T14:20:00Z',
  },
  {
    id: 't6',
    title: 'Review and restrict Kubernetes RBAC permissions',
    description: 'Audit all Kubernetes RBAC configurations in CI/CD pipelines and restrict cluster-admin privileges.',
    status: 'new',
    priority: 'medium',
    assignee: 'Sarah Chen',
    dueDate: '2025-01-22T23:59:00Z',
    createdAt: '2025-01-15T17:30:00Z',
  },
  {
    id: 't7',
    title: 'Update endpoint detection signatures',
    description: 'Deploy updated malware detection signatures for Emotet variant and test detection rates against known samples.',
    status: 'completed',
    priority: 'medium',
    assignee: 'Mike Rodriguez',
    dueDate: '2025-01-15T23:59:00Z',
    createdAt: '2025-01-14T10:00:00Z',
  },
  {
    id: 't8',
    title: 'Network segmentation for IoT devices',
    description: 'Isolate all IoT devices on dedicated VLANs with restricted internet access and monitoring.',
    status: 'in_progress',
    priority: 'medium',
    assignee: 'James Wilson',
    dueDate: '2025-01-25T23:59:00Z',
    createdAt: '2025-01-14T14:00:00Z',
  },
  {
    id: 't9',
    title: 'Incident response plan update',
    description: 'Update the incident response plan to include procedures for ransomware attacks from the BlackStorm group.',
    status: 'completed',
    priority: 'high',
    assignee: 'Lisa Park',
    dueDate: '2025-01-14T23:59:00Z',
    createdAt: '2025-01-13T09:00:00Z',
  },
  {
    id: 't10',
    title: 'SSL/TLS configuration audit',
    description: 'Audit all public-facing services for deprecated TLS protocol support and generate remediation report.',
    status: 'new',
    priority: 'low',
    assignee: 'David Kim',
    dueDate: '2025-01-30T23:59:00Z',
    createdAt: '2025-01-15T19:00:00Z',
  },
]

export const mockBrief = {
  title: 'Cyber Brief Unified Platform',
  volume: 847,
  date: 'January 15, 2025',
  threatLevel: 'ELEVATED' as const,
  threatScore: 78,
  sections: [
    {
      title: 'Top Threats Today',
      icon: 'alert-triangle',
      items: [
        {
          title: 'Apache Log4j RCE (CVE-2025-2177)',
          summary: 'Critical 10.0 CVSS vulnerability in Apache Log4j enables unauthenticated remote code execution. Active exploitation observed in the wild targeting enterprise Java applications. All organizations running affected versions should patch immediately.',
          severity: 'critical',
        },
        {
          title: 'Microsoft Exchange Zero-Day (CVE-2025-26801)',
          summary: 'Actively exploited zero-day in Exchange Server allowing remote code execution. Targeted attacks against government agencies confirmed. Emergency patches expected within 24 hours. Consider implementing proxy-based mitigation.',
          severity: 'critical',
        },
        {
          title: 'BlackStorm Ransomware Healthcare Campaign',
          summary: 'Coordinated ransomware campaign targeting healthcare organizations in North America. Attackers exploit unpatched VPN appliances for initial access. Healthcare sector urged to activate incident response plans.',
          severity: 'high',
        },
      ],
    },
    {
      title: 'Vulnerability Watch',
      icon: 'shield-alert',
      items: [
        {
          title: 'OpenSSL Certificate Forgery (CVE-2025-2931)',
          summary: 'Critical vulnerability in OpenSSL 3.0.x allows forging of X.509 certificates. Enables man-in-the-middle attacks on TLS connections. Immediate upgrade to 3.0.15 is required for all affected systems.',
          severity: 'critical',
        },
        {
          title: 'Docker Engine Privilege Escalation (CVE-2025-3145)',
          summary: 'Local privilege escalation via Docker socket access in versions before 25.0.5. Container orchestration environments should restrict socket access and update immediately.',
          severity: 'high',
        },
        {
          title: 'WordPress WP Super Cache Compromise',
          summary: 'Backdoor injected into popular WordPress plugin affecting approximately 3 million sites. Update to latest version immediately and scan for indicators of compromise.',
          severity: 'medium',
        },
        {
          title: 'IoT Botnet Firmware Vulnerabilities',
          summary: 'Multiple IoT vendors release patches for Mozi botnet vulnerabilities. Device administrators should apply updates and implement network segmentation.',
          severity: 'low',
        },
      ],
    },
    {
      title: 'Industry Alerts',
      icon: 'building-2',
      items: [
        {
          title: 'Financial Sector: Active Spear-Phishing Campaign',
          summary: 'CISA warns of ongoing phishing campaign targeting financial institutions using HR-themed lures. Malicious documents deliver Cobalt Strike beacons. Enhanced email filtering and user awareness recommended.',
          severity: 'high',
        },
        {
          title: 'Telecommunications: New APT Group "GhostPanda"',
          summary: 'Mandiant identifies new threat group targeting telecom providers in Southeast Asia. Custom malware and living-off-the-land techniques detected. Telecom operators in the region should enhance monitoring.',
          severity: 'high',
        },
        {
          title: 'Healthcare: BlackStorm Ransomware Advisory',
          summary: 'FBI IC3 issues advisory for BlackStorm ransomware targeting healthcare. Double-extortion tactics employed. Organizations should verify backup integrity and test restoration procedures.',
          severity: 'high',
        },
      ],
    },
    {
      title: 'Recommended Actions',
      icon: 'check-circle',
      items: [
        {
          title: 'Immediately patch Apache Log4j to 2.24.2',
          summary: 'This critical vulnerability is being actively exploited. Prioritize internet-facing applications and those processing untrusted input.',
          severity: 'critical',
        },
        {
          title: 'Upgrade OpenSSL to 3.0.15 across all systems',
          summary: 'Certificate forgery risk poses significant trust and security implications. Automated certificate monitoring should be enabled post-patch.',
          severity: 'critical',
        },
        {
          title: 'Conduct emergency Exchange Server hardening',
          summary: 'While patches are developed, implement URL rewrite rules and restrict Outlook Web Access as temporary mitigation for CVE-2025-26801.',
          severity: 'high',
        },
        {
          title: 'Audit VPN and remote access configurations',
          summary: 'Multiple threat groups are exploiting VPN vulnerabilities. Verify all VPN appliances are updated and multi-factor authentication is enforced.',
          severity: 'high',
        },
      ],
    },
    {
      title: 'Threat Intelligence Summary',
      icon: 'radar',
      items: [
        {
          title: 'Global Threat Landscape Overview',
          summary: 'The global threat landscape remains elevated with a 23% increase in ransomware incidents over the past 30 days. Nation-state actors continue to target critical infrastructure, while cybercriminal groups are leveraging AI-enhanced phishing techniques. Supply chain attacks remain a significant concern with three major incidents reported this week.',
          severity: 'medium',
        },
        {
          title: 'Emerging Trends: AI-Powered Attacks',
          summary: 'Security researchers report a significant uptick in AI-generated phishing emails, deepfake voice attacks targeting C-suite executives, and automated vulnerability scanning tools used by threat actors. Organizations should consider AI-based defenses and enhanced verification procedures.',
          severity: 'medium',
        },
        {
          title: 'Geopolitical Cyber Activity',
          summary: 'Increased cyber activity observed from Eastern European and East Asian state-sponsored groups. Focus areas include telecommunications, energy sector, and government agencies. Organizations in these sectors should maintain heightened awareness.',
          severity: 'medium',
        },
      ],
    },
  ],
}

export const dashboardStats = {
  activeAlerts: 18,
  criticalAlerts: 3,
  openTasks: 7,
  completedTasks: 2,
  complianceScore: 82,
  threatLevel: 'ELEVATED',
  threatScore: 78,
  recentAlerts: mockAlerts.slice(0, 5),
}

export const threatTrendData = [
  { date: 'Jan 9', score: 45, alerts: 8 },
  { date: 'Jan 10', score: 52, alerts: 12 },
  { date: 'Jan 11', score: 48, alerts: 9 },
  { date: 'Jan 12', score: 61, alerts: 15 },
  { date: 'Jan 13', score: 55, alerts: 11 },
  { date: 'Jan 14', score: 67, alerts: 16 },
  { date: 'Jan 15', score: 78, alerts: 18 },
]

export const alertDistributionData = [
  { category: 'Vulnerability', count: 6 },
  { category: 'Malware', count: 2 },
  { category: 'Phishing', count: 2 },
  { category: 'Ransomware', count: 1 },
  { category: 'APT', count: 1 },
  { category: 'Supply Chain', count: 1 },
  { category: 'Attack', count: 2 },
  { category: 'Data Breach', count: 1 },
  { category: 'Misconfiguration', count: 1 },
  { category: 'Other', count: 1 },
]

export const severityBreakdownData = [
  { name: 'Critical', value: 3, color: '#ef4444' },
  { name: 'High', value: 6, color: '#f97316' },
  { name: 'Medium', value: 7, color: '#eab308' },
  { name: 'Low', value: 2, color: '#22c55e' },
]

export const activityLogData = [
  { time: '20:00', action: 'IoT firmware update advisory published', type: 'info' },
  { time: '19:30', action: 'New phishing kit detected on dark web', type: 'warning' },
  { time: '19:00', action: 'SSL/TLS configuration scan completed', type: 'info' },
  { time: '18:30', action: 'DNS cache poisoning attack detected', type: 'critical' },
  { time: '18:00', action: 'Emotet variant analysis completed', type: 'info' },
  { time: '17:30', action: 'Kubernetes RBAC misconfiguration alert', type: 'warning' },
  { time: '17:00', action: 'Cloud provider data breach confirmed', type: 'critical' },
  { time: '16:30', action: 'SSH brute force campaign detected', type: 'warning' },
  { time: '16:00', action: 'Malicious Chrome extension reported', type: 'high' },
  { time: '15:30', action: 'WordPress plugin compromise identified', type: 'high' },
]
