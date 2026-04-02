'use client'

import { ShieldCheck } from 'lucide-react'

export function Footer() {
  return (
    <footer className="border-t border-border/30 bg-card/50">
      <div className="container mx-auto px-4 py-8 lg:px-6">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-8">
          <div className="col-span-2 md:col-span-1">
            <div className="flex items-center gap-2 mb-3">
              <ShieldCheck className="h-5 w-5 text-primary" />
              <span className="font-semibold text-sm">CBUP</span>
            </div>
            <p className="text-xs text-muted-foreground leading-relaxed">
              Unified cybersecurity awareness, real-time alerts, workflow management, and monitoring — deployable locally or on-prem.
            </p>
          </div>
          <div>
            <h4 className="font-semibold text-xs mb-3 text-foreground">Product</h4>
            <ul className="space-y-2 text-xs text-muted-foreground">
              <li className="hover:text-foreground cursor-pointer transition-colors">Features</li>
              <li className="hover:text-foreground cursor-pointer transition-colors">Pricing</li>
              <li className="hover:text-foreground cursor-pointer transition-colors">API Docs</li>
              <li className="hover:text-foreground cursor-pointer transition-colors">Changelog</li>
            </ul>
          </div>
          <div>
            <h4 className="font-semibold text-xs mb-3 text-foreground">Company</h4>
            <ul className="space-y-2 text-xs text-muted-foreground">
              <li className="hover:text-foreground cursor-pointer transition-colors">About</li>
              <li className="hover:text-foreground cursor-pointer transition-colors">Blog</li>
              <li className="hover:text-foreground cursor-pointer transition-colors">Careers</li>
              <li className="hover:text-foreground cursor-pointer transition-colors">Contact</li>
            </ul>
          </div>
          <div>
            <h4 className="font-semibold text-xs mb-3 text-foreground">Security</h4>
            <ul className="space-y-2 text-xs text-muted-foreground">
              <li className="hover:text-foreground cursor-pointer transition-colors">Trust Center</li>
              <li className="hover:text-foreground cursor-pointer transition-colors">Privacy Policy</li>
              <li className="hover:text-foreground cursor-pointer transition-colors">Terms of Service</li>
              <li className="hover:text-foreground cursor-pointer transition-colors">SOC 2 Report</li>
            </ul>
          </div>
        </div>
        <div className="mt-8 pt-4 border-t border-border/30 flex flex-col md:flex-row items-center justify-between gap-2">
          <p className="text-xs text-muted-foreground">
            © 2025 Cyber Brief Unified Platform. All rights reserved.
          </p>
          <p className="text-xs text-muted-foreground">
            🔒 Trusted by 2,400+ security teams worldwide
          </p>
        </div>
      </div>
    </footer>
  )
}
