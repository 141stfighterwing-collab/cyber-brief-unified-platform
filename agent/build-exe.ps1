#Requires -Version 5.1
<#
.SYNOPSIS
    CBUP Agent EXE Build Script
.DESCRIPTION
    Compiles CBUP-Agent.ps1 into a standalone .exe using the ps2exe module.
    Supports console mode, windows (hidden) mode, and custom icons.
.NOTES
    Version:    2.0.0
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
    [switch]$ForceModuleInstall
)

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AgentVersion = "2.0.0"
$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:SourceScript = Join-Path $script:ScriptDir "CBUP-Agent.ps1"
$script:DefaultOutputDir = Join-Path $script:ScriptDir "dist"
$script:DefaultIconPath = Join-Path $script:ScriptDir "shield.ico"

# =============================================================================
# PREREQUISITE CHECKS
# =============================================================================

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Verifies all prerequisites for building the EXE.
    #>
    Write-Host "[*] Checking prerequisites..." -ForegroundColor Cyan

    # Check source script exists
    if (-not (Test-Path $script:SourceScript)) {
        Write-Error "Source script not found: $($script:SourceScript)"
        exit 1
    }
    Write-Host "    [OK] Source script found: CBUP-Agent.ps1" -ForegroundColor Green

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

    try {
        # Try current user scope first
        if (-not $ForceModuleInstall) {
            $module = Get-Module -ListAvailable -Name "ps2exe" -ErrorAction SilentlyContinue
        }

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

        # Create a multi-resolution icon (16x16, 32x32, 48x48, 64x64, 256x256)
        $iconSizes = @(16, 32, 48, 64, 256)
        $bitmapList = [System.Collections.Generic.List[System.Drawing.Bitmap]]::new()

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
            $shieldPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(0, 140, 75), 2 * $scale)

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
            $checkPen = New-Object System.Drawing.Pen($checkColor, 4 * $scale)
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
        $imageDataList = [System.Collections.Generic.List[byte[]]]::new()
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
        requiresAdmin     = $false
        sta               = $false
        mta               = $true
        runtime40         = $true
        nested             = $true
    }

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

# Step 1: Check prerequisites
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
