# =============================================================================
# CBUP-Logging.ps1
# Module: Logging initialization and write functions for CBUP Agent.
# Provides event log source setup, log rotation, and multi-target output.
# =============================================================================

function Initialize-Logging {
    <#
    .SYNOPSIS
        Sets up event log source and log file directory.
    #>
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($script:LogSource)) {
            [System.Diagnostics.EventLog]::CreateEventSource($script:LogSource, $script:LogName)
            Write-Verbose "Created event log source: $($script:LogSource)"
        }

        $logDir = Split-Path -Parent $script:LogFilePath
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        # Rotate log if oversized
        if (Test-Path $script:LogFilePath) {
            $logItem = Get-Item $script:LogFilePath
            if ($logItem.Length -gt ($script:MaxLogSizeMB * 1MB)) {
                $archivePath = "$script:LogFilePath.$([datetime]::Now.ToString('yyyyMMdd-HHmmss')).bak"
                Move-Item -Path $script:LogFilePath -Destination $archivePath -Force
                Write-Verbose "Rotated log file to $archivePath"
                # Keep only 5 archived logs
                Get-ChildItem "$script:LogFilePath.*.bak" |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -Skip 5 |
                    Remove-Item -Force
            }
        }
    }
    catch {
        Write-Warning "Failed to initialize logging: $_"
    }
}

function Write-CBUPLog {
    <#
    .SYNOPSIS
        Writes a message to the event log and log file.
    .PARAMETER Message
        The message text.
    .PARAMETER Level
        Severity: INFO, WARN, ERROR, DEBUG.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    $timestamp = [datetime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $entry = "[$timestamp] [$Level] $Message"

    # Console output in dev mode
    if ($script:Config.DevMode) {
        switch ($Level) {
            "ERROR" { Write-Host $entry -ForegroundColor Red }
            "WARN"  { Write-Host $entry -ForegroundColor Yellow }
            "DEBUG" { Write-Host $entry -ForegroundColor Cyan }
            default { Write-Host $entry -ForegroundColor White }
        }
    }

    # File logging
    try {
        $entry | Out-File -FilePath $script:LogFilePath -Append -Encoding UTF8 -ErrorAction SilentlyContinue
    }
    catch {
        # Silent fail - logging should never crash the agent
    }

    # Windows Event Log
    try {
        $eventId = switch ($Level) {
            "ERROR" { 100 }
            "WARN"  { 200 }
            "DEBUG" { 300 }
            default { 400 }
        }
        $entryType = switch ($Level) {
            "ERROR" { [System.Diagnostics.EventLogEntryType]::Error }
            "WARN"  { [System.Diagnostics.EventLogEntryType]::Warning }
            default { [System.Diagnostics.EventLogEntryType]::Information }
        }
        Write-EventLog -LogName $script:LogName -Source $script:LogSource `
            -EntryType $entryType -EventId $eventId -Message $Message `
            -Category 0 -ErrorAction SilentlyContinue
    }
    catch {
        # Silent fail
    }
}
