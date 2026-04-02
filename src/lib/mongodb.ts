/**
 * MongoDB adapter for Cyber Brief Unified Platform
 *
 * Implements the same CRUD interface as PrismaClient for all 4 models:
 * User, Alert, Brief, Task
 *
 * Uses the native mongodb driver (no mongoose dependency).
 */

import { MongoClient, Db, ObjectId, Filter, Document } from 'mongodb'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface UserRecord {
  _id?: ObjectId
  id: string
  email: string
  name: string | null
  company: string | null
  tier: string
  password: string | null
  createdAt: Date
  updatedAt: Date
}

interface AlertRecord {
  _id?: ObjectId
  id: string
  title: string
  severity: string
  source: string
  description: string
  category: string
  createdAt: Date
}

interface BriefRecord {
  _id?: ObjectId
  id: string
  title: string
  volume: number
  content: string
  publishedAt: Date
}

interface TaskRecord {
  _id?: ObjectId
  id: string
  title: string
  description: string | null
  status: string
  priority: string
  assignee: string | null
  dueDate: Date | null
  createdAt: Date
  updatedAt: Date
}

type AnyRecord = UserRecord | AlertRecord | BriefRecord | TaskRecord

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function stripMongoId<T extends AnyRecord>(doc: WithId<T> | null): T | null {
  if (!doc) return null
  const { _id, ...rest } = doc
  return rest as T
}

function stripMongoIds<T extends AnyRecord>(docs: WithId<T>[]): T[] {
  return docs.map(stripMongoId).filter(Boolean) as T[]
}

type WithId<T> = T & { _id: ObjectId }

/** Convert a Prisma-style `where` filter + `orderBy` + `take` to MongoDB query/sort/limit */
function buildMongoQuery(args: Record<string, unknown>) {
  const filter: Filter<Document> = {}
  const sort: Record<string, 1 | -1> = {}
  let limit = 0

  if (args.where && typeof args.where === 'object') {
    const w = args.where as Record<string, unknown>
    for (const [key, val] of Object.entries(w)) {
      if (val !== undefined && val !== null) {
        filter[key] = val as unknown
      }
    }
  }

  if (args.orderBy && typeof args.orderBy === 'object') {
    const o = args.orderBy as Record<string, string>
    for (const [key, dir] of Object.entries(o)) {
      sort[key] = dir === 'desc' ? -1 : 1
    }
  }

  if (typeof args.take === 'number') {
    limit = args.take
  }

  return { filter, sort, limit }
}

/** Build MongoDB update from Prisma-style `data` (omit id) */
function buildUpdate(data: Record<string, unknown>) {
  const updateFields: Record<string, unknown> = { ...data }
  delete updateFields.id
  return updateFields
}

// ---------------------------------------------------------------------------
// Collection-level adapter
// ---------------------------------------------------------------------------

type ModelMethods<T extends AnyRecord> = {
  findMany(args?: Record<string, unknown>): Promise<T[]>
  findFirst(args?: Record<string, unknown>): Promise<T | null>
  findUnique(args: { where: Record<string, unknown> }): Promise<T | null>
  create(args: { data: Record<string, unknown> }): Promise<T>
  update(args: { where: Record<string, unknown>; data: Record<string, unknown> }): Promise<T>
  delete(args: { where: Record<string, unknown> }): Promise<T>
  count(args?: { where?: Record<string, unknown> }): Promise<number>
}

function createModelAdapter<T extends AnyRecord>(collectionName: string): ModelMethods<T> {
  return {
    async findMany(args = {}) {
      const db = await getMongoDb()
      const { filter, sort, limit } = buildMongoQuery(args)
      let cursor = db.collection(collectionName).find(filter).sort(sort)
      if (limit > 0) cursor = cursor.limit(limit)
      return stripMongoIds<T>(await cursor.toArray() as WithId<T>[])
    },

    async findFirst(args = {}) {
      const db = await getMongoDb()
      const { filter, sort } = buildMongoQuery(args)
      const doc = await db.collection(collectionName).findOne(filter, { sort })
      return stripMongoId<T>(doc as WithId<T> | null)
    },

    async findUnique(args: { where: Record<string, unknown> }) {
      const db = await getMongoDb()
      const doc = await db.collection(collectionName).findOne(args.where as Filter<Document>)
      return stripMongoId<T>(doc as WithId<T> | null)
    },

    async create(args: { data: Record<string, unknown> }) {
      const db = await getMongoDb()
      const now = new Date()
      const record = {
        ...buildUpdate(args.data),
        createdAt: now,
        updatedAt: now,
      } as unknown as Document
      const result = await db.collection(collectionName).insertOne(record)
      return { ...args.data, createdAt: now, updatedAt: now, _id: result.insertedId } as unknown as T
    },

    async update(args: { where: Record<string, unknown>; data: Record<string, unknown> }) {
      const db = await getMongoDb()
      const updateFields = buildUpdate(args.data)
      updateFields.updatedAt = new Date()
      await db.collection(collectionName).updateOne(args.where as Filter<Document>, { $set: updateFields })
      const doc = await db.collection(collectionName).findOne(args.where as Filter<Document>)
      if (!doc) throw new Error(`Record not found in ${collectionName}`)
      return stripMongoId<T>(doc as WithId<T>)!
    },

    async delete(args: { where: Record<string, unknown> }) {
      const db = await getMongoDb()
      const doc = await db.collection(collectionName).findOne(args.where as Filter<Document>)
      if (!doc) throw new Error(`Record not found in ${collectionName}`)
      await db.collection(collectionName).deleteOne(args.where as Filter<Document>)
      return stripMongoId<T>(doc as WithId<T>)!
    },

    async count(args = {}) {
      const db = await getMongoDb()
      const filter = (args.where && typeof args.where === 'object')
        ? (args.where as Filter<Document>)
        : {}
      return db.collection(collectionName).countDocuments(filter)
    },
  }
}

// ---------------------------------------------------------------------------
// Connection management
// ---------------------------------------------------------------------------

let client: MongoClient | null = null
let dbInstance: Db | null = null

export async function getMongoDb(): Promise<Db> {
  if (dbInstance) return dbInstance

  const url = process.env.MONGODB_URL || process.env.DATABASE_URL || 'mongodb://localhost:27017/cbup'

  client = new MongoClient(url)
  await client.connect()

  // Extract DB name from URL
  const urlObj = new URL(url)
  const dbName = urlObj.pathname.slice(1) || 'cbup'
  dbInstance = client.db(dbName)

  return dbInstance
}

export async function disconnectMongo(): Promise<void> {
  if (client) {
    await client.close()
    client = null
    dbInstance = null
  }
}

export async function getMongoStatus(): Promise<{
  connected: boolean
  collections: string[]
  counts: Record<string, number>
}> {
  try {
    const db = await getMongoDb()
    const collections = await db.listCollections().toArray()
    const collectionNames = collections.map(c => c.name)
    const counts: Record<string, number> = {}

    for (const name of collectionNames) {
      counts[name] = await db.collection(name).countDocuments()
    }

    return { connected: true, collections: collectionNames, counts }
  } catch {
    return { connected: false, collections: [], counts: {} }
  }
}

// ---------------------------------------------------------------------------
// Public API – matches Prisma's db.user / db.alert / db.brief / db.task shape
// ---------------------------------------------------------------------------

export function createMongoAdapter() {
  return {
    user: createModelAdapter<UserRecord>('users'),
    alert: createModelAdapter<AlertRecord>('alerts'),
    brief: createModelAdapter<BriefRecord>('briefs'),
    task: createModelAdapter<TaskRecord>('tasks'),
  }
}
