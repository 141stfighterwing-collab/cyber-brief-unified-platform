import { NextRequest, NextResponse } from 'next/server'
import { readFileSync, readdirSync, statSync, existsSync } from 'fs'
import { join, relative } from 'path'
import { deflateRawSync } from 'zlib'
import { checkAuth } from '@/lib/auth-check'
import { rateLimit, getClientIp, rateLimitResponse } from '@/lib/rate-limit'

// ─── Rate Limiting ───────────────────────────────────────────────────────────
const downloadRateLimit = rateLimit({ maxRequests: 20, windowMs: 5 * 60 * 1000 })

// ─── CRC-32 (ZIP requirement) ───────────────────────────────────────────────
function crc32(data: Buffer): number {
  let crc = 0xffffffff
  for (let i = 0; i < data.length; i++) {
    crc ^= data[i]
    for (let j = 0; j < 8; j++) {
      crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0)
    }
  }
  return (crc ^ 0xffffffff) >>> 0
}

// ─── Minimal ZIP creator (no external dependencies) ─────────────────────────
function createZip(files: { name: string; data: Buffer }[]): Buffer {
  const parts: Buffer[] = []
  const centralRecords: Buffer[] = []
  let offset = 0

  for (const file of files) {
    const nameBuffer = Buffer.from(file.name, 'utf-8')
    const crc = crc32(file.data)
    const compressed = deflateRawSync(file.data, { level: 9 })

    // Local file header (30 bytes + filename)
    const localHeader = Buffer.alloc(30 + nameBuffer.length)
    localHeader.writeUInt32LE(0x04034b50, 0)  // Local file header signature
    localHeader.writeUInt16LE(20, 4)           // Version needed to extract (2.0)
    localHeader.writeUInt16LE(0, 6)            // General purpose bit flag
    localHeader.writeUInt16LE(8, 8)            // Compression method: deflate
    localHeader.writeUInt16LE(0, 10)           // Last mod file time
    localHeader.writeUInt16LE(0, 12)           // Last mod file date
    localHeader.writeUInt32LE(crc, 14)         // CRC-32
    localHeader.writeUInt32LE(compressed.length, 18)  // Compressed size
    localHeader.writeUInt32LE(file.data.length, 22)   // Uncompressed size
    localHeader.writeUInt16LE(nameBuffer.length, 26)  // File name length
    localHeader.writeUInt16LE(0, 28)           // Extra field length
    nameBuffer.copy(localHeader, 30)            // Copy filename into header

    const localHeaderOffset = offset
    parts.push(localHeader, compressed)
    offset += localHeader.length + compressed.length

    // Central directory file header (46 bytes + filename)
    const centralRecord = Buffer.alloc(46 + nameBuffer.length)
    centralRecord.writeUInt32LE(0x02014b50, 0)   // Central directory header signature
    centralRecord.writeUInt16LE(20, 4)            // Version made by
    centralRecord.writeUInt16LE(20, 6)            // Version needed to extract
    centralRecord.writeUInt16LE(0, 8)             // General purpose bit flag
    centralRecord.writeUInt16LE(8, 10)            // Compression method: deflate
    centralRecord.writeUInt16LE(0, 12)            // Last mod file time
    centralRecord.writeUInt16LE(0, 14)            // Last mod file date
    centralRecord.writeUInt32LE(crc, 16)          // CRC-32
    centralRecord.writeUInt32LE(compressed.length, 20) // Compressed size
    centralRecord.writeUInt32LE(file.data.length, 24)  // Uncompressed size
    centralRecord.writeUInt16LE(nameBuffer.length, 28) // File name length
    centralRecord.writeUInt16LE(0, 30)            // Extra field length
    centralRecord.writeUInt16LE(0, 32)            // File comment length
    centralRecord.writeUInt16LE(0, 34)            // Disk number start
    centralRecord.writeUInt16LE(0, 36)            // Internal file attributes
    centralRecord.writeUInt32LE(0, 38)            // External file attributes
    centralRecord.writeUInt32LE(localHeaderOffset, 42) // Relative offset of local header
    nameBuffer.copy(centralRecord, 46)            // Copy filename into header

    centralRecords.push(centralRecord)
  }

  const centralDirOffset = offset
  let centralDirSize = 0
  for (const record of centralRecords) {
    centralDirSize += record.length
  }

  // End of central directory record (22 bytes)
  const endRecord = Buffer.alloc(22)
  endRecord.writeUInt32LE(0x06054b50, 0)        // EOCD signature
  endRecord.writeUInt16LE(0, 4)                  // Number of this disk
  endRecord.writeUInt16LE(0, 6)                  // Disk where central dir starts
  endRecord.writeUInt16LE(files.length, 8)        // Number of central dir records on this disk
  endRecord.writeUInt16LE(files.length, 10)       // Total number of central dir records
  endRecord.writeUInt32LE(centralDirSize, 12)     // Size of central directory
  endRecord.writeUInt32LE(centralDirOffset, 16)   // Offset of start of central directory
  endRecord.writeUInt16LE(0, 20)                  // Comment length

  return Buffer.concat([...parts, ...centralRecords, endRecord])
}

// ─── Collect agent files recursively ─────────────────────────────────────────
// Only includes files needed for EXE compilation: CBUP-Agent.ps1 + modules/
const EXCLUDE_PATTERNS = [
  /\.bak$/i,
  /^build-exe/i,
  /^cbup-agent-linux/i,
  /^CBUP-Agent-Tray/i,
  /^WORKLOG/i,
  /^shield\.ico$/i,
  /^dist\//i,
  /^node_modules\//i,
]

function collectFiles(dir: string, base: string): { name: string; data: Buffer }[] {
  const files: { name: string; data: Buffer }[] = []

  const entries = readdirSync(dir, { withFileTypes: true })
  for (const entry of entries) {
    const fullPath = join(dir, entry.name)
    const relativePath = relative(base, fullPath).replace(/\\/g, '/')

    // Skip excluded files
    if (EXCLUDE_PATTERNS.some(pattern => pattern.test(relativePath))) {
      continue
    }

    if (entry.isFile()) {
      files.push({
        name: relativePath,
        data: readFileSync(fullPath),
      })
    } else if (entry.isDirectory()) {
      files.push(...collectFiles(fullPath, base))
    }
  }

  return files
}

/**
 * GET /api/agents/download-package
 *
 * Returns a ZIP file containing the entire agent directory
 * (CBUP-Agent.ps1 + modules/). Used by build-exe.ps1 to
 * auto-download required files when building the EXE.
 */
export async function GET(request: NextRequest) {
  try {
    // ─── Rate Limiting ───────────────────────────────────────────────────
    const clientIp = getClientIp(request)
    const rlResult = downloadRateLimit.check(clientIp)
    if (!rlResult.allowed) {
      return rateLimitResponse(rlResult)
    }

    // ─── Auth Check (optional - allow with token for unauthenticated agents) ──
    const authResult = checkAuth(request)
    // Allow download even without admin auth (agents need this for self-build)
    // but log unauthorized access
    if (authResult) {
      console.log(`[CBUP] Agent package download from IP: ${clientIp} (unauthenticated)`)
    }

    // ─── Collect agent files ────────────────────────────────────────────
    const agentDir = join(process.cwd(), 'agent')

    if (!existsSync(agentDir)) {
      return NextResponse.json(
        { success: false, error: 'Agent directory not found on server' },
        { status: 404 }
      )
    }

    // Collect CBUP-Agent.ps1 and all module files
    const files = collectFiles(agentDir, agentDir)

    if (files.length === 0) {
      return NextResponse.json(
        { success: false, error: 'No agent files found' },
        { status: 404 }
      )
    }

    console.log(`[CBUP] Serving agent package: ${files.length} files`)

    // ─── Create ZIP ─────────────────────────────────────────────────────
    const zipBuffer = createZip(files)

    // ─── Response ───────────────────────────────────────────────────────
    return new NextResponse(zipBuffer, {
      status: 200,
      headers: {
        'Content-Type': 'application/zip',
        'Content-Disposition': 'attachment; filename="cbup-agent-package.zip"',
        'Content-Length': zipBuffer.length.toString(),
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        Pragma: 'no-cache',
        Expires: '0',
      },
    })
  } catch (error) {
    console.error('Download package error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}
