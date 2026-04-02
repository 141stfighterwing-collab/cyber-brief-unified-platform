'use client'

import { AlertTriangle, Clock, ArrowRight, ShieldCheck, TrendingUp, Users } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { useAppStore } from '@/lib/store'

export function SamplePreview() {
  const { setView } = useAppStore()

  return (
    <section className="container mx-auto px-4 lg:px-6 py-20">
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 items-center">
        <div>
          <h2 className="text-2xl md:text-3xl font-bold mb-4">
            A smarter way to stay informed
          </h2>
          <p className="text-muted-foreground mb-6 leading-relaxed">
            Our AI-curated daily brief cuts through the noise, delivering only the threats
            and intelligence that matter to your organization. No information overload,
            just actionable insights.
          </p>
          <div className="space-y-4 mb-8">
            <div className="flex items-start gap-3">
              <div className="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center shrink-0 mt-0.5">
                <ShieldCheck className="h-4 w-4 text-primary" />
              </div>
              <div>
                <h4 className="font-semibold text-sm">Curated by Experts + AI</h4>
                <p className="text-xs text-muted-foreground">
                  Every brief is reviewed by our security analysts and enhanced with AI-driven relevance scoring.
                </p>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <div className="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center shrink-0 mt-0.5">
                <TrendingUp className="h-4 w-4 text-primary" />
              </div>
              <div>
                <h4 className="font-semibold text-sm">Trend Analysis</h4>
                <p className="text-xs text-muted-foreground">
                  Track how threat levels evolve over time with interactive charts and historical data.
                </p>
              </div>
            </div>
            <div className="flex items-start gap-3">
              <div className="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center shrink-0 mt-0.5">
                <Users className="h-4 w-4 text-primary" />
              </div>
              <div>
                <h4 className="font-semibold text-sm">Team Collaboration</h4>
                <p className="text-xs text-muted-foreground">
                  Share briefs, assign tasks, and coordinate responses across your security team.
                </p>
              </div>
            </div>
          </div>
          <Button variant="outline" onClick={() => setView('briefs')}>
            View Full Sample Brief
            <ArrowRight className="ml-2 h-4 w-4" />
          </Button>
        </div>

        {/* Preview card */}
        <Card className="border-border/50 shadow-2xl">
          <CardContent className="p-0">
            <div className="bg-muted/50 px-5 py-3 border-b border-border/50 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <ShieldCheck className="h-4 w-4 text-primary" />
                <span className="font-semibold text-sm">Cyber Brief Unified Platform</span>
              </div>
              <div className="flex items-center gap-1.5">
                <span className="text-xs text-muted-foreground">Vol. 847</span>
                <span className="text-xs text-muted-foreground">•</span>
                <Clock className="h-3 w-3 text-muted-foreground" />
                <span className="text-xs text-muted-foreground">6:00 AM EST</span>
              </div>
            </div>
            <div className="p-5 space-y-4">
              <div className="flex items-center gap-2">
                <Badge variant="destructive" className="text-xs">ELEVATED</Badge>
                <span className="text-xs text-muted-foreground">Threat Score: 78/100</span>
              </div>
              <div className="space-y-3">
                {[
                  { title: 'Apache Log4j RCE (CVE-2025-2177)', severity: 'critical' },
                  { title: 'Microsoft Exchange Zero-Day Active Exploit', severity: 'critical' },
                  { title: 'BlackStorm Ransomware Healthcare Campaign', severity: 'high' },
                  { title: 'OpenSSL Certificate Forgery (CVE-2025-2931)', severity: 'critical' },
                ].map((item, i) => (
                  <div key={i} className="flex items-start gap-2 p-2.5 rounded-lg bg-muted/30">
                    <AlertTriangle className={`h-4 w-4 mt-0.5 shrink-0 ${
                      item.severity === 'critical' ? 'text-red-500' : 'text-amber-500'
                    }`} />
                    <div>
                      <p className="text-xs font-medium">{item.title}</p>
                      <p className="text-xs text-muted-foreground mt-0.5">
                        {item.severity === 'critical' ? 'Immediate action required' : 'Monitor closely'}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
              <div className="text-center pt-2">
                <p className="text-xs text-muted-foreground">
                  + 14 more items in today&apos;s full briefing
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </section>
  )
}
