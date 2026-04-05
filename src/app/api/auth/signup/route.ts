import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import { randomBytes, scryptSync } from 'crypto'
import { rateLimit, getClientIp, rateLimitResponse } from '@/lib/rate-limit'

// ─── Password Hashing ────────────────────────────────────────────────────────
// Uses Node.js crypto.scryptSync for password hashing (no external dependencies).
// Format: salt:hash (both hex-encoded)

const SCRYPT_KEY_LENGTH = 64
const SALT_LENGTH = 16

/**
 * Hash a password using scrypt with a random salt.
 * Returns hex-encoded "salt:hash" string for storage.
 */
function hashPassword(password: string): string {
  const salt = randomBytes(SALT_LENGTH).toString('hex')
  const hash = scryptSync(password, salt, SCRYPT_KEY_LENGTH).toString('hex')
  return `${salt}:${hash}`
}

/**
 * Verify a password against a stored salt:hash string.
 * Returns true if the password matches.
 * Handles backward compatibility: if stored value has no ":", it was plaintext.
 */
function verifyPassword(password: string, stored: string | null): boolean {
  if (!stored) return false

  if (stored.includes(':')) {
    // Hashed format: salt:hash
    const [salt, hash] = stored.split(':', 2)
    if (!salt || !hash) return false
    const verifyHash = scryptSync(password, salt, SCRYPT_KEY_LENGTH).toString('hex')
    return hash === verifyHash
  }

  // Legacy plaintext format: direct comparison
  // (existing users who signed up before hashing was added)
  console.warn('[CBUP SECURITY] Verifying against plaintext password (legacy user). Consider rehashing.')
  return password === stored
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

    const body = await request.json()
    const { email, name, company, password, tier } = body

    if (!email) {
      return NextResponse.json({ error: 'Email is required' }, { status: 400 })
    }

    // ─── Email Validation ────────────────────────────────────────────────
    if (!EMAIL_REGEX.test(email)) {
      return NextResponse.json({ error: 'Invalid email format' }, { status: 400 })
    }

    // ─── Password Strength Validation (for new users) ────────────────────
    if (password) {
      if (password.length < 8) {
        return NextResponse.json({ error: 'Password must be at least 8 characters' }, { status: 400 })
      }
      if (!/[a-zA-Z]/.test(password) || !/[0-9]/.test(password)) {
        return NextResponse.json({ error: 'Password must contain at least one letter and one number' }, { status: 400 })
      }
    }

    // Check if user already exists → login flow
    const existing = await db.user.findUnique({ where: { email } })
    if (existing) {
      // For existing users, if they provide a password, verify it (login flow)
      if (password) {
        if (!verifyPassword(password, existing.password)) {
          return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 })
        }
      }
      // Return user data (existing login flow preserved)
      return NextResponse.json({
        id: existing.id,
        email: existing.email,
        name: existing.name,
        company: existing.company,
        tier: existing.tier,
        role: existing.role,
      })
    }

    // Create new user — hash the password before storage
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
    })
  } catch (error) {
    console.error('Auth error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
