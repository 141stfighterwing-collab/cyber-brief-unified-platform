import { create } from 'zustand'

export type AppView = 
  | 'landing'
  | 'auth'
  | 'dashboard'
  | 'alerts'
  | 'briefs'
  | 'monitoring'
  | 'workflow'
  | 'agents'
  | 'admin'
  | 'reports'

export interface User {
  id: string
  email: string
  name: string | null
  company: string | null
  tier: string
  role: string // 'user' | 'admin' | 'super_admin'
}

export interface AppState {
  // Navigation
  currentView: AppView
  previousView: AppView | null
  setView: (view: AppView) => void
  goBack: () => void

  // Auth
  user: User | null
  setUser: (user: User | null) => void
  isAuthenticated: boolean

  // Auth form state
  authMode: 'login' | 'signup'
  setAuthMode: (mode: 'login' | 'signup') => void

  // Task management
  tasksUpdated: number
  triggerTasksUpdate: () => void

  // Tenant management
  currentTenantId: string | null
  setCurrentTenantId: (id: string | null) => void

  // Live data
  liveTelemetry: Record<string, any>
  setLiveTelemetry: (data: Record<string, any>) => void

  // WebSocket connection state
  wsConnected: boolean
  setWsConnected: (connected: boolean) => void
}

export const useAppStore = create<AppState>((set, get) => ({
  // Navigation
  currentView: 'landing',
  previousView: null,
  setView: (view) => set({ previousView: get().currentView, currentView: view }),
  goBack: () => {
    const prev = get().previousView
    if (prev) set({ currentView: prev, previousView: null })
  },

  // Auth
  user: null,
  setUser: (user) => set({ 
    user, 
    isAuthenticated: !!user,
    currentView: user ? 'dashboard' : 'landing'
  }),
  isAuthenticated: false,

  // Auth form state
  authMode: 'signup',
  setAuthMode: (mode) => set({ authMode: mode }),

  // Task management
  tasksUpdated: 0,
  triggerTasksUpdate: () => set((state) => ({ tasksUpdated: state.tasksUpdated + 1 })),

  // Tenant management
  currentTenantId: null,
  setCurrentTenantId: (id) => set({ currentTenantId: id }),

  // Live data
  liveTelemetry: {},
  setLiveTelemetry: (data) => set({ liveTelemetry: data }),

  // WebSocket connection state
  wsConnected: false,
  setWsConnected: (connected) => set({ wsConnected: connected }),
}))
