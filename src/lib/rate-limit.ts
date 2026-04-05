/**
 * Rate Limiting Utility for CBUP API Routes
 *
 * In-memory sliding-window rate limiter using a Map.
 * Per-IP tracking with configurable maxRequests per windowMs.
 * No external dependencies required.
 *
 * Usage:
 *   import { rateLimit, authRateLimit } from '@/lib/rate-limit'
 *   const limited = rateLimit({ maxRequests: 100, windowMs: 60000 })
 *   const result = limited.check(clientIp)
 *   if (!result.allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 })
 */

import { NextResponse } from 'next/server'

interface RateLimitEntry {
  timestamps: number[]
}

export interface RateLimitOptions {
  maxRequests: number
  windowMs: number
}

export interface RateLimitResult {
  allowed: boolean
  remaining: number
  resetMs: number
}

export interface RateLimiter {
  check: (ip: string) => RateLimitResult
}

// ─── Cleanup interval ────────────────────────────────────────────────────────
// Periodically purge stale entries to prevent memory leaks
const CLEANUP_INTERVAL_MS = 5 * 60 * 1000 // 5 minutes

const store = new Map<string, RateLimitEntry>()

setInterval(() => {
  const now = Date.now()
  for (const [ip, entry] of store) {
    // Remove timestamps outside any reasonable window (24h max)
    entry.timestamps = entry.timestamps.filter((t) => now - t < 24 * 60 * 60 * 1000)
    if (entry.timestamps.length === 0) {
      store.delete(ip)
    }
  }
}, CLEANUP_INTERVAL_MS)

/**
 * Creates a rate limiter instance with the given options.
 * Uses a sliding window algorithm: track timestamps of all requests
 * within the window, reject when count exceeds maxRequests.
 */
export function rateLimit(options: RateLimitOptions): RateLimiter {
  const { maxRequests, windowMs } = options

  return {
    check(ip: string): RateLimitResult {
      const now = Date.now()
      const windowStart = now - windowMs

      let entry = store.get(ip)
      if (!entry) {
        entry = { timestamps: [] }
        store.set(ip, entry)
      }

      // Prune timestamps outside the current window
      entry.timestamps = entry.timestamps.filter((t) => t > windowStart)

      const remaining = Math.max(0, maxRequests - entry.timestamps.length)
      const allowed = entry.timestamps.length < maxRequests

      if (allowed) {
        entry.timestamps.push(now)
      }

      // Calculate when the oldest request in the window will expire
      const resetMs = entry.timestamps.length > 0
        ? Math.max(0, entry.timestamps[0] - windowStart + 1) // +1 to ensure the slot is freed
        : 0

      return { allowed, remaining, resetMs }
    },
  }
}

// ─── Default limiters ─────────────────────────────────────────────────────────

/** Standard rate limiter: 100 requests per 60 seconds per IP */
export const defaultRateLimit = rateLimit({ maxRequests: 100, windowMs: 60 * 1000 })

/** Auth routes rate limiter: 10 requests per 60 seconds per IP */
export const authRateLimit = rateLimit({ maxRequests: 10, windowMs: 60 * 1000 })

/**
 * Helper to extract client IP from a NextRequest.
 * Checks X-Forwarded-For, X-Real-IP, and falls back to remoteAddress.
 */
export function getClientIp(request: Request): string {
  const forwarded = request.headers.get('x-forwarded-for')
  if (forwarded) {
    return forwarded.split(',')[0].trim()
  }
  const realIp = request.headers.get('x-real-ip')
  if (realIp) {
    return realIp.trim()
  }
  return 'unknown'
}

/**
 * Creates a standard 429 Too Many Requests response.
 */
export function rateLimitResponse(result: RateLimitResult): NextResponse {
  return NextResponse.json(
    {
      success: false,
      error: 'Too many requests. Please try again later.',
      retryAfterMs: result.resetMs,
    },
    {
      status: 429,
      headers: {
        'Retry-After': String(Math.ceil(result.resetMs / 1000)),
        'X-RateLimit-Remaining': '0',
      },
    }
  )
}
