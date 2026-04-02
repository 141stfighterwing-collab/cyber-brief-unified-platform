'use client'

import { Shield, ShieldCheck } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { useAppStore } from '@/lib/store'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'

const navItems = [
  { id: 'dashboard' as const, label: 'Dashboard' },
  { id: 'alerts' as const, label: 'Alerts' },
  { id: 'briefs' as const, label: 'Briefs' },
  { id: 'monitoring' as const, label: 'Monitoring' },
  { id: 'workflow' as const, label: 'Workflow' },
]

export function Navbar() {
  const { currentView, setView, user, setUser, isAuthenticated } = useAppStore()

  if (!isAuthenticated) return null

  const initials = user?.name
    ? user.name.split(' ').map((n) => n[0]).join('').toUpperCase().slice(0, 2)
    : 'U'

  return (
    <header className="sticky top-0 z-50 border-b border-border/50 bg-card/80 backdrop-blur-xl">
      <div className="flex h-14 items-center justify-between px-4 lg:px-6">
        <div className="flex items-center gap-6">
          <button
            onClick={() => setView('dashboard')}
            className="flex items-center gap-2 transition-opacity hover:opacity-80"
          >
            <ShieldCheck className="h-6 w-6 text-primary" />
            <span className="font-bold text-sm tracking-tight">Cyber Brief Unified Platform</span>
          </button>
          <nav className="hidden md:flex items-center gap-1">
            {navItems.map((item) => (
              <button
                key={item.id}
                onClick={() => setView(item.id)}
                className={`px-3 py-1.5 rounded-md text-sm font-medium transition-colors ${
                  currentView === item.id
                    ? 'bg-primary/10 text-primary'
                    : 'text-muted-foreground hover:text-foreground hover:bg-muted'
                }`}
              >
                {item.label}
              </button>
            ))}
          </nav>
        </div>
        <div className="flex items-center gap-3">
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" className="relative h-8 w-8 rounded-full">
                <Avatar className="h-8 w-8">
                  <AvatarFallback className="bg-primary/10 text-primary text-xs font-semibold">
                    {initials}
                  </AvatarFallback>
                </Avatar>
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-56">
              <div className="flex items-center gap-2 p-2">
                <Avatar className="h-8 w-8">
                  <AvatarFallback className="bg-primary/10 text-primary text-xs font-semibold">
                    {initials}
                  </AvatarFallback>
                </Avatar>
                <div className="flex flex-col space-y-0.5">
                  <p className="text-sm font-medium">{user?.name || 'User'}</p>
                  <p className="text-xs text-muted-foreground">{user?.email}</p>
                </div>
              </div>
              <DropdownMenuSeparator />
              <DropdownMenuItem className="text-xs text-muted-foreground">
                Tier: <span className="ml-auto capitalize font-medium text-foreground">{user?.tier || 'free'}</span>
              </DropdownMenuItem>
              {user?.company && (
                <DropdownMenuItem className="text-xs text-muted-foreground">
                  Company: <span className="ml-auto font-medium text-foreground">{user.company}</span>
                </DropdownMenuItem>
              )}
              <DropdownMenuSeparator />
              <DropdownMenuItem
                onClick={() => {
                  setUser(null)
                }}
                className="text-red-500 cursor-pointer"
              >
                Sign Out
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>
      {/* Mobile nav */}
      <div className="flex md:hidden items-center gap-1 px-4 pb-2 overflow-x-auto">
        {navItems.map((item) => (
          <button
            key={item.id}
            onClick={() => setView(item.id)}
            className={`px-3 py-1 rounded-md text-xs font-medium whitespace-nowrap transition-colors ${
              currentView === item.id
                ? 'bg-primary/10 text-primary'
                : 'text-muted-foreground hover:text-foreground'
            }`}
          >
            {item.label}
          </button>
        ))}
      </div>
    </header>
  )
}

export function LandingNav() {
  const { setView, isAuthenticated } = useAppStore()

  if (isAuthenticated) return null

  return (
    <header className="sticky top-0 z-50 border-b border-border/30 bg-background/80 backdrop-blur-xl">
      <div className="flex h-14 items-center justify-between px-4 lg:px-6">
        <button
          onClick={() => setView('landing')}
          className="flex items-center gap-2 transition-opacity hover:opacity-80"
        >
          <Shield className="h-6 w-6 text-primary" />
          <span className="font-bold text-sm tracking-tight">Cyber Brief Unified Platform</span>
        </button>
        <div className="flex items-center gap-3">
          <Button variant="ghost" size="sm" onClick={() => setView('auth')}>
            Sign In
          </Button>
          <Button size="sm" onClick={() => { useAppStore.getState().setAuthMode('signup'); setView('auth') }}>
            Get Started
          </Button>
        </div>
      </div>
    </header>
  )
}
