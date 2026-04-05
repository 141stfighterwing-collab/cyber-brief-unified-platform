import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { randomBytes, scryptSync } from 'crypto'
import { rateLimit, getClientIp, rateLimitResponse } from '@/lib/rate-limit'

// ─── Password Hashing ────────────────────────────────────────────────────────
// Uses Node.js crypto.scryptSync for password hashing (no external dependencies).
// Format: salt:hash (both hex-encoded)

const SCRYPT_KEY_LENGTH = 64
const SALT_LENGTH = 16

function hashPassword(password: string): string {
  const salt = randomBytes(SALT_LENGTH).toString('hex')
  const hash = scryptSync(password, salt, SCRYPT_KEY_LENGTH).toString('hex')
  return `${salt}:${hash}`
}

function verifyPassword(password: string, stored: string | null): boolean {
  if (!stored) return false

  if (stored.includes(':')) {
    const [salt, hash] = stored.split(':', 2)
    if (!salt || !hash) return false
    const verifyHash = scryptSync(password, salt, SCRYPT_KEY_LENGTH).toString('hex')
    return hash === verifyHash
  }

  // Legacy plaintext format
  console.warn('[CBUP SECURITY] Verifying against plaintext password (legacy user). Consider rehashing.')
  return password === stored
}

// ─── Default Super Admin ─────────────────────────────────────────────────────
// Auto-created on first login if no admin exists in the database.
// This ensures the platform is always accessible after a fresh deploy.

const DEFAULT_ADMIN_EMAIL = 'admin@cbup.io'
const DEFAULT_ADMIN_PASSWORD = 'CBUPadmin2024!'
const DEFAULT_ADMIN_NAME = 'Platform Admin'
const DEFAULT_ADMIN_ROLE = 'super_admin'
const DEFAULT_ADMIN_TIER = 'enterprise'

let adminAutoCreated = false

async function ensureDefaultAdmin(): Promise<void> {
  if (adminAutoCreated) return

  try {
    const existing = await db.user.findUnique({ where: { email: DEFAULT_ADMIN_EMAIL } })
    if (existing) {
      // If admin exists but has no password, hash the default one
      if (!existing.password) {
        const hashed = hashPassword(DEFAULT_ADMIN_PASSWORD)
        await db.user.update({
          where: { id: existing.id },
          data: { password: hashed },
        })
        console.log(`[CBUP AUTH] Set default admin password for: ${DEFAULT_ADMIN_EMAIL}`)
      }
      adminAutoCreated = true
      return
    }

    // Create the default admin with hashed password
    const hashedPassword = hashPassword(DEFAULT_ADMIN_PASSWORD)
    await db.user.create({
      data: {
        email: DEFAULT_ADMIN_EMAIL,
        name: DEFAULT_ADMIN_NAME,
        company: 'Cyber Brief Unified Platform',
        role: DEFAULT_ADMIN_ROLE,
        tier: DEFAULT_ADMIN_TIER,
        password: hashedPassword,
        settings: JSON.stringify({ theme: 'dark', notifications: true, language: 'en' }),
      },
    })
    console.log(`[CBUP AUTH] Auto-created default super admin: ${DEFAULT_ADMIN_EMAIL}`)
    adminAutoCreated = true
  } catch (error) {
    // If auto-creation fails (e.g., race condition), log and continue
    console.warn('[CBUP AUTH] Could not auto-create admin (may already exist):', error)
    adminAutoCreated = true // Don't retry
  }
}

// ─── Rate Limiting ───────────────────────────────────────────────────────────
// 5 signups per minute per IP
const signupRateLimit = rateLimit({ maxRequests: 5, windowMs: 60 * 1000 })

// ─── Validation ──────────────────────────────────────────────────────────────
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export async function POST(request: NextRequest) {
  try {
    // ─── Rate Limiting ───────────────────────────────────────────────────
    const clientIp = getClientIp(request)
    const rlResult = signupRateLimit.check(clientIp)
    if (!rlResult.allowed) {
      return rateLimitResponse(rlResult)
    }

    // ─── Ensure default admin exists (auto-seed) ─────────────────────────
    await ensureDefaultAdmin()

    const body = await request.json()
    const { email, name, company, password, tier, action } = body

    if (!email) {
      return NextResponse.json({ error: 'Email is required' }, { status: 400 })
    }

    // ─── Email Validation ────────────────────────────────────────────────
    if (!EMAIL_REGEX.test(email)) {
      return NextResponse.json({ error: 'Invalid email format' }, { status: 400 })
    }

    // ─── Password Strength Validation ────────────────────────────────────
    if (password) {
      if (password.length < 8) {
        return NextResponse.json({ error: 'Password must be at least 8 characters' }, { status: 400 })
      }
      if (!/[a-zA-Z]/.test(password) || !/[0-9]/.test(password)) {
        return NextResponse.json({ error: 'Password must contain at least one letter and one number' }, { status: 400 })
      }
    }

    // ─── Determine intent ────────────────────────────────────────────────
    const isExplicitLogin = action === 'login'

    // Check if user already exists
    const existing = await db.user.findUnique({ where: { email } })

    if (existing) {
      // ─── LOGIN FLOW (existing user) ────────────────────────────────────
      // Case 1: User has NO password set — allow first-login password set
      if (!existing.password) {
        if (password) {
          const hashed = hashPassword(password)
          await db.user.update({
            where: { id: existing.id },
            data: { password: hashed },
          })
          console.log(`[CBUP AUTH] First-login password set for: ${existing.email}`)
        }
        return NextResponse.json({
          id: existing.id,
          email: existing.email,
          name: existing.name,
          company: existing.company,
          tier: existing.tier,
          role: existing.role,
          firstLogin: !password,
        })
      }

      // Case 2: User HAS a hashed password — verify it
      if (password) {
        const valid = verifyPassword(password, existing.password)
        if (!valid) {
          console.warn(`[CBUP AUTH] Failed login attempt for: ${existing.email} from IP ${clientIp}`)
          return NextResponse.json({ error: 'Invalid email or password' }, { status: 401 })
        }

        // Auto-migrate legacy plaintext passwords
        if (existing.password && !existing.password.includes(':')) {
          const hashed = hashPassword(password)
          await db.user.update({
            where: { id: existing.id },
            data: { password: hashed },
          })
          console.log(`[CBUP SECURITY] Auto-migrated plaintext password to scrypt for: ${existing.email}`)
        }
      } else {
        return NextResponse.json({ error: 'Password is required' }, { status: 400 })
      }

      return NextResponse.json({
        id: existing.id,
        email: existing.email,
        name: existing.name,
        company: existing.company,
        tier: existing.tier,
        role: existing.role,
      })
    }

    // ─── SIGNUP FLOW (new user) ──────────────────────────────────────────
    if (isExplicitLogin) {
      console.warn(`[CBUP AUTH] Login attempt for non-existent user: ${email} from IP ${clientIp}`)
      return NextResponse.json({ error: 'No account found with this email' }, { status: 404 })
    }

    // Create new user
    const hashedPassword = password ? hashPassword(password) : null

    const user = await db.user.create({
      data: {
        email,
        name: name || null,
        company: company || null,
        tier: tier || 'free',
        password: hashedPassword,
        role: 'user',
      },
    })

    return NextResponse.json({
      id: user.id,
      email: user.email,
      name: user.name,
      company: user.company,
      tier: user.tier,
      role: user.role,
      firstLogin: !hashedPassword,
    })
  } catch (error) {
    console.error('Auth error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
