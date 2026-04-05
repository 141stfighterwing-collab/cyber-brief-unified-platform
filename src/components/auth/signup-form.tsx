'use client'

import { useState } from 'react'
import { ShieldCheck, Eye, EyeOff, Loader2 } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Card, CardContent, CardHeader } from '@/components/ui/card'
import { useAppStore } from '@/lib/store'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'

export function AuthForm() {
  const { authMode, setAuthMode, setUser } = useAppStore()
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  // Form fields
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [company, setCompany] = useState('')
  const [password, setPassword] = useState('')
  const [tier, setTier] = useState('free')

  const handleSignup = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    if (tier === 'enterprise') {
      setError('Enterprise tier requires a custom contract. Please contact our sales team.')
      setLoading(false)
      return
    }

    try {
      const res = await fetch('/api/auth/signup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, email, company, password, tier }),
      })

      if (!res.ok) {
        const data = await res.json()
        setError(data.error || 'Signup failed')
        return
      }

      const user = await res.json()
      setUser(user)
    } catch {
      setError('Network error. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    try {
      const res = await fetch('/api/auth/signup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, action: 'login' }),
      })

      if (!res.ok) {
        const data = await res.json()
        if (res.status === 404) {
          setError('No account found with this email. Try signing up first, or use the default admin account.')
        } else if (res.status === 429) {
          setError('Too many attempts. Please wait a moment and try again.')
        } else {
          setError(data.error || 'Login failed')
        }
        return
      }

      const user = await res.json()
      setUser(user)
    } catch {
      setError('Network error. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-[calc(100vh-3.5rem)] flex items-center justify-center px-4 py-12">
      <div className="w-full max-w-md">
        <div className="text-center mb-8">
          <ShieldCheck className="h-10 w-10 text-primary mx-auto mb-3" />
          <h1 className="text-2xl font-bold">
            {authMode === 'signup' ? 'Create your account' : 'Welcome back'}
          </h1>
          <p className="text-sm text-muted-foreground mt-1">
            {authMode === 'signup'
              ? 'Start your free cybersecurity briefing today'
              : 'Sign in to your Cyber Brief Unified Platform account'}
          </p>
        </div>

        <Card className="border-border/50">
          <CardHeader className="pb-4">
            <div className="flex items-center rounded-lg bg-muted p-1">
              <button
                onClick={() => { setAuthMode('login'); setError('') }}
                className={`flex-1 py-2 text-sm font-medium rounded-md transition-colors ${
                  authMode === 'login'
                    ? 'bg-card shadow-sm text-foreground'
                    : 'text-muted-foreground hover:text-foreground'
                }`}
              >
                Sign In
              </button>
              <button
                onClick={() => { setAuthMode('signup'); setError('') }}
                className={`flex-1 py-2 text-sm font-medium rounded-md transition-colors ${
                  authMode === 'signup'
                    ? 'bg-card shadow-sm text-foreground'
                    : 'text-muted-foreground hover:text-foreground'
                }`}
              >
                Sign Up
              </button>
            </div>
          </CardHeader>
          <CardContent>
            <form onSubmit={authMode === 'signup' ? handleSignup : handleLogin} className="space-y-4">
              {authMode === 'signup' && (
                <div className="space-y-2">
                  <Label htmlFor="name" className="text-xs">Full Name</Label>
                  <Input
                    id="name"
                    placeholder="John Doe"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    required
                    className="h-9"
                  />
                </div>
              )}

              <div className="space-y-2">
                <Label htmlFor="email" className="text-xs">Email</Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="john@company.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  className="h-9"
                />
              </div>

              {authMode === 'signup' && (
                <div className="space-y-2">
                  <Label htmlFor="company" className="text-xs">Company Name</Label>
                  <Input
                    id="company"
                    placeholder="Acme Corp"
                    value={company}
                    onChange={(e) => setCompany(e.target.value)}
                    className="h-9"
                  />
                </div>
              )}

              <div className="space-y-2">
                <Label htmlFor="password" className="text-xs">Password</Label>
                <div className="relative">
                  <Input
                    id="password"
                    type={showPassword ? 'text' : 'password'}
                    placeholder="••••••••"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    required
                    className="h-9 pr-10"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                  >
                    {showPassword ? <EyeOff className="h-3.5 w-3.5" /> : <Eye className="h-3.5 w-3.5" />}
                  </button>
                </div>
              </div>

              {authMode === 'signup' && (
                <div className="space-y-2">
                  <Label className="text-xs">Plan</Label>
                  <Select value={tier} onValueChange={setTier}>
                    <SelectTrigger className="h-9">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="free">Free — $0/mo</SelectItem>
                      <SelectItem value="starter">Starter — $29/mo</SelectItem>
                      <SelectItem value="pro">Pro — $99/mo</SelectItem>
                      <SelectItem value="enterprise">Enterprise — Custom</SelectItem>
                    </SelectContent>
                  </Select>
                  {tier === 'enterprise' && (
                    <p className="text-xs text-amber-500">
                      Enterprise plans require a custom contract. Contact our sales team.
                    </p>
                  )}
                </div>
              )}

              {error && (
                <div className="text-xs text-red-500 bg-red-500/10 p-2.5 rounded-lg">
                  {error}
                </div>
              )}

              {authMode === 'login' && (
                <div className="text-xs text-muted-foreground bg-muted/50 p-2.5 rounded-lg border border-border/30">
                  <span className="font-medium">Default admin:</span>{' '}
                  admin@cbup.io / CBUPadmin2024!
                </div>
              )}

              <Button type="submit" className="w-full" disabled={loading}>
                {loading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                {authMode === 'signup' ? 'Create Account' : 'Sign In'}
              </Button>
            </form>

            <div className="mt-4 text-center">
              <button
                onClick={() => useAppStore.getState().setView('landing')}
                className="text-xs text-muted-foreground hover:text-foreground transition-colors"
              >
                ← Back to home
              </button>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
