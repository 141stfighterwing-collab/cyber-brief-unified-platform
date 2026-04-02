'use client'

import { useState, useEffect } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Progress } from '@/components/ui/progress'
import { Separator } from '@/components/ui/separator'
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
  RadarChart, Radar, PolarGrid, PolarAngleAxis, PolarRadiusAxis,
  PieChart, Pie, Cell,
  BarChart, Bar,
  XAxis, YAxis, Tooltip as RechartsTooltip,
  ResponsiveContainer,
} from 'recharts'
import {
  FileText, Plus, RefreshCw, Download, Trash2, Eye,
  Shield, AlertTriangle, CheckCircle, ChevronLeft,
  FileWarning, ClipboardCheck, BarChart3, BookOpen,
  Clock, Loader2,
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

interface ReportFinding {
  severity: string
  title: string
  description: string
  recommendation: string
}

interface ComplianceEntry {
  framework: string
  score: number
  status: string
}

interface Report {
  id: string
  title: string
  type: string
  status: string
  tenant: string
  createdAt: string
  completedAt: string | null
  summary: string
  riskScore: number | null
  findings: ReportFinding[]
  riskCategories: Record<string, number>
  affectedEndpoints: string[]
  complianceStatus: ComplianceEntry[]
}

interface ReportType {
  id: string
  label: string
  description: string
  icon: any
}

// ─── Report Types ────────────────────────────────────────────────────────────

const reportTypes: ReportType[] = [
  { id: 'endpoint_health', label: 'Endpoint Health', description: 'Overview of all endpoint statuses, resources, and anomalies', icon: Monitor },
  { id: 'edr_scan_summary', label: 'EDR Scan Summary', description: 'Aggregated findings from EDR scans across endpoints', icon: Shield },
  { id: 'vulnerability_assessment', label: 'Vulnerability Assessment', description: 'Security posture analysis and vulnerability findings', icon: FileWarning },
  { id: 'compliance_report', label: 'Compliance Report', description: 'Compliance check results against industry frameworks', icon: ClipboardCheck },
  { id: 'full_audit', label: 'Full Audit Report', description: 'Comprehensive security audit across all endpoints', icon: BookOpen },
]

const typeBadge: Record<string, string> = {
  endpoint_health: 'bg-blue-500/10 text-blue-500 border-blue-500/20',
  edr_scan_summary: 'bg-primary/10 text-primary border-primary/20',
  vulnerability_assessment: 'bg-amber-500/10 text-amber-500 border-amber-500/20',
  compliance_report: 'bg-purple-500/10 text-purple-500 border-purple-500/20',
  full_audit: 'bg-emerald-500/10 text-emerald-500 border-emerald-500/20',
}

const statusBadge: Record<string, string> = {
  generating: 'bg-blue-500/10 text-blue-500 border-blue-500/20',
  completed: 'bg-green-500/10 text-green-500 border-green-500/20',
  failed: 'bg-red-500/10 text-red-500 border-red-500/20',
}

const severityBadge: Record<string, string> = {
  critical: 'bg-red-500/10 text-red-500 border-red-500/20',
  high: 'bg-orange-500/10 text-orange-500 border-orange-500/20',
  medium: 'bg-yellow-500/10 text-yellow-500 border-yellow-500/20',
  low: 'bg-green-500/10 text-green-500 border-green-500/20',
}

// ─── Main Component ──────────────────────────────────────────────────────────

export function ReportsView() {
  const [reports, setReports] = useState<Report[]>([])
  const [loading, setLoading] = useState(true)
  const [selectedReport, setSelectedReport] = useState<Report | null>(null)
  const [typeFilter, setTypeFilter] = useState('all')

  useEffect(() => {
    fetch('/api/reports')
      .then(r => r.json())
      .then((data) => {
        if (Array.isArray(data)) setReports(data)
      })
      .catch(() => {
        setReports(getMockReports())
      })
      .finally(() => setLoading(false))
  }, [])

  const filtered = typeFilter === 'all' ? reports : reports.filter(r => r.type === typeFilter)

  if (loading) {
    return (
      <div className="space-y-6 animate-pulse">
        <div className="h-8 w-64 bg-muted rounded" />
        <div className="grid grid-cols-1 md:grid-cols-5 gap-3">
          {Array.from({ length: 5 }).map((_, i) => <div key={i} className="h-24 bg-muted rounded-lg" />)}
        </div>
        <div className="h-[400px] bg-muted rounded-lg" />
      </div>
    )
  }

  // Detail View
  if (selectedReport) {
    return <ReportDetail report={selectedReport} onBack={() => setSelectedReport(null)} />
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center">
            <FileText className="h-5 w-5 text-primary" />
          </div>
          <div>
            <h1 className="text-xl font-bold">Security Reports</h1>
            <p className="text-xs text-muted-foreground">Generate, view, and manage security reports</p>
          </div>
        </div>
        <GenerateReportDialog />
      </div>

      {/* Report Type Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3">
        {reportTypes.map((rt) => {
          const count = reports.filter(r => r.type === rt.id).length
          const Icon = rt.icon
          return (
            <Card key={rt.id} className="border-border/50 hover:border-primary/30 transition-colors cursor-pointer" onClick={() => setTypeFilter(typeFilter === rt.id ? 'all' : rt.id)}>
              <CardContent className="p-3 flex items-start gap-3">
                <div className={`w-8 h-8 rounded-lg flex items-center justify-center shrink-0 ${typeBadge[rt.id]}`}>
                  <Icon className="h-4 w-4" />
                </div>
                <div className="min-w-0">
                  <p className="text-xs font-semibold">{rt.label}</p>
                  <p className="text-[10px] text-muted-foreground mt-0.5 line-clamp-2">{rt.description}</p>
                  <p className="text-[10px] text-muted-foreground mt-1">{count} report{count !== 1 ? 's' : ''}</p>
                </div>
              </CardContent>
            </Card>
          )
        })}
      </div>

      {/* Filter */}
      <div className="flex items-center gap-2">
        <Select value={typeFilter} onValueChange={setTypeFilter}>
          <SelectTrigger className="w-[180px] h-8 text-xs border-border/50"><SelectValue placeholder="All Types" /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All Report Types</SelectItem>
            {reportTypes.map(rt => <SelectItem key={rt.id} value={rt.id}>{rt.label}</SelectItem>)}
          </SelectContent>
        </Select>
        <Badge variant="outline" className="text-[10px] bg-muted">{filtered.length} reports</Badge>
      </div>

      {/* Reports Table */}
      <Card className="border-border/50">
        <CardContent className="p-4">
          <div className="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow className="border-border/50 hover:bg-transparent">
                  <TableHead className="text-xs">Title</TableHead>
                  <TableHead className="text-xs">Type</TableHead>
                  <TableHead className="text-xs">Status</TableHead>
                  <TableHead className="text-xs">Tenant</TableHead>
                  <TableHead className="text-xs">Created</TableHead>
                  <TableHead className="text-xs text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filtered.map((report) => (
                  <TableRow key={report.id} className="border-border/30 cursor-pointer hover:bg-muted/30" onClick={() => report.status === 'completed' && setSelectedReport(report)}>
                    <TableCell className="text-xs font-medium py-2.5">
                      <div className="flex items-center gap-2">
                        {report.status === 'generating' && <Loader2 className="h-3 w-3 text-blue-400 animate-spin shrink-0" />}
                        {report.title}
                      </div>
                    </TableCell>
                    <TableCell className="py-2.5">
                      <Badge variant="outline" className={`text-[10px] ${typeBadge[report.type] ?? ''}`}>
                        {reportTypes.find(rt => rt.id === report.type)?.label ?? report.type}
                      </Badge>
                    </TableCell>
                    <TableCell className="py-2.5">
                      <Badge variant="outline" className={`text-[10px] ${statusBadge[report.status] ?? ''}`}>
                        {report.status}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-xs text-muted-foreground py-2.5">{report.tenant}</TableCell>
                    <TableCell className="text-xs text-muted-foreground py-2.5">{new Date(report.createdAt).toLocaleDateString()}</TableCell>
                    <TableCell className="py-2.5 text-right">
                      <div className="flex items-center justify-end gap-1">
                        <Button variant="ghost" size="sm" className="h-7 w-7 p-0" title="View" disabled={report.status !== 'completed'} onClick={(e) => { e.stopPropagation(); setSelectedReport(report) }}>
                          <Eye className="h-3.5 w-3.5" />
                        </Button>
                        <Button variant="ghost" size="sm" className="h-7 w-7 p-0" title="Download PDF" disabled={report.status !== 'completed'}>
                          <Download className="h-3.5 w-3.5" />
                        </Button>
                        <Button variant="ghost" size="sm" className="h-7 w-7 p-0 text-red-500" title="Delete">
                          <Trash2 className="h-3.5 w-3.5" />
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}

// ─── Report Detail ───────────────────────────────────────────────────────────

function ReportDetail({ report, onBack }: { report: Report; onBack: () => void }) {
  const severityCounts = report.findings.reduce((acc, f) => {
    acc[f.severity] = (acc[f.severity] || 0) + 1
    return acc
  }, {} as Record<string, number>)

  const findingsPieData = [
    { name: 'Critical', value: severityCounts.critical || 0, color: '#ef4444' },
    { name: 'High', value: severityCounts.high || 0, color: '#f97316' },
    { name: 'Medium', value: severityCounts.medium || 0, color: '#eab308' },
    { name: 'Low', value: severityCounts.low || 0, color: '#22c55e' },
  ].filter(d => d.value > 0)

  const radarData = Object.entries(report.riskCategories).map(([key, value]) => ({
    category: key.charAt(0).toUpperCase() + key.slice(1),
    score: value,
    fullMark: 100,
  }))

  const complianceBarData = report.complianceStatus.map(c => ({
    name: c.framework.length > 15 ? c.framework.substring(0, 15) + '...' : c.framework,
    score: c.score,
  }))

  const riskColor = report.riskScore !== null
    ? report.riskScore >= 80 ? 'text-red-500' : report.riskScore >= 60 ? 'text-amber-500' : report.riskScore >= 40 ? 'text-yellow-500' : 'text-green-500'
    : 'text-muted-foreground'

  return (
    <div className="space-y-6">
      {/* Back */}
      <Button variant="ghost" size="sm" className="h-8 text-xs gap-1" onClick={onBack}>
        <ChevronLeft className="h-3.5 w-3.5" />
        Back to Reports
      </Button>

      {/* Header */}
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-lg font-bold">{report.title}</h1>
          <div className="flex items-center gap-2 mt-1">
            <Badge variant="outline" className={`text-[10px] ${typeBadge[report.type] ?? ''}`}>
              {reportTypes.find(rt => rt.id === report.type)?.label}
            </Badge>
            <Badge variant="outline" className={`text-[10px] ${statusBadge[report.status]}`}>
              {report.status}
            </Badge>
            <span className="text-xs text-muted-foreground">{report.tenant}</span>
          </div>
        </div>
        <div className="text-right">
          <p className="text-xs text-muted-foreground">Risk Score</p>
          <p className={`text-3xl font-bold ${riskColor}`}>{report.riskScore ?? '—'}</p>
        </div>
      </div>

      {/* Executive Summary */}
      <Card className="border-border/50">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-semibold">Executive Summary</CardTitle>
        </CardHeader>
        <CardContent className="p-4 pt-0">
          <p className="text-sm text-muted-foreground leading-relaxed">{report.summary}</p>
          <div className="flex items-center gap-4 mt-3 text-xs text-muted-foreground">
            <span className="flex items-center gap-1"><Clock className="h-3 w-3" /> Generated: {new Date(report.createdAt).toLocaleString()}</span>
            {report.completedAt && (
              <span className="flex items-center gap-1"><CheckCircle className="h-3 w-3" /> Completed: {new Date(report.completedAt).toLocaleString()}</span>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Risk Radar */}
        {radarData.length > 0 && (
          <Card className="border-border/50">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-semibold">Risk Categories</CardTitle>
            </CardHeader>
            <CardContent className="p-4 pt-0">
              <div className="h-[280px]">
                <ResponsiveContainer width="100%" height="100%">
                  <RadarChart data={radarData}>
                    <PolarGrid stroke="oklch(0.28 0.015 155)" />
                    <PolarAngleAxis dataKey="category" tick={chartTickStyle} />
                    <PolarRadiusAxis angle={30} domain={[0, 100]} tick={chartTickStyle} />
                    <Radar name="Risk" dataKey="score" stroke="oklch(0.627 0.194 149.214)" fill="oklch(0.627 0.194 149.214)" fillOpacity={0.2} />
                  </RadarChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Findings Pie */}
        <Card className="border-border/50">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-semibold">Findings by Severity</CardTitle>
          </CardHeader>
          <CardContent className="p-4 pt-0">
            <div className="h-[280px]">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie data={findingsPieData} cx="50%" cy="50%" innerRadius={55} outerRadius={90} dataKey="value" label={({ name, value }) => `${name}: ${value}`}>
                    {findingsPieData.map((entry, idx) => (
                      <Cell key={idx} fill={entry.color} />
                    ))}
                  </Pie>
                  <RechartsTooltip contentStyle={chartTooltipStyle} labelStyle={chartLabelStyle} />
                </PieChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>

        {/* Compliance Bar */}
        {complianceBarData.length > 0 && (
          <Card className="border-border/50">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-semibold">Compliance Scores</CardTitle>
            </CardHeader>
            <CardContent className="p-4 pt-0">
              <div className="h-[280px]">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={complianceBarData} layout="vertical">
                    <XAxis type="number" domain={[0, 100]} tick={chartTickStyle} axisLine={false} tickLine={false} />
                    <YAxis dataKey="name" type="category" width={110} tick={chartTickStyle} axisLine={false} tickLine={false} />
                    <RechartsTooltip contentStyle={chartTooltipStyle} labelStyle={chartLabelStyle} />
                    <Bar dataKey="score" fill="oklch(0.627 0.194 149.214)" radius={[0, 4, 4, 0]} name="Score" />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>
        )}
      </div>

      {/* Affected Endpoints */}
      {report.affectedEndpoints.length > 0 && (
        <Card className="border-border/50">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm font-semibold">Affected Endpoints ({report.affectedEndpoints.length})</CardTitle>
          </CardHeader>
          <CardContent className="p-4 pt-0">
            <div className="flex flex-wrap gap-2">
              {report.affectedEndpoints.map((ep) => (
                <Badge key={ep} variant="outline" className="text-xs bg-muted/50 border-border/50 font-mono">
                  {ep}
                </Badge>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Compliance Status Table */}
      {report.complianceStatus.length > 0 && (
        <Card className="border-border/50">
          <CardHeader className="pb-3">
            <CardTitle className="text-sm font-semibold">Compliance Status</CardTitle>
          </CardHeader>
          <CardContent className="p-4 pt-0">
            <Table>
              <TableHeader>
                <TableRow className="border-border/50 hover:bg-transparent">
                  <TableHead className="text-xs">Framework</TableHead>
                  <TableHead className="text-xs">Score</TableHead>
                  <TableHead className="text-xs">Status</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {report.complianceStatus.map((c) => (
                  <TableRow key={c.framework} className="border-border/30">
                    <TableCell className="text-xs py-2">{c.framework}</TableCell>
                    <TableCell className="py-2">
                      <div className="flex items-center gap-2">
                        <Progress value={c.score} className="h-2 w-24" />
                        <span className="text-xs font-medium">{c.score}%</span>
                      </div>
                    </TableCell>
                    <TableCell className="py-2">
                      <Badge variant="outline" className={`text-[10px] ${
                        c.status === 'pass' ? 'bg-green-500/10 text-green-500 border-green-500/20' :
                        c.status === 'partial' ? 'bg-yellow-500/10 text-yellow-500 border-yellow-500/20' :
                        'bg-red-500/10 text-red-500 border-red-500/20'
                      }`}>
                        {c.status}
                      </Badge>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      )}

      {/* Detailed Findings */}
      <Card className="border-border/50">
        <CardHeader className="pb-3">
          <CardTitle className="text-sm font-semibold">Detailed Findings ({report.findings.length})</CardTitle>
        </CardHeader>
        <CardContent className="p-4 pt-0 space-y-3">
          {report.findings.map((finding, idx) => (
            <div key={idx} className="rounded-lg border border-border/50 p-4 space-y-2">
              <div className="flex items-center gap-2">
                <Badge variant="outline" className={`text-[10px] ${severityBadge[finding.severity] ?? ''}`}>
                  {finding.severity}
                </Badge>
                <span className="text-sm font-semibold">{finding.title}</span>
              </div>
              <p className="text-xs text-muted-foreground">{finding.description}</p>
              <div className="rounded-md bg-primary/5 border border-primary/10 p-2">
                <p className="text-xs text-primary">
                  <span className="font-semibold">Recommendation: </span>
                  {finding.recommendation}
                </p>
              </div>
            </div>
          ))}
          {report.findings.length === 0 && (
            <p className="text-xs text-muted-foreground text-center py-4">No findings available for this report.</p>
          )}
        </CardContent>
      </Card>
    </div>
  )
}

// ─── Generate Report Dialog ──────────────────────────────────────────────────

function GenerateReportDialog() {
  const [open, setOpen] = useState(false)
  const [reportType, setReportType] = useState('endpoint_health')
  const [title, setTitle] = useState('')
  const [scope, setScope] = useState('all')
  const [tenant, setTenant] = useState('all')
  const [submitting, setSubmitting] = useState(false)

  const handleGenerate = async () => {
    setSubmitting(true)
    try {
      const autoTitle = `${reportTypes.find(rt => rt.id === reportType)?.label ?? reportType} - ${new Date().toISOString().split('T')[0]}`
      await fetch('/api/reports/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          type: reportType,
          title: title || autoTitle,
          tenantId: tenant === 'all' ? null : tenant,
          scope,
        }),
      })
      setOpen(false)
      setReportType('endpoint_health')
      setTitle('')
      setScope('all')
      setTenant('all')
    } catch { /* silent */ }
    setSubmitting(false)
  }

  const selectedType = reportTypes.find(rt => rt.id === reportType)

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="bg-primary hover:bg-primary/90 text-primary-foreground h-8 text-xs">
          <Plus className="h-3.5 w-3.5 mr-1.5" />
          Generate Report
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-lg border-border/50 bg-card">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <BarChart3 className="h-4 w-4 text-primary" />
            Generate Security Report
          </DialogTitle>
          <DialogDescription>Configure and generate a new security report.</DialogDescription>
        </DialogHeader>
        <div className="space-y-4 py-2">
          <div className="space-y-2">
            <label className="text-xs font-medium text-muted-foreground">Report Type</label>
            <Select value={reportType} onValueChange={setReportType}>
              <SelectTrigger className="h-8 text-xs border-border/50"><SelectValue /></SelectTrigger>
              <SelectContent>
                {reportTypes.map(rt => (
                  <SelectItem key={rt.id} value={rt.id}>{rt.label} — {rt.description}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-2">
            <label className="text-xs font-medium text-muted-foreground">Title (optional)</label>
            <Input
              className="h-8 text-xs border-border/50"
              placeholder={selectedType ? `${selectedType.label} - ${new Date().toISOString().split('T')[0]}` : 'Report title'}
              value={title}
              onChange={(e) => setTitle(e.target.value)}
            />
          </div>
          <div className="space-y-2">
            <label className="text-xs font-medium text-muted-foreground">Scope</label>
            <Select value={scope} onValueChange={setScope}>
              <SelectTrigger className="h-8 text-xs border-border/50"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Endpoints</SelectItem>
                <SelectItem value="critical">Critical Endpoints Only</SelectItem>
                <SelectItem value="flagged">Flagged Endpoints</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div className="space-y-2">
            <label className="text-xs font-medium text-muted-foreground">Tenant</label>
            <Select value={tenant} onValueChange={setTenant}>
              <SelectTrigger className="h-8 text-xs border-border/50"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Tenants</SelectItem>
                <SelectItem value="acme">Acme Corp</SelectItem>
                <SelectItem value="techstart">TechStart Inc</SelectItem>
                <SelectItem value="globalfin">Global Financial</SelectItem>
                <SelectItem value="healthcare">HealthCare Plus</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>
        <DialogFooter className="gap-2">
          <Button variant="outline" onClick={() => setOpen(false)} className="border-border/50 text-xs">Cancel</Button>
          <Button onClick={handleGenerate} disabled={submitting} className="bg-primary hover:bg-primary/90 text-primary-foreground text-xs">
            {submitting ? <Loader2 className="h-3.5 w-3.5 mr-1.5 animate-spin" /> : <BarChart3 className="h-3.5 w-3.5 mr-1.5" />}
            Generate Report
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// ─── Fallback Mock Reports ───────────────────────────────────────────────────

function getMockReports(): Report[] {
  return [
    {
      id: 'rpt-mock-1', title: 'Endpoint Health Report - Sample', type: 'endpoint_health',
      status: 'completed', tenant: 'All Tenants', createdAt: new Date().toISOString(),
      completedAt: new Date().toISOString(), summary: 'Sample report data.',
      riskScore: 72, findings: [], riskCategories: { network: 65, endpoint: 78, data: 55, identity: 42, compliance: 81 },
      affectedEndpoints: [], complianceStatus: [],
    },
  ]
}

import { Monitor } from 'lucide-react'
