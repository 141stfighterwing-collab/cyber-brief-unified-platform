# =============================================================================
# CBUP-C2Commands.ps1
# Module: Command-and-control (C2) command handler for CBUP Agent.
# Processes remote commands from the CBUP portal including EDR scans, script
# execution, file collection, process management, and agent updates.
# =============================================================================

function Send-CommandResult {
    <#
    .SYNOPSIS
        Sends the result of a C2 command execution to the portal.
    .PARAMETER CommandId
        The unique command ID from the portal.
    .PARAMETER Status
        Execution status: SUCCESS, FAILED, TIMEOUT.
    .PARAMETER Output
        Command output or result data.
    .PARAMETER Error
        Error message if command failed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandId,

        [Parameter(Mandatory)]
        [ValidateSet("SUCCESS", "FAILED", "TIMEOUT")]
        [string]$Status,

        [Parameter()]
        $Output = $null,

        [Parameter()]
        [string]$Error = $null
    )

    $result = @{
        commandId = $CommandId
        agentId   = $script:Config.AgentId
        status    = $Status
        timestamp = [datetime]::UtcNow.ToString("o")
    }

    if ($Output -ne $null) { $result["output"] = $Output }
    if ($Error)            { $result["error"]  = $Error  }

    $response = Invoke-CBUPApi -Method POST -Endpoint "/api/agents/command-result" -Body $result -UseCompression
    if ($null -eq $response) {
        Write-CBUPLog "Failed to send command result for $CommandId" -Level ERROR
    }
}

function Resolve-CommandTargetProcess {
    <#
    .SYNOPSIS
        Resolves a C2 command target (PID or process name) to a list of PIDs.
    #>
    param([string]$Target)

    $pids = @()
    if ($Target -match '^\d+$') {
        # PID specified directly
        $pids += [int]$Target
    }
    else {
        # Process name - find matching PIDs
        Get-Process -Name $Target -ErrorAction SilentlyContinue |
            ForEach-Object { $pids += $_.Id }
    }
    return $pids
}

function Invoke-C2Command {
    <#
    .SYNOPSIS
        Executes a single C2 command from the portal.
    .PARAMETER Command
        Command object from the portal with id, type, and parameters.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Command
    )

    $commandId = $Command.id
    $commandType = $Command.type
    $params = if ($Command.parameters) { $Command.parameters } else { @{} }

    Write-CBUPLog "Executing C2 command: $commandType (ID=$commandId)"

    try {
        switch ($commandType) {
            # ---------------------------------------------------------------
            # PING - Connectivity test
            # ---------------------------------------------------------------
            "PING" {
                Send-CommandResult -CommandId $commandId -Status SUCCESS -Output @{
                    message   = "PONG"
                    version   = $script:AgentVersion
                    timestamp = [datetime]::UtcNow.ToString("o")
                    uptime    = ((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).TotalSeconds
                }
            }

            # ---------------------------------------------------------------
            # RUN_EDR_SCAN - Trigger EDR scan
            # ---------------------------------------------------------------
            "RUN_EDR_SCAN" {
                $scanTypes = if ($params.scanType) { @($params.scanType) } else { @("PROCESS", "SERVICE", "PORT", "AUTORUN", "VULNERABILITY") }

                Write-CBUPLog "EDR scan requested: $($scanTypes -join ', ')"
                $allResults = @()

                foreach ($scanType in $scanTypes) {
                    $scanResult = switch ($scanType) {
                        "PROCESS"      { Invoke-EDRProcessScan }
                        "SERVICE"      { Invoke-EDRServiceScan }
                        "PORT"         { Invoke-EDRPortScan }
                        "AUTORUN"      { Invoke-EDRAutorunScan }
                        "VULNERABILITY" { Invoke-EDRVulnerabilityScan }
                        default { @{ ScanType = $scanType; Error = "Unknown scan type"; Results = @() } }
                    }
                    $allResults += $scanResult
                }

                # Submit to portal
                $edrPayload = @{
                    agentId   = $script:Config.AgentId
                    timestamp = [datetime]::UtcNow.ToString("o")
                    scans     = $allResults
                }
                $apiResponse = Invoke-CBUPApi -Method POST -Endpoint "/api/agents/edr-scan" -Body $edrPayload -UseCompression
                Send-CommandResult -CommandId $commandId -Status SUCCESS -Output @{
                    message = "EDR scan completed"
                    scans   = $allResults | ForEach-Object { @{ type = $_.ScanType; findings = $_.SuspiciousCount } }
                }
            }

            # ---------------------------------------------------------------
            # RUN_CUSTOM_SCRIPT - Execute arbitrary PowerShell (base64 encoded)
            # ---------------------------------------------------------------
            "RUN_CUSTOM_SCRIPT" {
                if (-not $params.script) {
                    Send-CommandResult -CommandId $commandId -Status FAILED -Error "Missing 'script' parameter"
                    return
                }

                try {
                    $scriptText = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($params.script))
                    $timeout = if ($params.timeout) { [int]$params.timeout } else { 60 }

                    Write-CBUPLog "Executing custom script (timeout=${timeout}s)" -Level WARN

                    # Run in a runspace with timeout
                    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
                    $runspace.Open()
                    $pipeline = $runspace.CreatePipeline($scriptText)

                    $asyncResult = $pipeline.BeginInvoke()

                    if ($asyncResult.AsyncWaitHandle.WaitOne([TimeSpan]::FromSeconds($timeout))) {
                        $output = $pipeline.Output.ReadToEnd()
                        $errors = $pipeline.Error.ReadToEnd()
                        $pipeline.EndInvoke($asyncResult)

                        $status = if ($errors) { "SUCCESS" } else { "SUCCESS" }
                        $resultOutput = @{ stdout = $output }
                        if ($errors) { $resultOutput["stderr"] = $errors }
                        Send-CommandResult -CommandId $commandId -Status $status -Output $resultOutput
                    }
                    else {
                        $runspace.Dispose()
                        Send-CommandResult -CommandId $commandId -Status TIMEOUT -Error "Script exceeded ${timeout}s timeout"
                    }
                }
                catch {
                    Write-CBUPLog "Custom script execution failed: $_" -Level ERROR
                    Send-CommandResult -CommandId $commandId -Status FAILED -Error $_.Exception.Message
                }
            }

            # ---------------------------------------------------------------
            # COLLECT_FILE - Retrieve a file from the agent (base64 response)
            # ---------------------------------------------------------------
            "COLLECT_FILE" {
                if (-not $params.path) {
                    Send-CommandResult -CommandId $commandId -Status FAILED -Error "Missing 'path' parameter"
                    return
                }

                $filePath = $params.path
                try {
                    if (-not (Test-Path $filePath)) {
                        Send-CommandResult -CommandId $commandId -Status FAILED -Error "File not found: $filePath"
                        return
                    }

                    $fileItem = Get-Item -Path $filePath
                    if ($fileItem.Length -gt 50MB) {
                        Send-CommandResult -CommandId $commandId -Status FAILED -Error "File too large (max 50MB): $([math]::Round($fileItem.Length / 1MB, 2))MB"
                        return
                    }

                    $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
                    $base64Content = [System.Convert]::ToBase64String($fileBytes)

                    Send-CommandResult -CommandId $commandId -Status SUCCESS -Output @{
                        path       = $filePath
                        size       = $fileItem.Length
                        base64     = $base64Content
                        hashSHA256 = (Get-FileHash -Path $filePath -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
                    }
                }
                catch {
                    Send-CommandResult -CommandId $commandId -Status FAILED -Error "Failed to collect file: $($_.Exception.Message)"
                }
            }

            # ---------------------------------------------------------------
            # KILL_PROCESS - Kill a process by PID or name
            # ---------------------------------------------------------------
            "KILL_PROCESS" {
                if (-not $params.target) {
                    Send-CommandResult -CommandId $commandId -Status FAILED -Error "Missing 'target' parameter (PID or process name)"
                    return
                }

                $pids = Resolve-CommandTargetProcess -Target $params.target
                if ($pids.Count -eq 0) {
                    Send-CommandResult -CommandId $commandId -Status FAILED -Error "No matching processes found for: $($params.target)"
                    return
                }

                $killed = @()
                $failed = @()
                foreach ($pid in $pids) {
                    try {
                        Stop-Process -Id $pid -Force -ErrorAction Stop
                        $killed += $pid
                    }
                    catch {
                        $failed += @{ pid = $pid; error = $_.Exception.Message }
                    }
                }

                Send-CommandResult -CommandId $commandId -Status SUCCESS -Output @{
                    killed = $killed
                    failed = $failed
                }
            }

            # ---------------------------------------------------------------
            # DISABLE_SERVICE - Stop and disable a service
            # ---------------------------------------------------------------
            "DISABLE_SERVICE" {
                if (-not $params.serviceName) {
                    Send-CommandResult -CommandId $commandId -Status FAILED -Error "Missing 'serviceName' parameter"
                    return
                }

                try {
                    $svc = Get-Service -Name $params.serviceName -ErrorAction Stop

                    # Stop the service if running
                    if ($svc.Status -eq "Running") {
                        Stop-Service -Name $params.serviceName -Force -ErrorAction Stop -WarningAction SilentlyContinue
                    }

                    # Set to Disabled
                    Set-Service -Name $params.serviceName -StartupType Disabled -ErrorAction Stop

                    # Verify
                    $verify = Get-Service -Name $params.serviceName -ErrorAction Stop
                    Send-CommandResult -CommandId $commandId -Status SUCCESS -Output @{
                        serviceName = $params.serviceName
                        status      = $verify.Status
                        startType   = $verify.StartType
                    }
                }
                catch {
                    Send-CommandResult -CommandId $commandId -Status FAILED -Error "Failed to disable service: $($_.Exception.Message)"
                }
            }

            # ---------------------------------------------------------------
            # BLOCK_IP - Add firewall rule to block an IP
            # ---------------------------------------------------------------
            "BLOCK_IP" {
                if (-not $params.ip) {
                    Send-CommandResult -CommandId $commandId -Status FAILED -Error "Missing 'ip' parameter"
                    return
                }

                $ruleName = "CBUP-Block-$($params.ip)-$(Get-Random -Maximum 9999)"
                try {
                    if ($params.protocol) {
                        $protocol = $params.protocol
                    }
                    else {
                        $protocol = "Any"
                    }

                    if ($params.port) {
                        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Block `
                            -RemoteAddress $params.ip -Protocol $protocol -LocalPort $params.port `
                            -ErrorAction Stop | Out-Null
                    }
                    else {
                        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Block `
                            -RemoteAddress $params.ip -Protocol $protocol `
                            -ErrorAction Stop | Out-Null
                    }

                    Send-CommandResult -CommandId $commandId -Status SUCCESS -Output @{
                        message    = "Firewall rule created"
                        ruleName   = $ruleName
                        ip         = $params.ip
                        protocol   = $protocol
                        port       = $params.port
                    }
                }
                catch {
                    Send-CommandResult -CommandId $commandId -Status FAILED -Error "Failed to create firewall rule: $($_.Exception.Message)"
                }
            }

            # ---------------------------------------------------------------
            # UPDATE_AGENT - Pull new agent version
            # ---------------------------------------------------------------
            "UPDATE_AGENT" {
                Write-CBUPLog "Agent update requested." -Level WARN

                $downloadUrl = if ($params.downloadUrl) { $params.downloadUrl } else { "$($script:Config.ServerUrl)/api/agents/download" }
                $targetVersion = $params.version

                try {
                    # Download new agent script
                    $tempPath = "$env:ProgramData\CBUP\update\CBUP-Agent.new.ps1"
                    $updateDir = Split-Path -Parent $tempPath
                    if (-not (Test-Path $updateDir)) {
                        New-Item -ItemType Directory -Path $updateDir -Force | Out-Null
                    }

                    $headers = New-ApiHeaders
                    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempPath -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 120

                    if (-not (Test-Path $tempPath)) {
                        throw "Downloaded file not found"
                    }

                    # Verify file has content
                    $fileSize = (Get-Item $tempPath).Length
                    if ($fileSize -lt 1KB) {
                        throw "Downloaded file too small ($fileSize bytes)"
                    }

                    # Backup current script
                    $currentScript = $MyInvocation.PSCommandPath
                    if ($currentScript -and (Test-Path $currentScript)) {
                        $backupPath = "$env:ProgramData\CBUP\backup\CBUP-Agent.$([datetime]::Now.ToString('yyyyMMdd-HHmmss')).ps1"
                        $backupDir = Split-Path -Parent $backupPath
                        if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
                        Copy-Item -Path $currentScript -Destination $backupPath -Force
                    }

                    # Replace with new version
                    Copy-Item -Path $tempPath -Destination $currentScript -Force
                    Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue

                    Send-CommandResult -CommandId $commandId -Status SUCCESS -Output @{
                        message = "Agent updated successfully. Restart required."
                        version = $targetVersion
                    }

                    # Schedule restart
                    $script:ShutdownRequested = $true
                }
                catch {
                    Send-CommandResult -CommandId $commandId -Status FAILED -Error "Update failed: $($_.Exception.Message)"
                }
            }

            # ---------------------------------------------------------------
            # RESTART_AGENT - Restart the agent
            # ---------------------------------------------------------------
            "RESTART_AGENT" {
                Write-CBUPLog "Agent restart requested by portal." -Level WARN
                Send-CommandResult -CommandId $commandId -Status SUCCESS -Output @{ message = "Restarting agent..." }
                $script:ShutdownRequested = $true
                # Trigger actual restart via scheduled task (after short delay)
                Start-Sleep -Seconds 3
                try {
                    if (Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue) {
                        Restart-Service -Name $script:ServiceName -Force -ErrorAction Stop
                    }
                }
                catch { }
            }

            # ---------------------------------------------------------------
            # UNINSTALL_AGENT - Uninstall the agent
            # ---------------------------------------------------------------
            "UNINSTALL_AGENT" {
                Write-CBUPLog "Agent uninstall requested by portal." -Level WARN
                Send-CommandResult -CommandId $commandId -Status SUCCESS -Output @{ message = "Uninstalling agent..." }
                Invoke-AgentUninstall
            }

            # ---------------------------------------------------------------
            # Unknown command
            # ---------------------------------------------------------------
            default {
                Send-CommandResult -CommandId $commandId -Status FAILED -Error "Unknown command type: $commandType"
            }
        }
    }
    catch {
        Write-CBUPLog "Unhandled error executing command $commandType ($commandId): $_" -Level ERROR
        try {
            Send-CommandResult -CommandId $commandId -Status FAILED -Error "Unhandled: $($_.Exception.Message)"
        }
        catch { }
    }
}

function Get-PendingCommands {
    <#
    .SYNOPSIS
        Polls the CBUP portal for pending C2 commands.
    #>
    $response = Invoke-CBUPApi -Method GET -Endpoint "/api/agents/commands"

    if ($null -eq $response) {
        return @()
    }

    # Handle both array and single command response
    if ($response -is [System.Array]) {
        return $response
    }
    elseif ($response.commands -is [System.Array]) {
        return $response.commands
    }
    elseif ($response.id) {
        return @($response)
    }

    return @()
}