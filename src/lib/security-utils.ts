/**
 * Timing-Safe Security Utilities for CBUP API Routes
 *
 * Provides constant-time string comparison to prevent timing attacks
 * on authentication tokens, API keys, and secrets.
 *
 * IMPORTANT: Never use === or !== for comparing security-sensitive values.
 * Always use timingSafeEqual() instead.
 */

import { timingSafeEqual } from 'crypto'

/**
 * Constant-time string comparison for security-sensitive values.
 * Prevents timing attacks that could leak token/key information.
 *
 * Returns true if both strings are equal, false otherwise.
 * Returns false immediately if either value is empty/null/undefined.
 */
export function safeEqual(a: string | null | undefined, b: string | null | undefined): boolean {
  if (!a || !b) return false
  if (a.length !== b.length) return false

  try {
    return timingSafeEqual(Buffer.from(a, 'utf-8'), Buffer.from(b, 'utf-8'))
  } catch {
    return false
  }
}

/**
 * Hashes an auth token for secure storage using SHA-256.
 * The token itself is never stored — only the hash.
 * This way, even if the database is compromised, tokens are not exposed.
 *
 * Format: "sha256:<hex_hash>"
 */
export function hashToken(token: string): string {
  const { createHash } = require('crypto')
  const hash = createHash('sha256').update(token).digest('hex')
  return `sha256:${hash}`
}

/**
 * Verifies a plaintext token against a stored hash.
 * Supports both "sha256:<hex>" format and legacy plaintext comparison.
 */
export function verifyTokenHash(plaintext: string, stored: string | null): boolean {
  if (!stored || !plaintext) return false

  if (stored.startsWith('sha256:')) {
    return safeEqual(hashToken(plaintext), stored)
  }

  // Legacy: plaintext comparison (should be migrated)
  return safeEqual(plaintext, stored)
}
