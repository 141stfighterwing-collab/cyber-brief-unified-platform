/**
 * Database client for Cyber Brief Unified Platform (v0.3.0)
 *
 * This module re-exports the unified `db` object from db-provider.
 * All API routes should continue to `import { db } from '@/lib/db'`.
 *
 * The actual database backend is selected via DATABASE_PROVIDER env var:
 *   - "sqlite"      (default)
 *   - "mysql"
 *   - "postgresql"
 *   - "mongodb"
 */

export { db, getDb, getProvider, getProviderDisplay, getDbStatus } from './db-provider'

export type { DatabaseProvider, DbStatus } from './db-provider'
