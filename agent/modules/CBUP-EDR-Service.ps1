# =============================================================================
# CBUP-EDR-Service.ps1
# Module: EDR service scanning for CBUP Agent.
# Scans all Windows services for suspicious configurations including unsigned
# binaries, auto-start stopped services, unusual paths, and script-based services.
# =============================================================================

function Invoke-EDRServiceScan {
    <#
    .SYNOPSIS
        Scans all Windows services for suspicious configurations.
    .OUTPUTS
        Array of service entries with flagged items.
    #>
    Write-CBUPLog "Starting EDR service scan..."
    $results = @()
    $suspiciousCount = 0

    try {
        $services = Get-CimInstance -ClassName Win32_Service -ErrorAction Stop
        foreach ($svc in $services) {
            $flags = @()

            # Flag: Non-Microsoft unsigned binary
            if ($svc.PathName -and (Test-Path $svc.PathName.Trim('"'))) {
                $sig = Get-AuthenticodeSignature -FilePath $svc.PathName.Trim('"') -ErrorAction SilentlyContinue
                if ($sig.Status -ne "Valid" -and $svc.PathName -notmatch "svchost\.exe|dllhost\.exe") {
                    $flags += "UNSIGNED_BINARY"
                }
            }

            # Flag: Auto-start but currently stopped
            if ($svc.StartMode -eq "Auto" -and $svc.State -ne "Running") {
                $flags += "AUTO_START_STOPPED"
            }

            # Bug 7b FIX: Use double backslashes for regex literal backslash matching
            if ($svc.PathName -and $svc.PathName -match '\\Temp\\|\\Users\\' -and $svc.PathName -notmatch 'svchost') {
                $flags += "UNUSUAL_PATH"
            }

            # Flag: Services with suspicious binary paths
            if ($svc.PathName -match '\.bat|\.cmd|\.ps1|\.vbs|\.js' -and $svc.StartMode -eq "Auto") {
                $flags += "SCRIPT_AS_SERVICE"
            }

            $entry = @{
                Name           = $svc.Name
                DisplayName    = $svc.DisplayName
                State          = $svc.State
                StartMode      = $svc.StartMode
                PathName       = $svc.PathName
                ProcessId      = $svc.ProcessId
                Flags          = $flags
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
        Write-CBUPLog "Error in service scan: $_" -Level ERROR
    }

    Write-CBUPLog "Service scan complete. Total=$($results.Count), Suspicious=$suspiciousCount"
    return @{ ScanType = "SERVICE"; Timestamp = [datetime]::UtcNow.ToString("o"); Results = $results; SuspiciousCount = $suspiciousCount }
}
