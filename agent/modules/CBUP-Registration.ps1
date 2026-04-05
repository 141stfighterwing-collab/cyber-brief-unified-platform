# =============================================================================
# CBUP-Registration.ps1
# Module: Agent registration, heartbeat, shutdown handlers, and status display.
# Handles initial registration with the CBUP portal and periodic telemetry.
#
# Security hardening (v2.2.0):
#   - AuthToken encrypted with DPAPI before registry storage
# =============================================================================

function Register-Agent {
    <#
    .SYNOPSIS
        Registers the agent with the CBUP portal and obtains an Agent ID + Auth Token.
    #>
    Write-CBUPLog "Registering agent with CBUP portal..."

    $discoveryData = Get-SystemDiscoveryData
    $registrationPayload = @{
        version        = $script:AgentVersion
        hostname       = $discoveryData["Hostname"]
        discovery      = $discoveryData
        interval       = $script:Config.Interval
        scanInterval   = $script:Config.ScanInterval
        capabilities   = @("TELEMETRY", "EDR_PROCESS", "EDR_SERVICE", "EDR_PORT", "EDR_AUTORUN", "EDR_VULNERABILITY", "C2_SCRIPT", "C2_KILL", "C2_SERVICE", "C2_FIREWALL", "C2_FILE")
    }

    if ($script:Config.AuthToken) {
        $registrationPayload["token"] = $script:Config.AuthToken
    }

    $response = Invoke-CBUPApi -Method POST -Endpoint "/api/agents/register" -Body $registrationPayload -UseCompression

    if ($null -eq $response) {
        Write-CBUPLog "Agent registration failed. No response from server." -Level ERROR
        return $false
    }

    # Store credentials
    if ($response.agentId) {
        $script:Config.AgentId = $response.agentId
    }
    if ($response.token -or $response.authToken) {
        $script:Config.AuthToken = $response.token ?? $response.authToken
    }

    # ── SECURITY: Encrypt AuthToken before persisting to registry (v2.2.0) ──
    $encryptedAuthToken = $null
    if ($script:Config.AuthToken) {
        try {
            $encryptedAuthToken = Protect-RegistryValue -Plaintext $script:Config.AuthToken
            Write-CBUPLog "AuthToken encrypted for registry storage." -Level DEBUG
        }
        catch {
            Write-CBUPLog "Failed to encrypt AuthToken, storing as plaintext (fallback): $_" -Level WARN
            $encryptedAuthToken = $script:Config.AuthToken
        }
    }

    # Persist to registry (with encrypted AuthToken)
    Set-RegistryConfig -Settings @{
        ServerUrl    = $script:Config.ServerUrl
        AgentId      = $script:Config.AgentId
        AuthToken    = $encryptedAuthToken
        Interval     = $script:Config.Interval
        ScanInterval = $script:Config.ScanInterval
        InstallDate  = $script:Config.InstallDate
        AgentVersion = $script:AgentVersion
    }

    Write-CBUPLog "Agent registered successfully. AgentId=$($script:Config.AgentId)"
    return $true
}

function Send-Heartbeat {
    <#
    .SYNOPSIS
        Sends telemetry data as a heartbeat to the portal.
    #>
    $telemetry = Get-TelemetryData
    $telemetry["AgentId"] = $script:Config.AgentId
    $telemetry["Version"] = $script:AgentVersion

    $response = Invoke-CBUPApi -Method POST -Endpoint "/api/agents/heartbeat" -Body $telemetry -UseCompression

    if ($null -ne $response) {
        Write-CBUPLog "Heartbeat sent. CPU=$($telemetry.CPUTotalPercent)%, RAM=$($telemetry.Memory.UsedPercent)%, Processes=$($telemetry.ProcessCount)" -Level DEBUG
    }

    return $null -ne $response
}

# =============================================================================
# GRACEFUL SHUTDOWN HANDLER
# =============================================================================

function Register-ShutdownHandlers {
    <#
    .SYNOPSIS
        Registers event handlers for graceful service shutdown.
    #>
    $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        $script:ShutdownRequested = $true
        Write-CBUPLog "PowerShell engine exiting. Shutting down."
    }

    # Handle Ctrl+C and service stop signals
    $null = [Console]::TreatControlCAsInput

    $job = Start-Job -ScriptBlock {
        # Watch for the agent's own process termination
        $parentPid = $PID
        try {
            while ($true) {
                Start-Sleep -Seconds 2
                if (-not (Get-Process -Id $parentPid -ErrorAction SilentlyContinue)) {
                    break
                }
            }
        }
        catch { }
    } -ArgumentList $PID

    Write-CBUPLog "Shutdown handlers registered."
}

# =============================================================================
# CONSOLE PROGRESS INDICATOR
# =============================================================================

function Show-AgentStatus {
    <#
    .SYNOPSIS
        Displays a status line in the console (dev mode).
    #>
    if (-not $script:Config.DevMode) { return }

    $status = "CBUP Agent v$($script:AgentVersion) | "
    $status += "ID: $($script:Config.AgentId) | "

    if ($script:Config.ServerUrl) {
        $status += "Server: $($script:Config.ServerUrl.Host) | "
    }

    $status += "Interval: $($script:Config.Interval)s | "
    $status += "Next scan: $(if ($script:Config.ScanInterval -gt 0) { "$($script:Config.ScanInterval)min" } else { "disabled" })"

    Write-Host "`r$status" -NoNewline -ForegroundColor DarkGray
}
