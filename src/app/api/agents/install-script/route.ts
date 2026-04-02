import { NextRequest, NextResponse } from 'next/server'
import { readFileSync, existsSync } from 'fs'
import { join } from 'path'

// GET /api/agents/install-script?platform=linux|windows|windows-exe
// Serves agent installation scripts for download/deployment
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const platform = searchParams.get('platform')

    if (!platform) {
      return NextResponse.json(
        {
          success: false,
          error:
            'Missing required query param: platform. Supported: linux, windows, windows-exe',
        },
        { status: 400 }
      )
    }

    const agentDir = join(process.cwd(), 'agent')

    switch (platform) {
      case 'linux': {
        const scriptPath = join(agentDir, 'cbup-agent-linux.sh')
        if (!existsSync(scriptPath)) {
          return NextResponse.json(
            { success: false, error: 'Linux agent script not found on server' },
            { status: 404 }
          )
        }

        const scriptContent = readFileSync(scriptPath, 'utf-8')

        return new NextResponse(scriptContent, {
          status: 200,
          headers: {
            'Content-Type': 'text/x-shellscript; charset=utf-8',
            'Content-Disposition':
              'attachment; filename="cbup-agent-linux.sh"',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            Pragma: 'no-cache',
            Expires: '0',
          },
        })
      }

      case 'windows': {
        const scriptPath = join(agentDir, 'CBUP-Agent.ps1')
        if (!existsSync(scriptPath)) {
          return NextResponse.json(
            { success: false, error: 'Windows agent script not found on server' },
            { status: 404 }
          )
        }

        const scriptContent = readFileSync(scriptPath, 'utf-8')

        return new NextResponse(scriptContent, {
          status: 200,
          headers: {
            'Content-Type': 'text/plain; charset=utf-8',
            'Content-Disposition':
              'attachment; filename="CBUP-Agent.ps1"',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            Pragma: 'no-cache',
            Expires: '0',
          },
        })
      }

      case 'windows-exe': {
        const instructions = `# CBUP Agent - Windows EXE Installation Guide
# ==================================================
# 
# The CBUP Agent EXE is a compiled version of CBUP-Agent.ps1.
# 
# Option 1: Download the pre-built EXE
#   - Download CBUP-Agent.exe from the CBUP portal
#   - Run as Administrator: CBUP-Agent.exe -ServerUrl https://YOUR-PORTAL -Install
# 
# Option 2: Build from source
#   1. Download CBUP-Agent.ps1 and build-exe.ps1
#   2. Open PowerShell as Administrator
#   3. Run: .\\build-exe.ps1
#   4. The compiled EXE will be in the ./dist/ directory
# 
# Option 3: Run directly as PowerShell script
#   - Download CBUP-Agent.ps1
#   - Run: powershell -ExecutionPolicy Bypass -File .\\CBUP-Agent.ps1 -ServerUrl https://YOUR-PORTAL -Install
#
# Supported arguments (same for EXE and PS1):
#   -ServerUrl URL     CBUP Portal URL (required for installation)
#   -Install           Install as Windows service
#   -Uninstall         Uninstall agent service
#   -Interval SECONDS  Telemetry interval (default: 30)
#   -ScanInterval MIN  EDR scan interval (default: 60, 0=disabled)
#   -DevMode           Run in foreground with verbose output
#   -Token TOKEN       Pre-authenticated registration token
#
# System Tray Application (Optional):
#   - Download CBUP-Agent-Tray.ps1
#   - Run: powershell -ExecutionPolicy Bypass -File .\\CBUP-Agent-Tray.ps1
#   - Shows status icon in system tray with context menu
#
# Requirements:
#   - Windows PowerShell 5.1+
#   - .NET Framework 4.5+
#   - Administrator privileges for installation
#
# Version: 2.0.0
`

        return new NextResponse(instructions, {
          status: 200,
          headers: {
            'Content-Type': 'text/plain; charset=utf-8',
            'Content-Disposition':
              'attachment; filename="CBUP-Agent-EXE-Instructions.txt"',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            Pragma: 'no-cache',
            Expires: '0',
          },
        })
      }

      default: {
        return NextResponse.json(
          {
            success: false,
            error: `Unsupported platform: ${platform}. Supported: linux, windows, windows-exe`,
          },
          { status: 400 }
        )
      }
    }
  } catch (error) {
    console.error('Install script error:', error)
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    )
  }
}
