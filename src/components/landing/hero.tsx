'use client'

import { ShieldCheck, ArrowRight, Lock, Activity, Zap, Server, Globe } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { useAppStore } from '@/lib/store'

export function Hero() {
  const { setView, setAuthMode } = useAppStore()

  return (
    <section className="relative overflow-hidden">
      {/* Background effects */}
      <div className="absolute inset-0 cyber-grid" />
      <div className="absolute inset-0 bg-gradient-to-b from-primary/5 via-transparent to-transparent" />
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[400px] bg-primary/10 blur-[120px] rounded-full" />

      <div className="relative container mx-auto px-4 lg:px-6 py-20 md:py-32">
        <div className="max-w-4xl mx-auto text-center">
          {/* Badge */}
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-primary/10 border border-primary/20 mb-6">
            <Activity className="h-3 w-3 text-primary" />
            <span className="text-xs font-medium text-primary">Threat Level: ELEVATED — Updated 2 min ago</span>
          </div>

          <h1 className="text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight mb-6">
            <span className="cyber-glow-text">One platform.</span>
            <br />
            <span className="text-primary cyber-glow-text">Every threat covered.</span>
          </h1>

          <p className="text-lg md:text-xl text-muted-foreground max-w-2xl mx-auto mb-10 leading-relaxed">
            The unified cybersecurity platform trusted by 2,400+ teams. Get actionable threat intelligence,
            real-time alerts, workflow management, and compliance monitoring — all in one place.
          </p>

          <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
            <Button
              size="lg"
              className="cyber-glow text-base px-8"
              onClick={() => { setAuthMode('signup'); setView('auth') }}
            >
              Get Started Free
              <ArrowRight className="ml-2 h-4 w-4" />
            </Button>
            <Button
              size="lg"
              variant="outline"
              className="text-base px-8"
              onClick={() => setView('briefs')}
            >
              View Sample Brief
            </Button>
          </div>

          {/* Trust indicators */}
          <div className="mt-12 flex flex-wrap items-center justify-center gap-6 text-xs text-muted-foreground">
            <div className="flex items-center gap-1.5">
              <Lock className="h-3.5 w-3.5 text-primary" />
              <span>SOC 2 Compliant</span>
            </div>
            <div className="flex items-center gap-1.5">
              <ShieldCheck className="h-3.5 w-3.5 text-primary" />
              <span>GDPR Ready</span>
            </div>
            <div className="flex items-center gap-1.5">
              <Server className="h-3.5 w-3.5 text-primary" />
              <span>On-Prem Available</span>
            </div>
            <div className="flex items-center gap-1.5">
              <Globe className="h-3.5 w-3.5 text-primary" />
              <span>Global Threat Intel</span>
            </div>
            <div className="flex items-center gap-1.5">
              <Zap className="h-3.5 w-3.5 text-primary" />
              <span>Real-Time Alerts</span>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
