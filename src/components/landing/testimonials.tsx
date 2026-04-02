'use client'

import { ShieldCheck, Globe, Clock, TrendingUp, Award, Users } from 'lucide-react'

const stats = [
  { icon: ShieldCheck, value: '2,400+', label: 'Security Teams' },
  { icon: Globe, value: '50+', label: 'Countries' },
  { icon: Clock, value: '24/7', label: 'Threat Monitoring' },
  { icon: TrendingUp, value: '15K+', label: 'Threats Tracked' },
  { icon: Award, value: '99.9%', label: 'Uptime SLA' },
  { icon: Users, value: '12K+', label: 'Active Users' },
]

const testimonials = [
  {
    quote: "Cyber Brief Unified Platform has transformed our security operations. We went from reactive to proactive in just two weeks.",
    author: 'Sarah Mitchell',
    role: 'CISO, TechVault Inc.',
    avatar: 'SM',
  },
  {
    quote: "The daily briefs are incredibly well-curated. Our team saves hours every week that we used to spend filtering through noise.",
    author: 'David Park',
    role: 'VP of Security, CloudSync',
    avatar: 'DP',
  },
  {
    quote: "The workflow management feature alone is worth the subscription. It's brought accountability and structure to our incident response.",
    author: 'Maria Garcia',
    role: 'Security Lead, DataFort',
    avatar: 'MG',
  },
]

export function Testimonials() {
  return (
    <section className="container mx-auto px-4 lg:px-6 py-20">
      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4 mb-16">
        {stats.map((stat) => (
          <div key={stat.label} className="text-center p-4">
            <stat.icon className="h-5 w-5 text-primary mx-auto mb-2" />
            <div className="text-xl md:text-2xl font-bold">{stat.value}</div>
            <div className="text-xs text-muted-foreground mt-0.5">{stat.label}</div>
          </div>
        ))}
      </div>

      {/* Testimonials */}
      <div className="text-center mb-10">
        <h2 className="text-2xl md:text-3xl font-bold mb-3">
          Trusted by security teams worldwide
        </h2>
        <p className="text-muted-foreground max-w-xl mx-auto">
          Hear from the teams that rely on Cyber Brief Unified Platform every day.
        </p>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {testimonials.map((t) => (
          <div
            key={t.author}
            className="rounded-xl border border-border/50 bg-card p-6"
          >
            <p className="text-sm text-muted-foreground leading-relaxed mb-4">
              &ldquo;{t.quote}&rdquo;
            </p>
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center">
                <span className="text-xs font-semibold text-primary">{t.avatar}</span>
              </div>
              <div>
                <div className="text-sm font-medium">{t.author}</div>
                <div className="text-xs text-muted-foreground">{t.role}</div>
              </div>
            </div>
          </div>
        ))}
      </div>
    </section>
  )
}
