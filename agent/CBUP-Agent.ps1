#Requires -Version 5.1
<#
.SYNOPSIS
    CBUP Agent - Endpoint Monitoring & EDR
.DESCRIPTION
    Comprehensive endpoint monitoring agent for the Cyber Brief Unified Platform (CBUP).
    Collects system metrics, performs EDR scanning, and communicates with the CBUP portal
    via a command-and-control (C2) protocol for centralized security management.
.NOTES
    Version:    2.1.0
    Author:     CBUP Security Engineering
    Project:    Cyber Brief Unified Platform
    License:    Proprietary

.PARAMETER ServerUrl
    URL of the CBUP portal (required for registration and telemetry).

.PARAMETER Install
    Switch to install the agent as a Windows service.

.PARAMETER Uninstall
    Switch to uninstall the agent service and clean up registry.

.PARAMETER Interval
    Telemetry collection interval in seconds (default: 30).

.PARAMETER ScanInterval
    EDR scan interval in minutes (default: 60, 0 to disable scheduled scans).

.PARAMETER Token
    Pre-authenticated registration token. If omitted, one is obtained at registration.

.PARAMETER DevMode
    Run as a standalone console process (no service installation, verbose output).

.EXAMPLE
    .\CBUP-Agent.ps1 -ServerUrl "https://cbup.example.com" -Install
    Installs the agent as a Windows service.

.EXAMPLE
    .\CBUP-Agent.ps1 -ServerUrl "https://cbup.example.com" -DevMode -Interval 10
    Runs in development mode with 10-second telemetry intervals.
#>

[CmdletBinding(DefaultParameterSetName = "Run")]
param(
    [Parameter(Mandatory = $false, HelpMessage = "CBUP Portal URL")]
    [ValidateNotNullOrEmpty()]
    [string]$ServerUrl,

    [Parameter(ParameterSetName = "Install", HelpMessage = "Install as Windows service")]
    [switch]$Install,

    [Parameter(ParameterSetName = "Uninstall", HelpMessage = "Uninstall agent")]
    [switch]$Uninstall,

    [Parameter(HelpMessage = "Telemetry interval in seconds")]
    [ValidateRange(5, 300)]
    [int]$Interval = 30,

    [Parameter(HelpMessage = "EDR scan interval in minutes (0=disabled)")]
    [ValidateRange(0, 1440)]
    [int]$ScanInterval = 60,

    [Parameter(HelpMessage = "Pre-authenticated token")]
    [string]$Token,

    [Parameter(HelpMessage = "Run in development mode")]
    [switch]$DevMode
)

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AgentVersion = "2.1.0"
$script:RegKeyPath = "HKLM:\SOFTWARE\CBUP"
$script:ServiceName = "CBUPAgent"
$script:ServiceDisplayName = "CBUP Monitoring Agent"
$script:ServiceDescription = "Cyber Brief Unified Platform - Endpoint Monitoring & EDR Agent"
$script:LogName = "CBUP-Agent"
$script:LogSource = "CBUPAgent"
$script:LogFilePath = "$env:ProgramData\CBUP\agent.log"
$script:MaxLogSizeMB = 50
$script:MaxRetries = 3
$script:RetryDelaySec = 5
$script:CommandPollInterval = 15
$script:ShutdownRequested = $false
$script:LastTelemetryTime = [datetime]::MinValue
$script:LastScanTime = [datetime]::MinValue
$script:LastCommandPoll = [datetime]::MinValue

# Suspicious port signatures for EDR
$script:SuspiciousPorts = @(1337, 4444, 5555, 31337, 1234, 6666, 6667, 8888, 9999, 5556, 32764, 5985, 445)

# Known suspicious process name patterns
$script:SuspiciousProcessPatterns = @(
    'mimikatz', 'nc\.exe', 'ncat', 'psexec', 'powershell.*-enc',
    'cmd.*\/c', 'wmic.*shadowcopy', 'vssadmin.*delete',
    'certutil.*-urlcache', 'bitsadmin.*\/transfer',
    'mshta.*http', 'regsvr32.*http', 'rundll32.*http'
)

# =============================================================================
# RUNTIME STATE
# =============================================================================

$script:Config = @{
    ServerUrl    = $ServerUrl
    AgentId      = $null
    AuthToken    = if ($Token) { $Token } else { $null }
    Interval     = $Interval
    ScanInterval = $ScanInterval
    DevMode      = $DevMode.IsPresent
    InstallDate  = (Get-Date).ToString("o")
}

# =============================================================================
# DOT-SOURCE MODULES
# =============================================================================

$modulePath = Join-Path $PSScriptRoot "modules"

. (Join-Path $modulePath "CBUP-Logging.ps1")
. (Join-Path $modulePath "CBUP-Registry.ps1")
. (Join-Path $modulePath "CBUP-API.ps1")
. (Join-Path $modulePath "CBUP-Discovery.ps1")
. (Join-Path $modulePath "CBUP-Telemetry.ps1")
. (Join-Path $modulePath "CBUP-EDR-Process.ps1")
. (Join-Path $modulePath "CBUP-EDR-Service.ps1")
. (Join-Path $modulePath "CBUP-EDR-Port.ps1")
. (Join-Path $modulePath "CBUP-EDR-Autorun.ps1")
. (Join-Path $modulePath "CBUP-EDR-Vulnerability.ps1")
. (Join-Path $modulePath "CBUP-EDR-Full.ps1")
. (Join-Path $modulePath "CBUP-C2Commands.ps1")
. (Join-Path $modulePath "CBUP-Service.ps1")
. (Join-Path $modulePath "CBUP-Registration.ps1")
. (Join-Path $modulePath "CBUP-Signature.ps1")

function Start-AgentLoop {
    <#
    .SYNOPSIS
        Main agent execution loop. Runs until shutdown is requested.
    #>
    Write-CBUPLog "============================================"
    Write-CBUPLog " CBUP Agent v$($script:AgentVersion) starting"
    Write-CBUPLog " Hostname: $env:COMPUTERNAME"
    Write-CBUPLog " PID: $PID"
    Write-CBUPLog " Server: $($script:Config.ServerUrl)"
    Write-CBUPLog " Telemetry Interval: $($script:Config.Interval)s"
    Write-CBUPLog " EDR Scan Interval: $(if ($script:Config.ScanInterval -gt 0) { "$($script:Config.ScanInterval)min" } else { "Disabled" })"
    Write-CBUPLog " Mode: $(if ($script:Config.DevMode) { "Development" } else { "Production" })"
    Write-CBUPLog "============================================"

    # Register shutdown handlers
    Register-ShutdownHandlers

    # Initialize timing
    $script:LastTelemetryTime = [datetime]::UtcNow
    $script:LastScanTime = [datetime]::UtcNow
    $script:LastCommandPoll = [datetime]::UtcNow

    $heartbeatFailureCount = 0
    $commandFailureCount = 0

    # Main loop
    while (-not $script:ShutdownRequested) {
        $now = [datetime]::UtcNow

        # --- Heartbeat / Telemetry ---
        if (($now - $script:LastTelemetryTime).TotalSeconds -ge $script:Config.Interval) {
            try {
                $success = Send-Heartbeat
                if ($success) {
                    $heartbeatFailureCount = 0
                }
                else {
                    $heartbeatFailureCount++
                    if ($heartbeatFailureCount -ge 5) {
                        Write-CBUPLog "Heartbeat failed $heartbeatFailureCount consecutive times. Will retry registration." -Level WARN
                        $reReg = Register-Agent
                        if ($reReg) { $heartbeatFailureCount = 0 }
                    }
                }
            }
            catch {
                Write-CBUPLog "Heartbeat error: $_" -Level ERROR
            }
            $script:LastTelemetryTime = $now
        }

        # --- Command Polling ---
        if (($now - $script:LastCommandPoll).TotalSeconds -ge $script:CommandPollInterval) {
            try {
                $commands = Get-PendingCommands
                foreach ($cmd in $commands) {
                    Invoke-C2Command -Command $cmd
                }
                $commandFailureCount = 0
            }
            catch {
                $commandFailureCount++
                Write-CBUPLog "Command poll error: $_" -Level ERROR
            }
            $script:LastCommandPoll = $now
        }

        # --- Scheduled EDR Scan ---
        if ($script:Config.ScanInterval -gt 0 -and ($now - $script:LastScanTime).TotalMinutes -ge $script:Config.ScanInterval) {
            try {
                Write-CBUPLog "Running scheduled EDR scan..."
                $scanResults = Invoke-FullEDRScan
                $apiResponse = Invoke-CBUPApi -Method POST -Endpoint "/api/agents/edr-scan" -Body $scanResults -UseCompression
                if ($null -ne $apiResponse) {
                    Write-CBUPLog "Scheduled EDR scan results submitted. Findings=$($scanResults.TotalFindings)"
                }
                else {
                    Write-CBUPLog "Failed to submit EDR scan results to portal." -Level WARN
                }
            }
            catch {
                Write-CBUPLog "Scheduled EDR scan error: $_" -Level ERROR
            }
            $script:LastScanTime = $now
        }

        # --- Status Display (Dev Mode) ---
        Show-AgentStatus

        # --- Sleep with shutdown check ---
        for ($i = 0; $i -lt 5; $i++) {
            if ($script:ShutdownRequested) { break }
            Start-Sleep -Seconds 1
        }
    }

    Write-CBUPLog "Agent loop terminated. Shutting down."
}

# =============================================================================
# ENTRY POINT
# =============================================================================

try {
    # Initialize logging
    Initialize-Logging

    # Handle uninstall
    if ($Uninstall) {
        Write-CBUPLog "Uninstall requested via command line."
        Invoke-AgentUninstall
        exit 0
    }

    # Load existing configuration from registry
    Get-RegistryConfig

    # Override with command-line parameters
    if ($ServerUrl) { $script:Config.ServerUrl = $ServerUrl }
    if ($Interval -ne 30) { $script:Config.Interval = $Interval }
    if ($ScanInterval -ne 60) { $script:Config.ScanInterval = $ScanInterval }
    if ($Token) { $script:Config.AuthToken = $Token }
    if ($DevMode) { $script:Config.DevMode = $true }

    # Validate ServerUrl
    if (-not $script:Config.ServerUrl) {
        Write-CBUPLog "No ServerUrl specified. Use -ServerUrl parameter." -Level ERROR
        throw "ServerUrl is required. Use -ServerUrl <url> to specify the CBUP portal URL."
    }

    # Validate URL format
    try {
        $uri = [System.Uri]$script:Config.ServerUrl
        if (-not ($uri.Scheme -eq "http" -or $uri.Scheme -eq "https")) {
            throw "Invalid scheme"
        }
    }
    catch {
        Write-CBUPLog "Invalid ServerUrl format: $($script:Config.ServerUrl)" -Level ERROR
        throw "Invalid ServerUrl. Must be a valid HTTP/HTTPS URL."
    }

    # Install mode
    if ($Install) {
        Install-CBUPAgentService

        # Start the service after installation
        try {
            $svc = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
            if ($svc) {
                Start-Service -Name $script:ServiceName -ErrorAction Stop
                Write-CBUPLog "Service started successfully."
            }
            else {
                # Started via scheduled task
                Start-ScheduledTask -TaskName $script:ServiceName -ErrorAction Stop
                Write-CBUPLog "Scheduled task started successfully."
            }
        }
        catch {
            Write-CBUPLog "Failed to start service/task: $_" -Level WARN
        }

        # Register with portal
        Register-Agent
        Write-CBUPLog "Installation complete. Agent is running."
        exit 0
    }

    # Running mode (service or standalone)
    Write-CBUPLog "Starting CBUP Agent..."

    # Register if no AgentId
    if (-not $script:Config.AgentId) {
        $registered = Register-Agent
        if (-not $registered) {
            Write-CBUPLog "Registration failed. Retrying in 30 seconds..." -Level WARN
            Start-Sleep -Seconds 30
            $registered = Register-Agent
            if (-not $registered) {
                Write-CBUPLog "Registration failed after retry. Exiting." -Level ERROR
                exit 1
            }
        }
    }

    # Enter main loop
    Start-AgentLoop

    exit 0
}
catch {
    Write-CBUPLog "FATAL ERROR: $_" -Level ERROR
    Write-CBUPLog "Stack Trace: $($_.ScriptStackTrace)" -Level ERROR
    exit 1
}
