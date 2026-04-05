/**
 * Auth Validation Utility for CBUP API Routes
 *
 * Provides authentication/authorization checks for admin-only endpoints.
 * Uses a simplified token-based auth model:
 *   1. X-Admin-Token header matching CBUP_ADMIN_TOKEN env var
 *   2. Authorization: Bearer <token> header
 *   3. Valid session cookie (cbup_session)
 *
 * The CBUP_ADMIN_TOKEN defaults to a cryptographically random value
 * generated at server startup if not set via environment.
 */

import { NextRequest, NextResponse } from 'next/server'
import { randomBytes } from 'crypto'

// ─── Generate persistent admin token if not set ──────────────────────────────
// This token is generated once per process and stored in process.env
// In production, set CBUP_ADMIN_TOKEN env var to a known value
if (!process.env.CBUP_ADMIN_TOKEN) {
  process.env.CBUP_ADMIN_TOKEN = randomBytes(32).toString('hex')
  console.warn(
    '[CBUP SECURITY] No CBUP_ADMIN_TOKEN env var set. Generated a random token for this session.\n' +
    '[CBUP SECURITY] Set CBUP_ADMIN_TOKEN env var for persistent admin authentication.\n' +
    `[CBUP SECURITY] Current token: ${process.env.CBUP_ADMIN_TOKEN.slice(0, 8)}... (first 8 chars for debug only)`
  )
}

const ADMIN_TOKEN = process.env.CBUP_ADMIN_TOKEN

/**
 * Validates session/auth token from a request.
 * Checks in order:
 *   1. X-Admin-Token header
 *   2. Authorization: Bearer <token> header
 *   3. cbup_session cookie
 *
 * Returns true if the request is authenticated, false otherwise.
 */
export function validateSessionToken(request: NextRequest): boolean {
  // Check X-Admin-Token header (primary admin auth)
  const adminToken = request.headers.get('x-admin-token')
  if (adminToken && adminToken === ADMIN_TOKEN) {
    return true
  }

  // Check Authorization: Bearer <token> header
  const authHeader = request.headers.get('authorization')
  if (authHeader) {
    const match = authHeader.match(/^Bearer\s+(.+)$/i)
    if (match) {
      const token = match[1].trim()
      if (token === ADMIN_TOKEN) {
        return true
      }
      // Future: check against stored session tokens in database
    }
  }

  // Check cbup_session cookie
  const sessionCookie = request.cookies.get('cbup_session')
  if (sessionCookie && sessionCookie.value === ADMIN_TOKEN) {
    return true
  }

  return false
}

/**
 * Requires authentication for a request.
 * Throws a 401 response if the request is not authenticated.
 * Use at the top of admin-only route handlers.
 *
 * Usage:
 *   export async function POST(request: NextRequest) {
 *     requireAuth(request)
 *     // ... your handler logic
 *   }
 */
export function requireAuth(request: NextRequest): void {
  if (!validateSessionToken(request)) {
    throw new AuthError('Authentication required. Provide a valid X-Admin-Token header.')
  }
}

/**
 * Custom error class for authentication failures.
 * Route handlers should catch this and return a 401 response.
 */
export class AuthError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'AuthError'
  }
}

/**
 * Creates a standard 401 Unauthorized response.
 */
export function unauthorizedResponse(message = 'Authentication required'): NextResponse {
  return NextResponse.json(
    { success: false, error: message },
    {
      status: 401,
      headers: {
        'WWW-Authenticate': 'Bearer',
      },
    }
  )
}

/**
 * Middleware-style wrapper: validates auth and returns null if OK,
 * or a 401 NextResponse if auth fails.
 *
 * Usage:
 *   const authFail = checkAuth(request)
 *   if (authFail) return authFail
 *   // ... proceed with handler
 */
export function checkAuth(request: NextRequest): NextResponse | null {
  if (!validateSessionToken(request)) {
    return unauthorizedResponse()
  }
  return null
}
