/**
 * Unified database provider for Cyber Brief Unified Platform (v0.3.0)
 *
 * Supports: sqlite, mysql, postgresql (via Prisma) and mongodb (native driver)
 *
 * Environment variables:
 *   DATABASE_PROVIDER  - "sqlite" | "mysql" | "postgresql" | "mongodb"
 *   DATABASE_URL       - connection string (Prisma databases)
 *   MONGODB_URL        - MongoDB connection string (fallback to DATABASE_URL)
 */

import { createMongoAdapter, getMongoStatus } from './mongodb'

// ---------------------------------------------------------------------------
// Provider type
// ---------------------------------------------------------------------------

export type DatabaseProvider = 'sqlite' | 'mysql' | 'postgresql' | 'mongodb'

function resolveProvider(): DatabaseProvider {
  const env = (process.env.DATABASE_PROVIDER || 'sqlite').toLowerCase().trim()
  const valid: DatabaseProvider[] = ['sqlite', 'mysql', 'postgresql', 'mongodb']
  if (!valid.includes(env as DatabaseProvider)) {
    console.warn(
      `[db-provider] Unknown DATABASE_PROVIDER="${env}", falling back to "sqlite". Valid: ${valid.join(', ')}`
    )
    return 'sqlite'
  }
  return env as DatabaseProvider
}

const _provider: DatabaseProvider = resolveProvider()

// ---------------------------------------------------------------------------
// Public helpers
// ---------------------------------------------------------------------------

/** Returns the current database provider identifier. */
export function getProvider(): DatabaseProvider {
  return _provider
}

/** Returns a human-readable label for the current provider. */
export function getProviderDisplay(): string {
  const map: Record<DatabaseProvider, string> = {
    sqlite: 'SQLite',
    mysql: 'MySQL',
    postgresql: 'PostgreSQL',
    mongodb: 'MongoDB',
  }
  return map[_provider]
}

// ---------------------------------------------------------------------------
// Lazy initialisation – we only import the heavy Prisma client when needed
// ---------------------------------------------------------------------------

let _db: ReturnType<typeof buildDb> | null = null

function buildDb() {
  if (_provider === 'mongodb') {
    return createMongoAdapter()
  }

  // sqlite / mysql / postgresql → Prisma
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { PrismaClient } = require('@prisma/client')

  const globalForPrisma = globalThis as unknown as {
    prisma: InstanceType<typeof PrismaClient> | undefined
  }

  const prisma =
    globalForPrisma.prisma ??
    new PrismaClient({
      log: process.env.NODE_ENV === 'development' ? ['query'] : [],
    })

  if (process.env.NODE_ENV !== 'production') {
    globalForPrisma.prisma = prisma
  }

  return prisma
}

/**
 * The unified `db` object.
 *
 * For Prisma providers (sqlite/mysql/postgresql) this IS the PrismaClient instance,
 * so all existing code using `db.user.findMany(...)` etc. continues to work.
 *
 * For MongoDB this is the adapter created by `createMongoAdapter()` which exposes
 * the same `.user`, `.alert`, `.brief`, `.task` model handles with compatible APIs.
 */
export function getDb() {
  if (!_db) {
    _db = buildDb()
  }
  return _db
}

// Keep a default export for the common `import { db } from '@/lib/db'` pattern
export const db = new Proxy({} as ReturnType<typeof getDb>, {
  get(_target, prop, receiver) {
    const instance = getDb()
    const value = Reflect.get(instance, prop as string, receiver)
    // Bind methods so `this` is correct
    return typeof value === 'function' ? value.bind(instance) : value
  },
})

// ---------------------------------------------------------------------------
// Status helpers (used by /api/db-status)
// ---------------------------------------------------------------------------

export type DbStatus = {
  provider: DatabaseProvider
  display: string
  connected: boolean
  tables: string[]
  counts: Record<string, number>
}

export async function getDbStatus(): Promise<DbStatus> {
  const provider = getProvider()
  const display = getProviderDisplay()
  const tables = ['users', 'alerts', 'briefs', 'tasks']

  if (provider === 'mongodb') {
    const mongoStatus = await getMongoStatus()
    return {
      provider,
      display,
      connected: mongoStatus.connected,
      tables: mongoStatus.collections.length > 0 ? mongoStatus.collections : tables,
      counts: mongoStatus.counts,
    }
  }

  // Prisma-based providers
  try {
    const instance = getDb() as Record<string, unknown>
    const modelNames = ['user', 'alert', 'brief', 'task']
    const counts: Record<string, number> = {}

    for (const name of modelNames) {
      const model = instance[name] as Record<string, (...args: unknown[]) => Promise<unknown>>
      if (model && typeof model.count === 'function') {
        counts[name + 's'] = (await model.count()) as number
      }
    }

    return {
      provider,
      display,
      connected: true,
      tables,
      counts,
    }
  } catch (error) {
    console.error('[db-provider] Status check failed:', error)
    return {
      provider,
      display,
      connected: false,
      tables,
      counts: {},
    }
  }
}
