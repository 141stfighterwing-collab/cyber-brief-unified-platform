'use client'

import { Shield, ShieldCheck, Crown, FileText } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { useAppStore } from '@/lib/store'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  DropdownMenuSub,
  DropdownMenuSubContent,
  DropdownMenuSubTrigger,
} from '@/components/ui/dropdown-menu'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { Building2 } from 'lucide-react'

const baseNavItems = [
  { id: 'dashboard' as const, label: 'Dashboard' },
  { id: 'alerts' as const, label: 'Alerts' },
  { id: 'briefs' as const, label: 'Briefs' },
  { id: 'monitoring' as const, label: 'Monitoring' },
  { id: 'agents' as const, label: 'Agents', showLive: true },
  { id: 'workflow' as const, label: 'Workflow' },
]

const adminNavItems = [
  { id: 'admin' as const, label: 'Admin', icon: Crown, roleRequired: 'super_admin' as const },
  { id: 'reports' as const, label: 'Reports', icon: FileText, roleRequired: 'admin' as const },
]

export function Navbar() {
  const { currentView, setView, user, setUser, isAuthenticated, wsConnected } = useAppStore()

  if (!isAuthenticated) return null

  const initials = user?.name
    ? user.name.split(' ').map((n) => n[0]).join('').toUpperCase().slice(0, 2)
    : 'U'

  const userRole = user?.role || 'user'
  const isSuperAdmin = userRole === 'super_admin'
  const isAdmin = userRole === 'admin' || isSuperAdmin

  const filteredAdminItems = adminNavItems.filter((item) => {
    if (item.roleRequired === 'super_admin') return isSuperAdmin
    if (item.roleRequired === 'admin') return isAdmin
    return true
  })

  const allNavItems = [...baseNavItems, ...filteredAdminItems]

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
            {allNavItems.map((item) => {
              const Icon = item.icon
              return (
                <button
                  key={item.id}
                  onClick={() => setView(item.id)}
                  className={`px-3 py-1.5 rounded-md text-sm font-medium transition-colors flex items-center gap-1.5 ${
                    currentView === item.id
                      ? 'bg-primary/10 text-primary'
                      : 'text-muted-foreground hover:text-foreground hover:bg-muted'
                  }`}
                >
                  {Icon && <Icon className="h-3.5 w-3.5" />}
                  {item.label}
                  {item.id === 'agents' && wsConnected && (
                    <span className="flex items-center gap-1 ml-0.5">
                      <span className="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse" />
                      <span className="text-[10px] text-green-500 font-medium">LIVE</span>
                    </span>
                  )}
                </button>
              )
            })}
          </nav>
        </div>
        <div className="flex items-center gap-3">
          {/* Tenant Selector */}
          {isSuperAdmin && (
            <TenantSelector />
          )}

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
              <DropdownMenuItem className="text-xs text-muted-foreground">
                Role: <span className="ml-auto capitalize font-medium text-foreground">{userRole.replace('_', ' ')}</span>
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
        {allNavItems.map((item) => {
          const Icon = item.icon
          return (
            <button
              key={item.id}
              onClick={() => setView(item.id)}
              className={`px-3 py-1 rounded-md text-xs font-medium whitespace-nowrap transition-colors flex items-center gap-1.5 ${
                currentView === item.id
                  ? 'bg-primary/10 text-primary'
                  : 'text-muted-foreground hover:text-foreground'
              }`}
            >
              {Icon && <Icon className="h-3 w-3" />}
              {item.label}
              {item.id === 'agents' && wsConnected && (
                <span className="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse" />
              )}
            </button>
          )
        })}
      </div>
    </header>
  )
}

function TenantSelector() {
  const { currentTenantId, setCurrentTenantId } = useAppStore()
  const [tenants, setTenants] = useState<{id: string, name: string}[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    fetch('/api/tenants')
      .then(r => r.json())
      .then((data) => {
        if (!cancelled && Array.isArray(data)) {
          setTenants(data.map((t: any) => ({ id: t.id, name: t.name })))
        }
      })
      .catch(() => {
        if (!cancelled) {
          setTenants([
            { id: 'all', name: 'All Tenants' },
            { id: 't1', name: 'Acme Corp' },
            { id: 't2', name: 'TechStart Inc' },
            { id: 't3', name: 'Global Financial' },
          ])
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => { cancelled = true }
  }, [])

  const currentName = tenants.find(t => t.id === currentTenantId)?.name || 'All Tenants'

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="outline" size="sm" className="h-8 text-xs gap-1.5 border-border/50">
          <Building2 className="h-3 w-3 text-primary" />
          <span className="hidden sm:inline max-w-[120px] truncate">{currentName}</span>
          <span className="sm:hidden">{currentName.split(' ')[0]}</span>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-48">
        <DropdownMenuItem onClick={() => setCurrentTenantId(null)}>
          All Tenants
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        {tenants.filter(t => t.id !== 'all').map((tenant) => (
          <DropdownMenuItem
            key={tenant.id}
            onClick={() => setCurrentTenantId(tenant.id)}
            className={currentTenantId === tenant.id ? 'bg-primary/10 text-primary' : ''}
          >
            {tenant.name}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

import { useState, useEffect } from 'react'

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
