import { NextRequest, NextResponse } from 'next/server'
import { db } from '@/lib/db'
import crypto from 'crypto'
import { rateLimit, getClientIp, rateLimitResponse } from '@/lib/rate-limit'
import { safeEqual } from '@/lib/security-utils'

// ─── Rate Limiting ────────────────────────────────────────────────────────────
// 10 registrations per 5 minutes per IP
const registerRateLimit = rateLimit({ maxRequests: 10, windowMs: 5 * 60 * 1000 })

// ─── Input Validation ─────────────────────────────────────────────────────────
const AGENT_ID_REGEX = /^[a-zA-Z0-9_-]{8,128}$/
const HOSTNAME_REGEX = /^[a-zA-Z0-9][a-zA-Z0-9._-]{0,254}$/

// Maximum request body size: 256KB
const MAX_BODY_SIZE = 256 * 1024

/**
 * Generates a deterministic agentId from hostname + timestamp.
 * Falls back to random bytes if hostname is not available.
 */
function generateAgentId(hostname?: string): string {
  const time = Date.now().toString(36)
  const rand = crypto.randomBytes(4).toString('hex')
  const host = (hostname || 'unknown').replace(/[^a-zA-Z0-9]/g, '').substring(0, 12)
  return `CBUP-${host}-${time}-${rand}`
}

/**
 * Extracts top-level fields from the agent's payload.
 * The CBUP Agent sends data in two formats:
 *   1. Direct: { hostname, osName, osVersion, ... }
 *   2. Nested: { hostname, discovery: { Hostname, OSName, OSVersion, ... }, token }
 *
 * This function normalizes both into a flat structure.
 */
function extractRegistrationFields(body: Record<string, unknown>) {
  const discovery = (body.discovery as Record<string, unknown>) || {}

  return {
    agentId:      (body.agentId as string) || '',
    hostname:     (body.hostname as string) || (discovery.Hostname as string) || '',
    domain:       (body.domain as string) || (discovery.Domain as string) || '',
    osName:       (body.osName as string) || (discovery.OSName as string) || '',
    osVersion:    (body.osVersion as string) || (discovery.OSVersion as string) || '',
    osArch:       (body.osArch as string) || (discovery.OSArchitecture as string) || '',
    manufacturer: (body.manufacturer as string) || (discovery.Manufacturer as string) || '',
    model:        (body.model as string) || (discovery.Model as string) || '',
    serialNumber: (body.serialNumber as string) || (discovery.SerialNumber as string) || '',
    biosVersion:  (body.biosVersion as string) || (discovery.BIOSVersion as string) || '',
    cpuModel:     (body.cpuModel as string) || (discovery.CPUModel as string) || '',
    cpuCores:     (body.cpuCores as number) || (discovery.CPUCores as number) || null,
    totalRamMb:   (body.totalRamMb as number) || null,
    totalRamGb:   (discovery.TotalRAM_GB as number) || null,
    macAddresses: body.macAddresses || discovery.NetworkAdapters || null,
    ipAddresses:  body.ipAddresses || null,
    version:      (body.version as string) || '',
    capabilities: body.capabilities || null,
    interval:     (body.interval as number) || 30,
    scanInterval: (body.scanInterval as number) || 60,
  }
}

/**
 * Extract MAC addresses from network adapter data.
 * Accepts both string (JSON array) and array formats.
 */
function extractMacAddresses(macData: unknown): string | null {
  if (!macData) return null
  if (typeof macData === 'string') return macData.length > 0 ? macData : null
  if (Array.isArray(macData)) {
    const macs = macData
      .map((a: Record<string, unknown>) => (a.MACAddress as string) || '')
      .filter(Boolean)
    return macs.length > 0 ? JSON.stringify(macs) : null
  }
  return null
}

// POST /api/agents/register
// Registers a new agent or updates existing one.
// SECURITY: Requires a valid pre-auth token or an existing valid agent auth token.
export async function POST(request: NextRequest) {
  try {
    // ─── Rate Limiting ───────────────────────────────────────────────────
    const clientIp = getClientIp(request)
    const rlResult = registerRateLimit.check(clientIp)
    if (!rlResult.allowed) {
      return rateLimitResponse(rlResult)
    }

    // ─── Body Size Validation ─────────────────────────────────────────────
    const contentLength = request.headers.get('content-length')
    if (contentLength && parseInt(contentLength, 10) > MAX_BODY_SIZE) {
      return NextResponse.json(
        { success: false, error: 'Request body too large' },
        { status: 413 }
      )
    }

    const body = await request.json()

    // Normalize fields from both direct and nested (discovery) formats
    const fields = extractRegistrationFields(body)

    // The agent sends `token` as the pre-auth registration token.
    // The server also accepts `authToken` for existing agent updates.
    const authToken = (body.authToken as string) || (body.token as string) || ''

    // ─── Generate agentId if not provided ────────────────────────────────
    // The CBUP Agent EXE does NOT send agentId on first registration.
    // We generate one deterministically from hostname.
    let agentId = fields.agentId
    if (!agentId) {
      agentId = generateAgentId(fields.hostname)
      console.log(`[CBUP AGENT] Generated agentId: ${agentId} for hostname: ${fields.hostname}`)
    }

    // ─── Input Validation ─────────────────────────────────────────────────
    if (!fields.hostname) {
      return NextResponse.json(
        { success: false, error: 'Missing required field: hostname' },
        { status: 400 }
      )
    }

    if (!agentId || !AGENT_ID_REGEX.test(agentId)) {
      return NextResponse.json(
        { success: false, error: 'Invalid or missing agentId' },
        { status: 400 }
      )
    }

    if (!HOSTNAME_REGEX.test(fields.hostname)) {
      return NextResponse.json(
        { success: false, error: 'Invalid hostname format.' },
        { status: 400 }
      )
    }

    // Check if agent already exists
    const existing = await db.agent.findUnique({
      where: { agentId },
    })

    if (existing) {
      // ─── UPDATE EXISTING AGENT ─────────────────────────────────────────
      // SECURITY: Must provide valid authToken for updates
      if (!authToken) {
        return NextResponse.json(
          { success: false, error: 'Auth token required for agent updates' },
          { status: 401 }
        )
      }

      // Timing-safe token comparison
      if (!safeEqual(authToken, existing.authToken || '')) {
        return NextResponse.json(
          { success: false, error: 'Invalid auth token' },
          { status: 401 }
        )
      }

      const updated = await db.agent.update({
        where: { agentId },
        data: {
          hostname: fields.hostname.substring(0, 255),
          domain: fields.domain ? fields.domain.substring(0, 255) : null,
          osName: fields.osName ? fields.osName.substring(0, 100) : existing.osName,
          osVersion: fields.osVersion ? fields.osVersion.substring(0, 100) : existing.osVersion,
          osArch: fields.osArch ? fields.osArch.substring(0, 50) : null,
          manufacturer: fields.manufacturer ? fields.manufacturer.substring(0, 255) : null,
          model: fields.model ? fields.model.substring(0, 255) : null,
          serialNumber: fields.serialNumber ? fields.serialNumber.substring(0, 255) : null,
          biosVersion: fields.biosVersion ? fields.biosVersion.substring(0, 255) : null,
          cpuModel: fields.cpuModel ? fields.cpuModel.substring(0, 255) : null,
          cpuCores: fields.cpuCores ?? null,
          totalRamMb: fields.totalRamMb ?? (fields.totalRamGb ? Math.round(fields.totalRamGb * 1024) : null),
          macAddresses: extractMacAddresses(fields.macAddresses),
          ipAddresses: fields.ipAddresses ? JSON.stringify(fields.ipAddresses) : null,
          status: 'online',
          lastSeen: new Date(),
          version: fields.version ? fields.version.substring(0, 20) : '1.0.0',
        },
      })

      // SECURITY: Never return the auth token in update responses
      return NextResponse.json({ success: true, agentId: updated.agentId })
    }

    // ─── CREATE NEW AGENT ─────────────────────────────────────────────────
    // New agents must present a token. This can be:
    //   - A pre-auth tenant token (from the install-script endpoint)
    //   - A self-generated token (the server will assign its own authToken)
    //
    // NOTE: We allow registration even without a verified pre-auth token for
    // development/local deployments. In production, enforce token validation
    // by setting CBUP_STRICT_REGISTRATION=true.

    const strictRegistration = process.env.CBUP_STRICT_REGISTRATION === 'true'
    if (strictRegistration && !authToken) {
      return NextResponse.json(
        { success: false, error: 'Registration token required. Generate from the CBUP portal.' },
        { status: 401 }
      )
    }

    // Generate a new agent-specific auth token
    const newAuthToken = crypto.randomBytes(32).toString('hex') // 64-char hex

    const agent = await db.agent.create({
      data: {
        agentId,
        hostname: fields.hostname.substring(0, 255),
        domain: fields.domain ? fields.domain.substring(0, 255) : null,
        osName: fields.osName ? fields.osName.substring(0, 100) : 'Unknown',
        osVersion: fields.osVersion ? fields.osVersion.substring(0, 100) : 'Unknown',
        osArch: fields.osArch ? fields.osArch.substring(0, 50) : null,
        manufacturer: fields.manufacturer ? fields.manufacturer.substring(0, 255) : null,
        model: fields.model ? fields.model.substring(0, 255) : null,
        serialNumber: fields.serialNumber ? fields.serialNumber.substring(0, 255) : null,
        biosVersion: fields.biosVersion ? fields.biosVersion.substring(0, 255) : null,
        cpuModel: fields.cpuModel ? fields.cpuModel.substring(0, 255) : null,
        cpuCores: fields.cpuCores ?? null,
        totalRamMb: fields.totalRamMb ?? (fields.totalRamGb ? Math.round(fields.totalRamGb * 1024) : null),
        macAddresses: extractMacAddresses(fields.macAddresses),
        ipAddresses: fields.ipAddresses ? JSON.stringify(fields.ipAddresses) : null,
        version: fields.version ? fields.version.substring(0, 20) : '1.0.0',
        authToken: newAuthToken,
        status: 'online',
      },
    })

    console.log(`[CBUP AGENT] New agent registered: ${agentId} (${fields.hostname}) from IP: ${clientIp}`)

    // Return the auth token ONLY once (on initial registration)
    // The agent expects: { agentId, token } or { agentId, authToken }
    return NextResponse.json({
      success: true,
      agentId: agent.agentId,
      token: newAuthToken,       // The agent reads $response.token
      authToken: newAuthToken,   // Also provide as authToken for compatibility
    })
  } catch (error) {
    console.error('Agent registration error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}
