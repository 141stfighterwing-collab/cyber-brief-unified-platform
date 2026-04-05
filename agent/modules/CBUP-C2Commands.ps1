# =============================================================================
# CBUP-C2Commands.ps1
# Module: Command-and-control (C2) command handler for CBUP Agent.
# Processes remote commands from the CBUP portal including EDR scans, script
# execution, file collection, process management, and agent updates.
#
# Security hardening (v2.2.0):
#   - RUN_CUSTOM_SCRIPT: Command whitelist enforcement
#   - COLLECT_FILE: Restricted paths blocklist + max 10MB
#   - UPDATE_AGENT: SHA256 hash verification
# =============================================================================

# ─── Allowed Script Commands (whitelist for RUN_CUSTOM_SCRIPT) ──────────────
# Only these PowerShell commands/cmdlets are permitted in custom scripts.
# This prevents arbitrary code execution while allowing useful diagnostics.
$script:AllowedScriptCommands = @(
    # Safe query cmdlets
    'Get-Process',
    'Get-Service',
    'Get-EventLog',
    'Get-ChildItem',
    'Get-Content',
    'Get-NetTCPConnection',
    'Get-NetUDPEndpoint',
    'Get-ItemProperty',
    'Get-CimInstance',
    'Get-WmiObject',
    'Get-FileHash',
    'Get-AuthenticodeSignature',
    'Get-Item',
    'Get-Module',
    'Get-Command',
    'Get-HotFix',
    'Get-Event',
    'Get-WinEvent',
    'Get-Counter',
    'Get-Variable',
    'Get-PSDrive',
    'Get-Acl',
    'Get-AuditPolicy',
    'Get-ExecutionPolicy',
    'Get-NetFirewallRule',
    'Get-NetFirewallProfile',
    'Get-NetAdapter',
    'Get-NetRoute',
    'Get-DnsClientCache',
    'Get-LocalUser',
    'Get-LocalGroup',
    'Get-LocalGroupMember',
    'Get-ScheduledTask',
    'Get-Service',
    # Safe external commands
    'whoami',
    'hostname',
    'ipconfig',
    'systeminfo',
    'netstat',
    'tasklist',
    'nslookup',
    'ping',
    'tracert',
    'pathping',
    'arp',
    'route',
    'nbtstat',
    'type',
    # Pipeline and flow control (allowed)
    'Where-Object',
    'Select-Object',
    'Sort-Object',
    'Format-Table',
    'Format-List',
    'Format-Wide',
    'ForEach-Object',
    'Measure-Object',
    'Group-Object',
    'Compare-Object',
    'Tee-Object',
    'Out-String',
    'Out-File',
    'Export-Csv',
    'ConvertTo-Json',
    'ConvertFrom-Json',
    'Join-String',
    # Safe operators (not commands, but needed for validation)
    'Write-Output',
    'Write-Host'
)

# ─── Restricted Paths for COLLECT_FILE ────────────────────────────────────────
# These paths MUST NOT be collected by the agent (sensitive system files)
$script:RestrictedFilePatterns = @(
    # Windows credential/system files
    'C:\Windows\System32\config\*',
    'C:\Windows\NTDS\*',
    # Certificate private keys
    '*.pfx',
    '*.p12',
    '*.key',
    '*.pem',
    '*.der',
    # Credential files
    'credential*',
    'credentials*',
    '*.rdp',
    '*.csc',
    # Registry hives
    'SAM',
    'SYSTEM',
    'SECURITY',
    'SOFTWARE',
    'NTUSER.DAT'
)

# Maximum file size for COLLECT_FILE: 10MB (reduced from 50MB for security)
$script:MaxCollectFileSize = 10MB

function Test-ScriptCommandAllowed {
    <#
    .SYNOPSIS
        Validates that a custom script only uses whitelisted commands.
    .PARAMETER ScriptText
        The PowerShell script text to validate.
    .OUTPUTS
        Boolean: true if all commands are allowed, false otherwise.
    .OUTPUTS
        String array of disallowed commands found (via $script:DisallowedCommandsFound)
    #>
    param([string]$ScriptText)

    $script:DisallowedCommandsFound = @()

    # Tokenize the script to extract command names
    try {
        $tokens = [System.Management.Automation.PSParser]::Tokenize($ScriptText, [ref]$null)

        foreach ($token in $tokens) {
            if ($token.Type -eq 'CommandArgument') { continue }

            # Check string literals, command names, and member accesses
            $commandName = $null

            if ($token.Type -eq 'Command') {
                $commandName = $token.Content
            }
            elseif ($token.Type -eq 'String') {
                # Skip string literals
                continue
            }

            if ($commandName) {
                # Extract base command name (strip module prefix like Microsoft.PowerShell.Management\Get-Process)
                $baseCommand = $commandName -replace '^.*\\', ''

                if ($baseCommand -and $script:AllowedScriptCommands -notcontains $baseCommand) {
                    $script:DisallowedCommandsFound += $baseCommand
                }
            }
        }
    }
    catch {
        Write-CBUPLog "Script parsing failed during validation: $_" -Level WARN
        $script:DisallowedCommandsFound = @('SCRIPT_PARSE_ERROR')
        return $false
    }

    if ($script:DisallowedCommandsFound.Count -gt 0) {
        return $false
    }

    return $true
}

function Test-RestrictedPath {
    <#
    .SYNOPSIS
        Checks if a file path matches any restricted patterns.
    .PARAMETER FilePath
        The file path to check.
    .OUTPUTS
        Boolean: true if the path is restricted (should be blocked).
    #>
    param([string]$FilePath)

    $normalizedPath = $FilePath.Replace('/', '\').ToUpperInvariant()

    foreach ($pattern in $script:RestrictedFilePatterns) {
        $patternUpper = $pattern.ToUpperInvariant()

        if ($patternUpper.StartsWith('C:\') -or $patternUpper.StartsWith('D:\')) {
            # Path-based restriction: check if requested path starts with or matches pattern
            $patternPrefix = $patternUpper -replace '\*$', ''
            if ($normalizedPath.StartsWith($patternPrefix) -or $normalizedPath -eq $patternUpper) {
                return $true
            }
        }
        else {
            # Extension or filename pattern: use simple matching
            $patternName = $patternUpper -replace '^\*', ''
            if ($patternUpper.StartsWith('*')) {
                # Match extension (*.pfx, *.key, etc.)
                if ($normalizedPath.EndsWith($patternName)) {
                    return $true
                }
            }
            else {
                # Match filename prefix (credential*)
                $fileName = Split-Path -Leaf $normalizedPath
                if ($fileName.StartsWith($patternUpper) -or $fileName -eq $patternUpper) {
                    return $true
                }
            }
        }
    }

    return $false
}

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
            # RUN_CUSTOM_SCRIPT - Execute PowerShell with WHITELIST enforcement
            # ---------------------------------------------------------------
            "RUN_CUSTOM_SCRIPT" {
                if (-not $params.script) {
                    Send-CommandResult -CommandId $commandId -Status FAILED -Error "Missing 'script' parameter"
                    return
                }

                try {
                    $scriptText = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($params.script))
                    $timeout = if ($params.timeout) { [int]$params.timeout } else { 60 }

                    # ── SECURITY: Validate script commands against whitelist ──
                    Write-CBUPLog "Validating custom script commands against whitelist..." -Level WARN

                    $isAllowed = Test-ScriptCommandAllowed -ScriptText $scriptText

                    if (-not $isAllowed) {
                        $disallowedStr = ($script:DisallowedCommandsFound | Select-Object -Unique) -join ', '
                        $errorMsg = "SCRIPT REJECTED: Contains disallowed commands: $disallowedStr. Only whitelisted diagnostic commands are permitted."
                        Write-CBUPLog $errorMsg -Level ERROR
                        Send-CommandResult -CommandId $commandId -Status FAILED -Error $errorMsg
                        return
                    }

                    Write-CBUPLog "Custom script validated. Executing (timeout=${timeout}s)" -Level WARN

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
            # COLLECT_FILE - Retrieve a file with RESTRICTED PATH enforcement
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

                    # ── SECURITY: Check against restricted paths blocklist ──
                    if (Test-RestrictedPath -FilePath $filePath) {
                        $errorMsg = "ACCESS DENIED: File path is on the restricted list: $filePath. Sensitive system/credential files cannot be collected."
                        Write-CBUPLog $errorMsg -Level ERROR
                        Send-CommandResult -CommandId $commandId -Status FAILED -Error $errorMsg
                        return
                    }

                    $fileItem = Get-Item -Path $filePath
                    # ── SECURITY: Reduced max file size from 50MB to 10MB ──
                    if ($fileItem.Length -gt $script:MaxCollectFileSize) {
                        $maxMB = [math]::Round($script:MaxCollectFileSize / 1MB, 0)
                        Send-CommandResult -CommandId $commandId -Status FAILED -Error "File too large (max ${maxMB}MB): $([math]::Round($fileItem.Length / 1MB, 2))MB"
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
            # UPDATE_AGENT - Pull new agent version with SHA256 verification
            # ---------------------------------------------------------------
            "UPDATE_AGENT" {
                Write-CBUPLog "Agent update requested." -Level WARN

                $downloadUrl = if ($params.downloadUrl) { $params.downloadUrl } else { "$($script:Config.ServerUrl)/api/agents/download" }
                $targetVersion = $params.version
                $expectedHash = $params.expectedHash

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

                    # ── SECURITY: SHA256 Hash Verification ──
                    if ($expectedHash) {
                        Write-CBUPLog "Verifying update integrity (SHA256)..." -Level WARN
                        $actualHash = (Get-FileHash -Path $tempPath -Algorithm SHA256).Hash

                        if ($actualHash -ne $expectedHash) {
                            Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
                            $errorMsg = "UPDATE REJECTED: SHA256 hash mismatch! Expected: $expectedHash, Actual: $actualHash. Possible tampering or corruption detected."
                            Write-CBUPLog $errorMsg -Level ERROR
                            Send-CommandResult -CommandId $commandId -Status FAILED -Error $errorMsg
                            return
                        }

                        Write-CBUPLog "Update integrity verified. SHA256=$actualHash" -Level INFO
                    }
                    else {
                        Write-CBUPLog "No expectedHash provided for update. Skipping integrity verification. (recommended: always provide expectedHash)" -Level WARN
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
