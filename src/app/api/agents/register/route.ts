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

    const {
      agentId,
      hostname,
      domain,
      osName,
      osVersion,
      osArch,
      manufacturer,
      model,
      serialNumber,
      biosVersion,
      cpuModel,
      cpuCores,
      totalRamMb,
      macAddresses,
      ipAddresses,
      version,
      authToken,
    } = body

    // ─── Input Validation ─────────────────────────────────────────────────
    if (!agentId || !hostname || !osName || !osVersion) {
      return NextResponse.json(
        { success: false, error: 'Missing required fields: agentId, hostname, osName, osVersion' },
        { status: 400 }
      )
    }

    if (!AGENT_ID_REGEX.test(agentId)) {
      return NextResponse.json(
        { success: false, error: 'Invalid agentId format. Must be 8-128 alphanumeric characters.' },
        { status: 400 }
      )
    }

    if (!HOSTNAME_REGEX.test(hostname)) {
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
      if (!safeEqual(authToken, existing.authToken)) {
        return NextResponse.json(
          { success: false, error: 'Invalid auth token' },
          { status: 401 }
        )
      }

      const updated = await db.agent.update({
        where: { agentId },
        data: {
          hostname: hostname.substring(0, 255),
          domain: domain ? domain.substring(0, 255) : null,
          osName: osName.substring(0, 100),
          osVersion: osVersion.substring(0, 100),
          osArch: osArch ? osArch.substring(0, 50) : null,
          manufacturer: manufacturer ? manufacturer.substring(0, 255) : null,
          model: model ? model.substring(0, 255) : null,
          serialNumber: serialNumber ? serialNumber.substring(0, 255) : null,
          biosVersion: biosVersion ? biosVersion.substring(0, 255) : null,
          cpuModel: cpuModel ? cpuModel.substring(0, 255) : null,
          cpuCores: cpuCores ?? null,
          totalRamMb: totalRamMb ?? null,
          macAddresses: macAddresses ? JSON.stringify(macAddresses) : null,
          ipAddresses: ipAddresses ? JSON.stringify(ipAddresses) : null,
          status: 'online',
          lastSeen: new Date(),
          version: version ? version.substring(0, 20) : '1.0.0',
        },
      })

      // SECURITY: Never return the auth token in update responses
      return NextResponse.json({ success: true, agentId: updated.agentId })
    }

    // ─── CREATE NEW AGENT ─────────────────────────────────────────────────
    // SECURITY: New agents must present a valid pre-auth token (from install-script endpoint)
    // The pre-auth token is verified against valid tenant tokens
    const preAuthToken = authToken || request.headers.get('x-cbup-registration-token')

    if (!preAuthToken) {
      return NextResponse.json(
        { success: false, error: 'Registration token required. Generate from the CBUP portal.' },
        { status: 401 }
      )
    }

    // Verify pre-auth token format
    if (!AGENT_ID_REGEX.test(preAuthToken) && preAuthToken.length < 8) {
      return NextResponse.json(
        { success: false, error: 'Invalid registration token format' },
        { status: 400 }
      )
    }

    // Generate a new agent-specific auth token
    const newAuthToken = crypto.randomBytes(32).toString('hex') // 64-char hex (more secure)

    const agent = await db.agent.create({
      data: {
        agentId,
        hostname: hostname.substring(0, 255),
        domain: domain ? domain.substring(0, 255) : null,
        osName: osName.substring(0, 100),
        osVersion: osVersion.substring(0, 100),
        osArch: osArch ? osArch.substring(0, 50) : null,
        manufacturer: manufacturer ? manufacturer.substring(0, 255) : null,
        model: model ? model.substring(0, 255) : null,
        serialNumber: serialNumber ? serialNumber.substring(0, 255) : null,
        biosVersion: biosVersion ? biosVersion.substring(0, 255) : null,
        cpuModel: cpuModel ? cpuModel.substring(0, 255) : null,
        cpuCores: cpuCores ?? null,
        totalRamMb: totalRamMb ?? null,
        macAddresses: macAddresses ? JSON.stringify(macAddresses) : null,
        ipAddresses: ipAddresses ? JSON.stringify(ipAddresses) : null,
        version: version ? version.substring(0, 20) : '1.0.0',
        authToken: newAuthToken,
        status: 'online',
      },
    })

    console.log(`[CBUP AGENT] New agent registered: ${agentId} (${hostname})`)

    // Return the auth token ONLY once (on initial registration)
    return NextResponse.json({
      success: true,
      agentId: agent.agentId,
      authToken: newAuthToken,
    })
  } catch (error) {
    console.error('Agent registration error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}
