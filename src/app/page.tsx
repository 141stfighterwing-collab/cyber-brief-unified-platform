'use client'

import { useAppStore } from '@/lib/store'
import { Navbar, LandingNav } from '@/components/shared/navbar'
import { Footer } from '@/components/shared/footer'
import { Hero } from '@/components/landing/hero'
import { Features } from '@/components/landing/features'
import { Pricing } from '@/components/landing/pricing'
import { SamplePreview } from '@/components/landing/sample-preview'
import { Testimonials } from '@/components/landing/testimonials'
import { AuthForm } from '@/components/auth/signup-form'
import { DashboardView } from '@/components/dashboard/dashboard-view'
import { AlertsView } from '@/components/alerts/alerts-view'
import { BriefView } from '@/components/briefs/brief-view'
import { MonitoringView } from '@/components/monitoring/monitoring-view'
import { WorkflowView } from '@/components/workflow/workflow-view'

export default function Home() {
  const { currentView, isAuthenticated } = useAppStore()

  return (
    <div className="min-h-screen flex flex-col">
      {/* Navbar */}
      {isAuthenticated ? <Navbar /> : <LandingNav />}

      {/* Scan line effect (subtle) */}
      <div className="scanline" />

      {/* Main Content */}
      <main className="flex-1">
        {currentView === 'landing' && (
          <>
            <Hero />
            <Features />
            <SamplePreview />
            <Pricing />
            <Testimonials />
            <Footer />
          </>
        )}

        {currentView === 'auth' && (
          <>
            <AuthForm />
            <Footer />
          </>
        )}

        {currentView === 'dashboard' && (
          <div className="container mx-auto px-4 lg:px-6 py-6">
            <DashboardView />
          </div>
        )}

        {currentView === 'alerts' && (
          <div className="container mx-auto px-4 lg:px-6 py-6">
            <AlertsView />
          </div>
        )}

        {currentView === 'briefs' && (
          <div className="container mx-auto px-4 lg:px-6 py-6">
            <BriefView />
          </div>
        )}

        {currentView === 'monitoring' && (
          <div className="container mx-auto px-4 lg:px-6 py-6">
            <MonitoringView />
          </div>
        )}

        {currentView === 'workflow' && (
          <div className="container mx-auto px-4 lg:px-6 py-6">
            <WorkflowView />
          </div>
        )}
      </main>

      {/* App footer when authenticated */}
      {isAuthenticated && (
        <footer className="border-t border-border/30 py-4">
          <div className="container mx-auto px-4 lg:px-6 flex items-center justify-between">
            <p className="text-xs text-muted-foreground">
              © 2025 Cyber Brief Unified Platform
            </p>
            <p className="text-xs text-muted-foreground">
              Threat Level: ELEVATED
            </p>
          </div>
        </footer>
      )}
    </div>
  )
}
