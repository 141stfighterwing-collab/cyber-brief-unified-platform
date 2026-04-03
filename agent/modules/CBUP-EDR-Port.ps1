# =============================================================================
# CBUP-EDR-Port.ps1
# Module: EDR port scanning for CBUP Agent.
# Scans all listening TCP and UDP ports, flagging suspicious ports and
# uncommon privileged port usage.
# =============================================================================

function Invoke-EDRPortScan {
    <#
    .SYNOPSIS
        Scans all listening ports and flags suspicious ones.
    .OUTPUTS
        Array of port entries with flagged items.
    #>
    Write-CBUPLog "Starting EDR port scan..."
    $results = @()
    $suspiciousCount = 0

    try {
        $connections = Get-NetTCPConnection -State Listen -ErrorAction Stop
        foreach ($conn in $connections) {
            $flags = @()

            # Flag suspicious ports
            if ($conn.LocalPort -in $script:SuspiciousPorts) {
                $flags += "SUSPICIOUS_PORT"
            }

            # Flag well-known services on non-standard ports
            if ($conn.LocalPort -notin @(80, 443, 445, 135, 139, 3389, 5985, 5986, 22, 53, 88, 389, 636, 25, 587, 143, 993, 110, 995) -and $conn.LocalPort -lt 1024 -and $conn.LocalPort -notin $script:SuspiciousPorts) {
                # Any other privileged port
                $flags += "UNCOMMON_PRIVILEGED_PORT"
            }

            $processName = try { (Get-Process -Id $conn.OwningProcess -ErrorAction Stop).Name } catch { "Unknown" }

            $entry = @{
                LocalPort   = $conn.LocalPort
                LocalAddress = $conn.LocalAddress
                Protocol    = "TCP"
                PID         = $conn.OwningProcess
                ProcessName = $processName
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

        # Also check UDP listeners
        $udpListeners = Get-NetUDPEndpoint -ErrorAction SilentlyContinue
        foreach ($udp in $udpListeners) {
            $flags = @()
            if ($udp.LocalPort -in $script:SuspiciousPorts) {
                $flags += "SUSPICIOUS_PORT"
            }

            $processName = try { (Get-Process -Id $udp.OwningProcess -ErrorAction Stop).Name } catch { "Unknown" }

            $entry = @{
                LocalPort   = $udp.LocalPort
                LocalAddress = $udp.LocalAddress
                Protocol    = "UDP"
                PID         = $udp.OwningProcess
                ProcessName = $processName
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
        Write-CBUPLog "Error in port scan: $_" -Level ERROR
    }

    Write-CBUPLog "Port scan complete. Total=$($results.Count), Suspicious=$suspiciousCount"
    return @{ ScanType = "PORT"; Timestamp = [datetime]::UtcNow.ToString("o"); Results = $results; SuspiciousCount = $suspiciousCount }
}
