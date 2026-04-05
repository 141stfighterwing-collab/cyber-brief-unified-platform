#Requires -Version 5.1
<#
.SYNOPSIS
    CBUP Agent EXE Build Script
.DESCRIPTION
    Compiles CBUP-Agent.ps1 into a standalone .exe using the ps2exe module.
    Supports console mode, windows (hidden) mode, and custom icons.

    If CBUP-Agent.ps1 or modules/ are not found locally, this script will
    auto-download them from the CBUP server (requires $CBUP_SERVER_ORIGIN
    to be set, which is automatically injected when downloaded from the portal).
.NOTES
    Version:    2.4.0
    Author:     CBUP Security Engineering
    Project:    Cyber Brief Unified Platform

.EXAMPLE
    .\build-exe.ps1
    Builds CBUP-Agent.exe in console mode with default settings.

.EXAMPLE
    .\build-exe.ps1 -Mode windows -IconFile .\shield.ico
    Builds CBUP-Agent.exe as a windows application (hidden console) with custom icon.

.EXAMPLE
    .\build-exe.ps1 -Mode both
    Builds both console and windows (hidden) versions.
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Build mode: console, windows, or both")]
    [ValidateSet("console", "windows", "both")]
    [string]$Mode = "console",

    [Parameter(HelpMessage = "Path to .ico file for the executable")]
    [string]$IconFile,

    [Parameter(HelpMessage = "Output directory for built executables")]
    [string]$OutputDir,

    [Parameter(HelpMessage = "Do not generate a default icon")]
    [switch]$NoIcon,

    [Parameter(HelpMessage = "Force reinstall of ps2exe module")]
    [switch]$ForceModuleInstall,

    [Parameter(HelpMessage = "CBUP server URL for auto-downloading agent source files")]
    [string]$ServerOrigin
)

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AgentVersion = "2.4.0"
$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:SourceScript = Join-Path $script:ScriptDir "CBUP-Agent.ps1"
$script:ModulesDir = Join-Path $script:ScriptDir "modules"
$script:DefaultOutputDir = Join-Path $script:ScriptDir "dist"
$script:DefaultIconPath = Join-Path $script:ScriptDir "shield.ico"

# Use injected server origin or parameter
if (-not $ServerOrigin -and $CBUP_SERVER_ORIGIN) {
    $ServerOrigin = $CBUP_SERVER_ORIGIN
}

# =============================================================================
# AUTO-DOWNLOAD AGENT SOURCE FILES
# =============================================================================

function Get-RequiredAgentFiles {
    <#
    .SYNOPSIS
        Ensures CBUP-Agent.ps1 and modules/ are available.
        Downloads from the CBUP server if missing locally.
    #>

    $needDownload = $false

    if (-not (Test-Path $script:SourceScript)) {
        Write-Host "    [MISSING] CBUP-Agent.ps1 not found locally" -ForegroundColor Yellow
        $needDownload = $true
    }
    elseif (-not (Test-Path (Join-Path $script:ModulesDir "CBUP-API.ps1"))) {
        Write-Host "    [MISSING] modules/ directory not found or incomplete" -ForegroundColor Yellow
        $needDownload = $true
    }

    if (-not $needDownload) {
        Write-Host "    [OK] Source script and modules found locally" -ForegroundColor Green
        return $true
    }

    # Need to download from server
    if (-not $ServerOrigin) {
        Write-Host ""
        Write-Host "    [ERROR] Agent source files are missing and no server URL provided." -ForegroundColor Red
        Write-Host "    You must either:" -ForegroundColor Yellow
        Write-Host "      1. Download this script from the CBUP portal (auto-injects server URL)" -ForegroundColor Yellow
        Write-Host "      2. Place CBUP-Agent.ps1 and modules/ in: $($script:ScriptDir)" -ForegroundColor Yellow
        Write-Host "      3. Use -ServerOrigin parameter: .\build-exe.ps1 -ServerOrigin http://your-server:3001" -ForegroundColor Yellow
        Write-Host ""
        return $false
    }

    # Clean up any partial downloads
    if (Test-Path $script:SourceScript) { Remove-Item $script:SourceScript -Force }
    if (Test-Path $script:ModulesDir) { Remove-Item $script:ModulesDir -Recurse -Force }

    $packageUrl = "$ServerOrigin/api/agents/download-package"

    Write-Host "    [*] Downloading agent package from server..." -ForegroundColor Cyan
    Write-Host "        URL: $packageUrl" -ForegroundColor DarkGray

    try {
        $tempZip = Join-Path $env:TEMP "cbup-agent-package.zip"

        # Download with TLS 1.2+
        $securityProtocol = [Net.ServicePointManager]::SecurityProtocol
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $packageUrl -OutFile $tempZip -UseBasicParsing -TimeoutSec 120
        $ProgressPreference = 'Continue'

        [Net.ServicePointManager]::SecurityProtocol = $securityProtocol

        if (-not (Test-Path $tempZip)) {
            Write-Host "    [ERROR] Download failed - no file received" -ForegroundColor Red
            return $false
        }

        $zipSize = (Get-Item $tempZip).Length
        if ($zipSize -lt 1000) {
            Write-Host "    [ERROR] Downloaded file is too small ($($zipSize) bytes) - likely an error response" -ForegroundColor Red
            $content = Get-Content $tempZip -Raw -ErrorAction SilentlyContinue
            if ($content) { Write-Host "    Response: $content" -ForegroundColor DarkGray }
            Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
            return $false
        }

        Write-Host "    [OK] Downloaded package ($([math]::Round($zipSize / 1KB, 1)) KB)" -ForegroundColor Green

        # Extract ZIP
        Write-Host "    [*] Extracting agent files..." -ForegroundColor Cyan

        # Try Expand-Archive (PowerShell 5.0+)
        try {
            Expand-Archive -Path $tempZip -DestinationPath $script:ScriptDir -Force
            Write-Host "    [OK] Files extracted successfully" -ForegroundColor Green
        }
        catch {
            # Fallback: use COM Shell.Application
            try {
                $shell = New-Object -ComObject Shell.Application
                $zipShell = $shell.Namespace($tempZip)
                $destShell = $shell.Namespace($script:ScriptDir)
                $destShell.CopyHere($zipShell.Items(), 0x14) # 0x14 = no confirm UI
                Start-Sleep -Seconds 2
                Write-Host "    [OK] Files extracted (COM fallback)" -ForegroundColor Green
            }
            catch {
                Write-Host "    [ERROR] Failed to extract ZIP: $_" -ForegroundColor Red
                Write-Host "    Try manually extracting: $tempZip" -ForegroundColor Yellow
                Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
                return $false
            }
        }

        # Clean up temp file
        Remove-Item $tempZip -Force -ErrorAction SilentlyContinue

        # Verify extraction
        if (-not (Test-Path $script:SourceScript)) {
            Write-Host "    [ERROR] CBUP-Agent.ps1 not found after extraction" -ForegroundColor Red
            return $false
        }

        $moduleCount = (Get-ChildItem -Path $script:ModulesDir -Filter "*.ps1" -ErrorAction SilentlyContinue).Count
        Write-Host "    [OK] CBUP-Agent.ps1 + $moduleCount module files ready" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "    [ERROR] Download failed: $_" -ForegroundColor Red
        if ($tempZip -and (Test-Path $tempZip)) {
            Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        }
        return $false
    }
}

# =============================================================================
# PREREQUISITE CHECKS
# =============================================================================

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Verifies all prerequisites for building the EXE.
    #>
    Write-Host "[*] Checking prerequisites..." -ForegroundColor Cyan

    # Check for agent source files (auto-download if missing)
    if (-not (Get-RequiredAgentFiles)) {
        Write-Error "Cannot proceed without agent source files. See errors above."
        exit 1
    }

    # Check source script exists (re-verify after download)
    if (-not (Test-Path $script:SourceScript)) {
        Write-Error "Source script not found: $($script:SourceScript)"
        exit 1
    }
    Write-Host "    [OK] Source script: CBUP-Agent.ps1" -ForegroundColor Green

    # Check modules directory
    if (-not (Test-Path $script:ModulesDir)) {
        Write-Error "Modules directory not found: $($script:ModulesDir)"
        exit 1
    }
    $moduleCount = (Get-ChildItem -Path $script:ModulesDir -Filter "*.ps1" -ErrorAction SilentlyContinue).Count
    Write-Host "    [OK] Modules: $moduleCount files found" -ForegroundColor Green

    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    Write-Host "    [OK] PowerShell version: $($psVersion.ToString())" -ForegroundColor Green

    # Check .NET Framework availability
    $dotnetVersion = $null
    try {
        $dotnetVersion = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
        Write-Host "    [OK] Runtime: $dotnetVersion" -ForegroundColor Green
    }
    catch {
        try {
            $dotnetVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue).Version
            if ($dotnetVersion) {
                Write-Host "    [OK] .NET Framework: $dotnetVersion" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "    [WARN] Could not determine .NET version (continuing anyway)" -ForegroundColor Yellow
        }
    }
}

# =============================================================================
# PS2EXE MODULE MANAGEMENT
# =============================================================================

function Install-Ps2ExeModule {
    <#
    .SYNOPSIS
        Installs or updates the ps2exe module from PowerShell Gallery.
    #>
    Write-Host "[*] Checking ps2exe module..." -ForegroundColor Cyan

    $module = Get-Module -ListAvailable -Name "ps2exe" -ErrorAction SilentlyContinue

    if ($module -and -not $ForceModuleInstall) {
        Write-Host "    [OK] ps2exe module found (v$($module.Version.ToString()))" -ForegroundColor Green
        return
    }

    Write-Host "    [*] Installing ps2exe module from PowerShell Gallery..." -ForegroundColor Yellow

    # Ensure NuGet package provider is available
    $nugetProvider = Get-PackageProvider -Name "NuGet" -ErrorAction SilentlyContinue
    if (-not $nugetProvider) {
        Write-Host "    [*] Installing NuGet package provider..." -ForegroundColor Yellow
        try {
            Install-PackageProvider -Name "NuGet" -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -ErrorAction Stop
        }
        catch {
            Write-Host "    [WARN] Failed to install NuGet provider automatically: $_" -ForegroundColor Yellow
            Write-Host "    [*] Continuing with ps2exe install (may prompt for NuGet)..." -ForegroundColor Yellow
        }
    }

    # Set PSGallery as trusted to avoid prompts
    $repo = Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue
    if ($repo -and -not $repo.Trusted) {
        try {
            Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction Stop
            Write-Host "    [OK] PSGallery set as trusted" -ForegroundColor Green
        }
        catch {
            Write-Host "    [WARN] Could not set PSGallery as trusted: $_" -ForegroundColor Yellow
        }
    }

    try {
        Install-Module -Name "ps2exe" -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Write-Host "    [OK] ps2exe module installed successfully" -ForegroundColor Green
    }
    catch {
        # Try system scope if current user fails
        try {
            Install-Module -Name "ps2exe" -Force -AllowClobber -ErrorAction Stop
            Write-Host "    [OK] ps2exe module installed (system scope)" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to install ps2exe module: $_"
            Write-Host ""
            Write-Host "Manual install:" -ForegroundColor Yellow
            Write-Host "  Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force" -ForegroundColor Yellow
            Write-Host "  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted" -ForegroundColor Yellow
            Write-Host "  Install-Module -Name ps2exe -Force -AllowClobber" -ForegroundColor Yellow
            exit 1
        }
    }
}

function Import-Ps2ExeModule {
    <#
    .SYNOPSIS
        Imports the ps2exe module.
    #>
    try {
        Import-Module -Name "ps2exe" -Force -ErrorAction Stop
        Write-Host "    [OK] ps2exe module loaded" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to import ps2exe module: $_"
        Write-Host "    Try running: Install-Module -Name ps2exe -Force -AllowClobber" -ForegroundColor Yellow
        exit 1
    }
}

# =============================================================================
# ICON GENERATION
# =============================================================================

function New-ShieldIcon {
    <#
    .SYNOPSIS
        Generates a simple shield icon (.ico file) using System.Drawing.
        Creates a green shield with a checkmark, suitable for a security agent.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter()]
        [int]$Size = 64
    )

    Write-Host "    [*] Generating default shield icon..." -ForegroundColor Yellow

    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop

        # Create a multi-resolution icon (16x16, 32x32, 48x48, 64x64)
        # Note: Skip 256x256 on PS 5.1 — large GDI+ bitmaps can cause
        # Pen constructor failures and out-of-memory in some environments.
        $iconSizes = @(16, 32, 48, 64)
        $bitmapList = New-Object System.Collections.Generic.List[System.Drawing.Bitmap]

        foreach ($s in $iconSizes) {
            $bmp = New-Object System.Drawing.Bitmap($s, $s)
            $gfx = [System.Drawing.Graphics]::FromImage($bmp)

            # High-quality rendering
            $gfx.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $gfx.Clear([System.Drawing.Color]::Transparent)

            # Scale factor
            $scale = $s / 64.0

            # Shield body (rounded rectangle with curved top)
            $shieldColor = [System.Drawing.Color]::FromArgb(0, 180, 100)  # Green
            $shieldBrush = New-Object System.Drawing.SolidBrush($shieldColor)
            $penWidth = [System.Single]($s * 2.0 / 64.0)
            $shieldPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(0, 140, 75), $penWidth)

            # Draw shield shape using GraphicsPath
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $margin = 6 * $scale
            $width = ($s - 2 * $margin)
            $height = ($s - 2 * $margin)

            # Top-left corner
            $path.AddArc($margin, $margin, $width * 0.4, $height * 0.3, 180, 90)
            # Top-right corner
            $path.AddArc($margin + $width * 0.6, $margin, $width * 0.4, $height * 0.3, 270, 90)
            # Right side
            $path.AddLine($margin + $width, $margin + $height * 0.15, $margin + $width, $margin + $height * 0.55)
            # Bottom point
            $path.AddLine($margin + $width, $margin + $height * 0.55, $s / 2, $s - $margin)
            $path.AddLine($s / 2, $s - $margin, $margin, $margin + $height * 0.55)
            # Left side
            $path.AddLine($margin, $margin + $height * 0.55, $margin, $margin + $height * 0.15)
            $path.CloseFigure()

            $gfx.FillPath($shieldBrush, $path)
            $gfx.DrawPath($shieldPen, $path)

            # Checkmark
            $checkColor = [System.Drawing.Color]::White
            $checkWidth = [System.Single]($s * 4.0 / 64.0)
            $checkPen = New-Object System.Drawing.Pen($checkColor, $checkWidth)
            $checkPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
            $checkPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

            $checkStart = New-Object System.Drawing.PointF(($s * 0.22), ($s * 0.52))
            $checkMid = New-Object System.Drawing.PointF(($s * 0.42), ($s * 0.72))
            $checkEnd = New-Object System.Drawing.PointF(($s * 0.78), ($s * 0.28))

            $gfx.DrawLines($checkPen, @($checkStart, $checkMid, $checkEnd))

            # Cleanup
            $gfx.Dispose()
            $shieldBrush.Dispose()
            $shieldPen.Dispose()
            $checkPen.Dispose()

            $bitmapList.Add($bmp)
        }

        # Save as ICO
        $iconFile = New-Object System.IO.FileStream($OutputPath, [System.IO.FileMode]::Create)
        $writer = New-Object System.IO.BinaryWriter($iconFile)

        # ICO Header
        $writer.Write([UInt16]0)      # Reserved
        $writer.Write([UInt16]1)      # ICO type
        $writer.Write([UInt16]$bitmapList.Count)  # Number of images

        # Calculate offsets
        $headerSize = 6 + ($bitmapList.Count * 16)
        $dataOffset = $headerSize

        # Write directory entries
        $imageDataList = New-Object System.Collections.Generic.List[byte[]]
        foreach ($bmp in $bitmapList) {
            $ms = New-Object System.IO.MemoryStream
            $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
            $imageData = $ms.ToArray()
            $ms.Dispose()
            $imageDataList.Add($imageData)

            $w = if ($bmp.Width -ge 256) { 0 } else { $bmp.Width }
            $h = if ($bmp.Height -ge 256) { 0 } else { $bmp.Height }

            $writer.Write([byte]$w)           # Width
            $writer.Write([byte]$h)           # Height
            $writer.Write([byte]0)            # Color palette
            $writer.Write([byte]0)            # Reserved
            $writer.Write([UInt16]1)          # Color planes
            $writer.Write([UInt16]32)         # Bits per pixel
            $writer.Write([UInt32]$imageData.Length)  # Image size
            $writer.Write([UInt32]$dataOffset)        # Offset
            $dataOffset += $imageData.Length
        }

        # Write image data
        foreach ($data in $imageDataList) {
            $writer.Write($data)
        }

        $writer.Close()
        $iconFile.Close()

        # Cleanup bitmaps
        foreach ($bmp in $bitmapList) {
            $bmp.Dispose()
        }

        Write-Host "    [OK] Icon generated: $OutputPath ($($bitmapList.Count) resolutions)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Warning "Failed to generate icon: $_"
        return $false
    }
}

# =============================================================================
# BUILD FUNCTIONS
# =============================================================================

function Build-Exe {
    <#
    .SYNOPSIS
        Compiles the CBUP-Agent.ps1 script into an EXE using ps2exe.
    .PARAMETER Platform
        Target platform: console or windows (hidden console).
    .PARAMETER OutputPath
        Output file path for the EXE.
    .PARAMETER IconPath
        Path to .ico file.
    #>
    param(
        [Parameter(Mandatory)]
        [ValidateSet("console", "windows")]
        [string]$Platform,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [string]$IconPath
    )

    $displayName = if ($Platform -eq "console") { "Console" } else { "Windows (Hidden)" }
    Write-Host "[*] Building CBUP-Agent.exe ($displayName mode)..." -ForegroundColor Cyan

    # Dynamically detect supported parameters for the installed ps2exe version.
    # Older versions may not have requiresAdmin, sta, mta, nested, etc.
    $ps2exeCmd = Get-Command -Name "Invoke-ps2exe" -ErrorAction SilentlyContinue
    $supportedParams = @{}
    if ($ps2exeCmd) {
        $ps2exeCmd.Parameters.Keys | ForEach-Object { $supportedParams[$_] = $true }
        Write-Host "    [INFO] ps2exe supports: $($supportedParams.Keys -join ', ')" -ForegroundColor DarkGray
    }

    $params = @{
        inputFile         = $script:SourceScript
        outputFile        = $OutputPath
        noConsole         = ($Platform -eq "windows")
        title             = "CBUP Monitoring Agent v$($script:AgentVersion)"
        description       = "Cyber Brief Unified Platform - Endpoint Monitoring & EDR Agent"
        company           = "CBUP Security Engineering"
        product           = "CBUP Agent"
        version           = $script:AgentVersion
        copyright         = "(c) $(Get-Date -Format yyyy) CBUP Security Engineering"
    }

    # Only add optional parameters if the installed ps2exe version supports them
    if ($supportedParams['requiresAdmin'])  { $params['requiresAdmin']  = $false }
    if ($supportedParams['sta'])            { $params['sta']            = $false }
    if ($supportedParams['mta'])            { $params['mta']            = $true }
    if ($supportedParams['runtime40'])      { $params['runtime40']      = $true }
    if ($supportedParams['nested'])         { $params['nested']         = $true }
    if ($supportedParams['credential'])     { $params['credential']     = $null }

    # Override with injected metadata if available
    if ($CBUP_EXE_COMPANY)    { $params["company"]     = $CBUP_EXE_COMPANY }
    if ($CBUP_EXE_PRODUCT)    { $params["product"]     = $CBUP_EXE_PRODUCT }
    if ($CBUP_EXE_VERSION)    { $params["version"]     = $CBUP_EXE_VERSION }
    if ($CBUP_EXE_DESCRIPTION) { $params["description"] = $CBUP_EXE_DESCRIPTION }

    if ($IconPath -and (Test-Path $IconPath)) {
        $params["iconFile"] = $IconPath
        Write-Host "    [OK] Using icon: $IconPath" -ForegroundColor Green
    }
    else {
        Write-Host "    [INFO] No icon specified or icon not found. Building without icon." -ForegroundColor Yellow
    }

    try {
        Invoke-ps2exe @params -ErrorAction Stop

        if (Test-Path $OutputPath) {
            $fileInfo = Get-Item $OutputPath
            $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
            Write-Host "    [OK] Build successful!" -ForegroundColor Green
            Write-Host "    [OK] Output: $($OutputPath)" -ForegroundColor Green
            Write-Host "    [OK] Size: ${fileSizeMB} MB" -ForegroundColor Green
            return $true
        }
        else {
            Write-Error "Build completed but output file not found: $OutputPath"
            return $false
        }
    }
    catch {
        Write-Error "Build failed: $_"
        return $false
    }
}

# =============================================================================
# MAIN
# =============================================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor DarkCyan
Write-Host "  CBUP Agent EXE Builder v$($script:AgentVersion)" -ForegroundColor DarkCyan
Write-Host "  Cyber Brief Unified Platform" -ForegroundColor DarkCyan
Write-Host "============================================" -ForegroundColor DarkCyan
Write-Host ""

# Step 1: Check prerequisites (includes auto-download)
Test-Prerequisites
Write-Host ""

# Step 2: Install ps2exe module
Install-Ps2ExeModule
Write-Host ""

# Step 3: Import module
Import-Ps2ExeModule
Write-Host ""

# Step 4: Determine output directory
if ($OutputDir) {
    $script:FinalOutputDir = $OutputDir
}
else {
    $script:FinalOutputDir = $script:DefaultOutputDir
}

if (-not (Test-Path $script:FinalOutputDir)) {
    New-Item -ItemType Directory -Path $script:FinalOutputDir -Force | Out-Null
}
Write-Host "[*] Output directory: $($script:FinalOutputDir)" -ForegroundColor Cyan
Write-Host ""

# Step 5: Generate icon if needed
$iconPath = $IconFile
if (-not $NoIcon -and -not $iconPath) {
    if (Test-Path $script:DefaultIconPath) {
        $iconPath = $script:DefaultIconPath
    }
    else {
        $iconGenerated = New-ShieldIcon -OutputPath $script:DefaultIconPath -Size 256
        if ($iconGenerated) {
            $iconPath = $script:DefaultIconPath
        }
    }
}

if (-not $iconPath) {
    $iconPath = $null
}
Write-Host ""

# Step 6: Build EXE(s)
$buildSuccess = $true

switch ($Mode) {
    "console" {
        $consoleExe = Join-Path $script:FinalOutputDir "CBUP-Agent.exe"
        if (-not (Build-Exe -Platform "console" -OutputPath $consoleExe -IconPath $iconPath)) {
            $buildSuccess = $false
        }
    }
    "windows" {
        $windowsExe = Join-Path $script:FinalOutputDir "CBUP-Agent.exe"
        if (-not (Build-Exe -Platform "windows" -OutputPath $windowsExe -IconPath $iconPath)) {
            $buildSuccess = $false
        }
    }
    "both" {
        # Console version
        $consoleOutputDir = Join-Path $script:FinalOutputDir "console"
        if (-not (Test-Path $consoleOutputDir)) {
            New-Item -ItemType Directory -Path $consoleOutputDir -Force | Out-Null
        }
        $consoleExe = Join-Path $consoleOutputDir "CBUP-Agent.exe"
        if (-not (Build-Exe -Platform "console" -OutputPath $consoleExe -IconPath $iconPath)) {
            $buildSuccess = $false
        }
        Write-Host ""

        # Windows (hidden) version
        $windowsOutputDir = Join-Path $script:FinalOutputDir "windows"
        if (-not (Test-Path $windowsOutputDir)) {
            New-Item -ItemType Directory -Path $windowsOutputDir -Force | Out-Null
        }
        $windowsExe = Join-Path $windowsOutputDir "CBUP-Agent.exe"
        if (-not (Build-Exe -Platform "windows" -OutputPath $windowsExe -IconPath $iconPath)) {
            $buildSuccess = $false
        }
    }
}

# =============================================================================
# SUMMARY
# =============================================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor DarkCyan
Write-Host "  Build Summary" -ForegroundColor DarkCyan
Write-Host "============================================" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  Mode:           $Mode" -ForegroundColor White
Write-Host "  Source:         $($script:SourceScript)" -ForegroundColor White
Write-Host "  Output Dir:     $($script:FinalOutputDir)" -ForegroundColor White
Write-Host "  Icon:           $(if ($iconPath) { $iconPath } else { '(none)' })" -ForegroundColor White
Write-Host ""

if ($Mode -eq "both") {
    Write-Host "  Console EXE:    $consoleExe" -ForegroundColor Green
    Write-Host "  Windows EXE:    $windowsExe" -ForegroundColor Green
}
else {
    Write-Host "  EXE:            $(if ($Mode -eq 'console') { $consoleExe } else { $windowsExe })" -ForegroundColor Green
}

Write-Host ""

if ($buildSuccess) {
    Write-Host "[OK] All builds completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\CBUP-Agent.exe -ServerUrl https://cbup.example.com -Install" -ForegroundColor White
    Write-Host "  .\CBUP-Agent.exe -ServerUrl https://cbup.example.com -DevMode" -ForegroundColor White
    Write-Host "  .\CBUP-Agent.exe -Uninstall" -ForegroundColor White
    if ($Mode -ne "console") {
        Write-Host ""
        Write-Host "For windows mode, use the --no-console flag:" -ForegroundColor Yellow
        Write-Host "  .\CBUP-Agent.exe -ServerUrl URL -Install -NoConsole" -ForegroundColor White
    }
}
else {
    Write-Host "[ERROR] One or more builds failed. Check the errors above." -ForegroundColor Red
    exit 1
}
