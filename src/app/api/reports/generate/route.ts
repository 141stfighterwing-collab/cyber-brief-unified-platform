import { NextResponse } from 'next/server'
import { db } from '@/lib/db'
import wsHub from '@/lib/websocket'

// Report type metadata
const REPORT_TYPES: Record<string, { label: string; description: string }> = {
  vulnerability: {
    label: 'Vulnerability Assessment',
    description: 'Comprehensive vulnerability scan report across all endpoints.',
  },
  compliance: {
    label: 'Compliance Audit',
    description: 'Regulatory compliance status and findings.',
  },
  edr_summary: {
    label: 'EDR Summary',
    description: 'Endpoint detection and response summary across all agents.',
  },
  endpoint_health: {
    label: 'Endpoint Health',
    description: 'Health status and performance metrics for all endpoints.',
  },
  full_audit: {
    label: 'Full Security Audit',
    description: 'Complete security audit covering all aspects of the platform.',
  },
}

// Mock report data generator
function generateMockReportData(
  type: string,
  tenantId?: string | null,
  agentIds?: string[]
): Record<string, unknown> {
  const now = new Date().toISOString()
  const base = {
    generatedAt: now,
    reportType: type,
    period: {
      start: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
      end: now,
    },
  }

  switch (type) {
    case 'vulnerability':
      return {
        ...base,
        executiveSummary: `Found 23 vulnerabilities across ${agentIds?.length || 5} endpoints. 4 are critical, 8 are high severity.`,
        sections: [
          {
            title: 'Critical Vulnerabilities',
            findings: [
              { id: 'CVE-2024-1234', title: 'Remote Code Execution in Agent Service', severity: 'critical', affectedEndpoints: 2, recommendation: 'Update agent to latest version immediately.' },
              { id: 'CVE-2024-5678', title: 'Privilege Escalation via Misconfigured Service', severity: 'critical', affectedEndpoints: 1, recommendation: 'Restrict service permissions and apply security patches.' },
            ],
          },
          {
            title: 'High Severity Vulnerabilities',
            findings: [
              { id: 'CVE-2024-9012', title: 'SQL Injection in Dashboard API', severity: 'high', affectedEndpoints: 3, recommendation: 'Implement parameterized queries and input validation.' },
            ],
          },
        ],
        riskScore: 78,
        complianceScore: 82,
      }

    case 'compliance':
      return {
        ...base,
        executiveSummary: 'Overall compliance score is 76%. Key gaps identified in access control and logging policies.',
        sections: [
          {
            title: 'Access Control (NIST AC)',
            score: 68,
            findings: [
              { requirement: 'AC-2: Account Management', status: 'partial', details: 'Some accounts lack proper MFA enforcement.' },
              { requirement: 'AC-6: Least Privilege', status: 'fail', details: '3 service accounts have excessive permissions.' },
            ],
          },
          {
            title: 'Audit and Accountability (NIST AU)',
            score: 84,
            findings: [
              { requirement: 'AU-2: Audit Events', status: 'pass', details: 'All critical events are properly logged.' },
              { requirement: 'AU-6: Audit Review', status: 'partial', details: 'Log review intervals exceed recommended frequency.' },
            ],
          },
        ],
        overallScore: 76,
        frameworks: ['NIST 800-53', 'CIS Controls v8'],
      }

    case 'edr_summary':
      return {
        ...base,
        executiveSummary: `EDR analysis across ${agentIds?.length || 5} agents. 156 total detections, 12 high-risk items identified.`,
        sections: [
          {
            title: 'Detection Summary',
            totalDetections: 156,
            bySeverity: { critical: 2, high: 10, medium: 44, low: 100 },
            byCategory: { malware: 12, suspicious_process: 34, network_anomaly: 28, policy_violation: 82 },
          },
          {
            title: 'Top Threats',
            findings: [
              { threat: 'Suspicious PowerShell Execution', count: 8, endpoints: 3, severity: 'high' },
              { threat: 'Unauthorized Network Connection', count: 5, endpoints: 2, severity: 'medium' },
              { threat: 'Potential Keylogger Activity', count: 2, endpoints: 1, severity: 'critical' },
            ],
          },
        ],
        agentCoverage: 95,
        avgResponseTime: '1.2s',
      }

    case 'endpoint_health':
      return {
        ...base,
        executiveSummary: `${agentIds?.length || 5} endpoints monitored. 4 healthy, 1 needs attention.`,
        sections: [
          {
            title: 'Health Overview',
            healthy: 4,
            warning: 1,
            critical: 0,
            offline: 0,
          },
          {
            title: 'Performance Metrics',
            avgCpu: 34,
            avgMemory: 62,
            avgDiskUsage: 58,
            avgUptime: '14d 6h',
          },
        ],
        endpoints: [
          { hostname: 'WS-PROD-001', status: 'healthy', cpu: 28, memory: 55, disk: 45 },
          { hostname: 'WS-PROD-002', status: 'healthy', cpu: 42, memory: 68, disk: 62 },
          { hostname: 'SRV-DB-001', status: 'warning', cpu: 78, memory: 89, disk: 72 },
          { hostname: 'WS-DEV-001', status: 'healthy', cpu: 15, memory: 42, disk: 35 },
          { hostname: 'SRV-WEB-001', status: 'healthy', cpu: 38, memory: 58, disk: 51 },
        ],
      }

    case 'full_audit':
      return {
        ...base,
        executiveSummary: 'Comprehensive security audit completed. Platform security posture is GOOD with some areas requiring improvement.',
        sections: [
          { title: 'Endpoint Security', score: 85, status: 'good' },
          { title: 'Network Security', score: 72, status: 'needs_improvement' },
          { title: 'Access Control', score: 68, status: 'needs_improvement' },
          { title: 'Data Protection', score: 90, status: 'excellent' },
          { title: 'Incident Response', score: 78, status: 'good' },
          { title: 'Compliance', score: 76, status: 'good' },
        ],
        overallScore: 78,
        totalFindings: 34,
        criticalFindings: 2,
        highFindings: 6,
        mediumFindings: 12,
        lowFindings: 14,
      }

    default:
      return {
        ...base,
        executiveSummary: 'Report generated successfully.',
        sections: [],
      }
  }
}

// POST /api/reports/generate — Generate a security report
export async function POST(request: Request) {
  try {
    const body = await request.json()
    const { type, tenantId, agentIds, title } = body

    // Validate report type
    const validTypes = Object.keys(REPORT_TYPES)
    const reportType = type || 'full_audit'
    if (!validTypes.includes(reportType)) {
      return NextResponse.json(
        { success: false, error: `Invalid report type. Must be one of: ${validTypes.join(', ')}` },
        { status: 400 }
      )
    }

    // Verify tenant exists if specified
    if (tenantId) {
      const tenant = await db.tenant.findUnique({ where: { id: tenantId } })
      if (!tenant) {
        return NextResponse.json(
          { success: false, error: 'Tenant not found.' },
          { status: 404 }
        )
      }
    }

    // Create report with "generating" status
    const report = await db.securityReport.create({
      data: {
        title: title || `${REPORT_TYPES[reportType].label} — ${new Date().toLocaleDateString()}`,
        type: reportType,
        tenantId: tenantId || null,
        agentIds: agentIds ? JSON.stringify(agentIds) : null,
        status: 'generating',
      },
    })

    // Generate report data asynchronously (mock — 2-second delay)
    generateReportAsync(report.id, reportType, tenantId, agentIds)

    return NextResponse.json(
      {
        success: true,
        data: report,
        message: 'Report generation started. Poll /api/reports/[id] for status.',
      },
      { status: 201 }
    )
  } catch (error) {
    console.error('Generate report error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}

async function generateReportAsync(
  reportId: string,
  type: string,
  tenantId?: string | null,
  agentIds?: string[]
) {
  try {
    await new Promise((resolve) => setTimeout(resolve, 2000))

    const reportData = generateMockReportData(type, tenantId, agentIds)
    const summary = (reportData.executiveSummary as string) || 'Report generated successfully.'

    await db.securityReport.update({
      where: { id: reportId },
      data: {
        status: 'completed',
        data: JSON.stringify(reportData),
        summary,
        completedAt: new Date(),
      },
    })

    wsHub.broadcastReportGenerated({
      reportId,
      tenantId: tenantId || undefined,
      title: `${REPORT_TYPES[type]?.label || type} Report`,
      type,
      status: 'completed',
    })

    console.log(`[Reports] Report ${reportId} (${type}) generated successfully.`)
  } catch (error) {
    console.error(`[Reports] Error generating report ${reportId}:`, error)
    try {
      await db.securityReport.update({
        where: { id: reportId },
        data: {
          status: 'failed',
          summary: 'Report generation failed due to an internal error.',
          completedAt: new Date(),
        },
      })
    } catch (updateError) {
      console.error(`[Reports] Error updating failed report ${reportId}:`, updateError)
    }
  }
}
