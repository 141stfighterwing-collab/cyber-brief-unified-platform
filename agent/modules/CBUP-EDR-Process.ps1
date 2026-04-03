# =============================================================================
# CBUP-EDR-Process.ps1
# Module: EDR process scanning for CBUP Agent.
# Scans all running processes for suspicious activity including temp directory
# execution, known malware names, and system process masquerading.
# =============================================================================

function Get-WmiProcessOwner {
    <#
    .SYNOPSIS
        Helper to get the owner of a process.
    #>
    param([int]$Pid)
    try {
        $owner = (Get-CimInstance -ClassName Win32_Process -Filter "ProcessId=$Pid" -ErrorAction Stop).GetOwner()
        return "$($owner.Domain)\$($owner.User)"
    }
    catch {
        return "N/A"
    }
}

function Invoke-EDRProcessScan {
    <#
    .SYNOPSIS
        Scans all running processes for suspicious activity.
    .OUTPUTS
        Array of process entries with flagged items.
    #>
    Write-CBUPLog "Starting EDR process scan..."
    $results = @()
    $suspiciousCount = 0

    try {
        $processes = Get-CimInstance -ClassName Win32_Process -ErrorAction Stop
        foreach ($proc in $processes) {
            $flags = @()

            # Flag: No executable path
            if ([string]::IsNullOrEmpty($proc.ExecutablePath)) {
                $flags += "NO_PATH"
            }

            # Flag: Running from temp directory
            # Bug 7a FIX: Use double backslashes for regex literal backslash matching
            if ($proc.ExecutablePath -match '\\Temp\\|\\tmp\\|AppData\\Local\\Temp') {
                $flags += "TEMP_DIR"
            }

            # Flag: Known malware/suspicious names
            foreach ($pattern in $script:SuspiciousProcessPatterns) {
                if ($proc.Name -match $pattern -or $proc.CommandLine -match $pattern) {
                    $flags += "SUSPICIOUS_NAME"
                    break
                }
            }

            # Bug 1 FIX: Added null guard for $proc.ExecutablePath before calling .StartsWith()
            if ($proc.Name -match 'svchost|lsass|csrss|smss|winlogon' -and $proc.ExecutablePath -and -not $proc.ExecutablePath.StartsWith($env:SystemRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                $flags += "SYSTEM_PROCESS_OUTSIDE_SYSTEM32"
            }

            $entry = @{
                PID         = $proc.ProcessId
                Name        = $proc.Name
                Path        = $proc.ExecutablePath
                CommandLine = $proc.CommandLine
                User        = try { $owner = $proc.GetOwner(); "$($owner.Domain)\$($owner.User)" } catch { "N/A" }
                CPU         = [math]::Round($proc.KernelModeTime / 10000000, 1)
                MemoryMB    = [math]::Round($proc.WorkingSetSize / 1MB, 1)
                Flags       = $flags
            }

            if ($flags.Count -gt 0) {
                $entry["Suspicious"] = $true
                $suspiciousCount++
            }
            else {
                $entry["Suspicious"] = $false
            }

            $results += $entry
        }
    }
    catch {
        Write-CBUPLog "Error in process scan: $_" -Level ERROR
    }

    Write-CBUPLog "Process scan complete. Total=$($results.Count), Suspicious=$suspiciousCount"
    return @{ ScanType = "PROCESS"; Timestamp = [datetime]::UtcNow.ToString("o"); Results = $results; SuspiciousCount = $suspiciousCount }
}
