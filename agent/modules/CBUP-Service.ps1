# =============================================================================
# CBUP-Service.ps1
# Module: Windows service installation and uninstallation for CBUP Agent.
# Supports NSSM-based installation and scheduled task fallback.
# =============================================================================

function Install-CBUPAgentService {
    <#
    .SYNOPSIS
        Installs the agent as a Windows service using NSSM or native service wrapper.
    #>
    Write-CBUPLog "Installing CBUP Agent as Windows service..."

    # Check for admin privileges
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-CBUPLog "Installation requires administrator privileges." -Level ERROR
        throw "Administrator privileges required for installation"
    }

    # Check if already installed
    $existingService = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
    if ($existingService) {
        Write-CBUPLog "Service already exists. Updating..." -Level WARN
        Stop-Service -Name $script:ServiceName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }

    $scriptPath = $MyInvocation.PSCommandPath
    if (-not $scriptPath) {
        $scriptPath = $PSCommandPath
    }
    if (-not $scriptPath -or -not (Test-Path $scriptPath)) {
        Write-CBUPLog "Cannot determine script path for service installation." -Level ERROR
        throw "Script path not found"
    }

    # Try NSSM first (preferred)
    $nssmPath = $null
    if (Get-Command nssm -ErrorAction SilentlyContinue) {
        $nssmPath = (Get-Command nssm).Source
    }
    else {
        $nssmCandidates = @(
            "$env:ProgramFiles\NSSM\nssm.exe",
            "${env:ProgramFiles(x86)}\NSSM\nssm.exe",
            "$env:ChocolateyInstall\bin\nssm.exe"
        )
        foreach ($candidate in $nssmCandidates) {
            if (Test-Path $candidate) {
                $nssmPath = $candidate
                break
            }
        }
    }

    if ($nssmPath) {
        Write-CBUPLog "Installing via NSSM: $nssmPath"
        try {
            if ($existingService) {
                & $nssmPath set $script:ServiceName Application "powershell.exe" | Out-Null
                & $nssmPath set $script:ServiceName AppParameters "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -ServerUrl `"$($script:Config.ServerUrl)`"" | Out-Null
            }
            else {
                & $nssmPath install $script:ServiceName "powershell.exe" "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -ServerUrl `"$($script:Config.ServerUrl)`"" | Out-Null
            }
            & $nssmPath set $script:ServiceName DisplayName $script:ServiceDisplayName | Out-Null
            & $nssmPath set $script:ServiceName Description $script:ServiceDescription | Out-Null
            & $nssmPath set $script:ServiceName Start SERVICE_AUTO_START | Out-Null
            & $nssmPath set $script:ServiceName AppStdout "$env:ProgramData\CBUP\service-stdout.log" | Out-Null
            & $nssmPath set $script:ServiceName AppStderr "$env:ProgramData\CBUP\service-stderr.log" | Out-Null
            & $nssmPath set $script:ServiceName AppRotateFiles 1 | Out-Null
            & $nssmPath set $script:ServiceName AppRotateBytes 10485760 | Out-Null

            Write-CBUPLog "NSSM installation successful."
        }
        catch {
            Write-CBUPLog "NSSM installation failed: $_. Falling back to native method." -Level WARN
            $nssmPath = $null
        }
    }

    if (-not $nssmPath) {
        # Fallback: Create a scheduled task as service
        Write-CBUPLog "Installing as Scheduled Task (no NSSM found)..."
        try {
            $taskAction = New-ScheduledTaskAction -Execute "powershell.exe" `
                -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -ServerUrl `"$($script:Config.ServerUrl)`""

            $taskTrigger = New-ScheduledTaskTrigger -AtStartup

            $taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

            $taskSettings = New-ScheduledTaskSettingsSet `
                -AllowStartIfOnBatteries `
                -DontStopIfGoingOnBatteries `
                -StartWhenAvailable `
                -RestartCount 3 `
                -RestartInterval (New-TimeSpan -Minutes 1) `
                -ExecutionTimeLimit (New-TimeSpan -Days 365)

            $existingTask = Get-ScheduledTask -TaskName $script:ServiceName -ErrorAction SilentlyContinue
            if ($existingTask) {
                Unregister-ScheduledTask -TaskName $script:ServiceName -Confirm:$false -ErrorAction SilentlyContinue
            }

            Register-ScheduledTask `
                -TaskName $script:ServiceName `
                -Action $taskAction `
                -Trigger $taskTrigger `
                -Principal $taskPrincipal `
                -Settings $taskSettings `
                -Description $script:ServiceDescription `
                -ErrorAction Stop | Out-Null

            Write-CBUPLog "Scheduled Task installation successful."
        }
        catch {
            Write-CBUPLog "Scheduled Task installation failed: $_" -Level ERROR
            throw
        }
    }

    # Persist configuration to registry
    Set-RegistryConfig -Settings @{
        ServerUrl    = $script:Config.ServerUrl
        AgentId      = $script:Config.AgentId
        AuthToken    = $script:Config.AuthToken
        Interval     = $script:Config.Interval
        ScanInterval = $script:Config.ScanInterval
        InstallDate  = $script:Config.InstallDate
        AgentVersion = $script:AgentVersion
    }

    Write-CBUPLog "CBUP Agent installation complete."
}

function Invoke-AgentUninstall {
    <#
    .SYNOPSIS
        Removes the agent service, scheduled task, and registry configuration.
    #>
    Write-CBUPLog "Uninstalling CBUP Agent..."

    # Stop service if running
    try {
        $svc = Get-Service -Name $script:ServiceName -ErrorAction SilentlyContinue
        if ($svc) {
            Stop-Service -Name $script:ServiceName -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            & sc.exe delete $script:ServiceName 2>$null
            Write-CBUPLog "Service removed."
        }
    }
    catch {
        Write-CBUPLog "Error removing service: $_" -Level WARN
    }

    # Remove scheduled task
    try {
        $task = Get-ScheduledTask -TaskName $script:ServiceName -ErrorAction SilentlyContinue
        if ($task) {
            Unregister-ScheduledTask -TaskName $script:ServiceName -Confirm:$false -ErrorAction Stop
            Write-CBUPLog "Scheduled task removed."
        }
    }
    catch {
        Write-CBUPLog "Error removing scheduled task: $_" -Level WARN
    }

    # Remove registry keys
    Remove-RegistryConfig

    # Clean up log files (optional)
    try {
        if (Test-Path "$env:ProgramData\CBUP") {
            # Archive logs before deletion
            $archiveDir = "$env:ProgramData\CBUP_uninstalled_$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Move-Item -Path "$env:ProgramData\CBUP" -Destination $archiveDir -Force -ErrorAction SilentlyContinue
            Write-CBUPLog "Data archived to $archiveDir"
        }
    }
    catch {
        Write-CBUPLog "Error archiving data: $_" -Level WARN
    }

    # Unregister event log source
    try {
        [System.Diagnostics.EventLog]::DeleteEventSource($script:LogSource)
    }
    catch { }

    Write-CBUPLog "CBUP Agent uninstallation complete."
    $script:ShutdownRequested = $true
}