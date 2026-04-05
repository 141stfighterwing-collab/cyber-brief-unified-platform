import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { checkAuth } from '@/lib/auth-check'

// GET /api/admin/stats — Platform-wide statistics
// SECURITY: Requires admin authentication
export async function GET(request: NextRequest) {
  // ─── Auth Check ────────────────────────────────────────────────────────
  const authFail = checkAuth(request)
  if (authFail) return authFail

  try {
    const now = new Date()

    // Run all counts in parallel
    const [
      totalTenants,
      totalUsers,
      totalAgents,
      totalAlerts,
      totalReports,
      onlineAgents,
      offlineAgents,
      warningAgents,
      criticalAgents,
      resolvedAlerts,
      recentAlerts,
      recentCommands,
      activeTenants,
      recentReports,
    ] = await Promise.all([
      db.tenant.count({ where: { active: true } }),
      db.user.count(),
      db.agent.count(),
      db.alert.count(),
      db.securityReport.count(),
      db.agent.count({ where: { status: 'online' } }),
      db.agent.count({ where: { status: 'offline' } }),
      db.agent.count({ where: { status: 'warning' } }),
      db.agent.count({ where: { status: 'critical' } }),
      db.alert.count({ where: { resolved: true } }),
      // Recent activity — last 24 hours
      db.alert.count({
        where: { createdAt: { gte: new Date(now.getTime() - 24 * 60 * 60 * 1000) } },
      }),
      db.command.count({
        where: { createdAt: { gte: new Date(now.getTime() - 24 * 60 * 60 * 1000) } },
      }),
      db.tenant.count({ where: { active: true } }),
      db.securityReport.count({
        where: { createdAt: { gte: new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000) } },
      }),
    ])

    // Get recent alerts for activity summary
    const latestAlerts = await db.alert.findMany({
      take: 5,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        title: true,
        severity: true,
        source: true,
        createdAt: true,
        resolved: true,
      },
    })

    // Get severity distribution
    const severityCounts = await db.alert.groupBy({
      by: ['severity'],
      _count: { id: true },
    })

    // Get alert category distribution
    const categoryCounts = await db.alert.groupBy({
      by: ['category'],
      _count: { id: true },
    })

    return NextResponse.json({
      success: true,
      data: {
        overview: {
          totalTenants,
          activeTenants,
          totalUsers,
          totalAgents,
          totalAlerts,
          totalReports,
        },
        agents: {
          online: onlineAgents,
          offline: offlineAgents,
          warning: warningAgents,
          critical: criticalAgents,
          total: totalAgents,
        },
        alerts: {
          total: totalAlerts,
          resolved: resolvedAlerts,
          unresolved: totalAlerts - resolvedAlerts,
          resolutionRate: totalAlerts > 0 ? Math.round((resolvedAlerts / totalAlerts) * 100) : 0,
          last24h: recentAlerts,
          severityBreakdown: severityCounts.map((s) => ({
            severity: s.severity,
            count: s._count.id,
          })),
          categoryBreakdown: categoryCounts.map((c) => ({
            category: c.category,
            count: c._count.id,
          })),
        },
        recentActivity: {
          commandsLast24h: recentCommands,
          reportsLast7d: recentReports,
          latestAlerts,
        },
        storage: {
          estimatedRecords:
            totalTenants + totalUsers + totalAgents + totalAlerts + totalReports,
        },
        timestamp: now.toISOString(),
      },
    })
  } catch (error) {
    console.error('Admin stats error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}
