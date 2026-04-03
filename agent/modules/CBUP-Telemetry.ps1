# =============================================================================
# CBUP-Telemetry.ps1
# Module: Real-time system performance telemetry collection for CBUP Agent.
# Gathers CPU, memory, disk, network, process, and service metrics.
# =============================================================================

function Get-TelemetryData {
    <#
    .SYNOPSIS
        Collects real-time system performance telemetry.
    .OUTPUTS
        Hashtable with all telemetry fields.
    #>
    $telemetry = @{
        Timestamp = [datetime]::UtcNow.ToString("o")
    }

    try {
        # --- CPU Usage ---
        $cpuCounters = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop
        $cpuPerCore = @()
        $totalLoad = 0
        foreach ($cpu in $cpuCounters) {
            $cpuPerCore += @{
                Name    = $cpu.Name
                Load    = $cpu.LoadPercentage
                Cores   = $cpu.NumberOfCores
            }
            $totalLoad += $cpu.LoadPercentage
        }
        $telemetry["CPUPerCore"] = $cpuPerCore
        $telemetry["CPUTotalPercent"] = if ($cpuCounters.Count -gt 0) { [math]::Round($totalLoad / $cpuCounters.Count, 1) } else { 0 }

        # --- Memory Usage ---
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $freeGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $usedGB  = [math]::Round($totalGB - $freeGB, 2)
        $telemetry["Memory"] = @{
            TotalGB        = $totalGB
            UsedGB         = $usedGB
            FreeGB         = $freeGB
            UsedPercent    = [math]::Round(($usedGB / $totalGB) * 100, 1)
            AvailableGB    = $freeGB
            CommittedBytes = [math]::Round($os.SizeStoredInPagingFiles / 1GB, 2)
        }

        # --- Disk I/O and Space ---
        $diskMetrics = @()
        Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction Stop |
            Where-Object { $_.DriveType -eq 3 } |
            ForEach-Object {
                $freePct = if ($_.Size -gt 0) { [math]::Round(($_.FreeSpace / $_.Size) * 100, 1) } else { 0 }
                $diskMetrics += @{
                    DriveLetter = $_.DeviceID
                    FreeSpaceGB = [math]::Round($_.FreeSpace / 1GB, 2)
                    UsedSpaceGB = [math]::Round(($_.Size - $_.FreeSpace) / 1GB, 2)
                    TotalSpaceGB = [math]::Round($_.Size / 1GB, 2)
                    UsedPercent  = [math]::Round(100 - $freePct, 1)
                    FreePercent  = $freePct
                }
            }
        $telemetry["Disks"] = $diskMetrics

        # --- Network Throughput (requires perfmon counters) ---
        $networkMetrics = @()
        try {
            Get-CimInstance -ClassName Win32_PerfFormattedData_Tcpip_NetworkInterface -ErrorAction Stop |
                ForEach-Object {
                    $networkMetrics += @{
                        Name           = $_.Name
                        BytesSentPerSec  = $_.BytesSentPersec
                        BytesRecvPerSec  = $_.BytesReceivedPersec
                        CurrentBandwidth = $_.CurrentBandwidth
                    }
                }
        }
        catch {
            # Perfmon data may not be available immediately
            Write-CBUPLog "Network perfmon counters unavailable: $_" -Level DEBUG
        }
        $telemetry["Network"] = $networkMetrics

        # --- Top 5 Processes by CPU ---
        $topCpu = @()
        Get-CimInstance -ClassName Win32_Process -ErrorAction Stop |
            Sort-Object -Property CPU -Descending |
            Select-Object -First 5 |
            ForEach-Object {
                $topCpu += @{
                    Name      = $_.Name
                    PID       = $_.ProcessId
                    CPU       = [math]::Round($_.CPU, 1)
                    MemoryMB  = [math]::Round($_.WorkingSetSize / 1MB, 1)
                }
            }
        $telemetry["TopProcessesByCPU"] = $topCpu

        # --- Top 5 Processes by Memory ---
        $topMem = @()
        Get-CimInstance -ClassName Win32_Process -ErrorAction Stop |
            Sort-Object -Property WorkingSetSize -Descending |
            Select-Object -First 5 |
            ForEach-Object {
                $topMem += @{
                    Name      = $_.Name
                    PID       = $_.ProcessId
                    CPU       = [math]::Round($_.CPU, 1)
                    MemoryMB  = [math]::Round($_.WorkingSetSize / 1MB, 1)
                }
            }
        $telemetry["TopProcessesByMemory"] = $topMem

        # --- Active TCP Connections ---
        $tcpCount = 0
        try {
            $tcpCount = (Get-NetTCPConnection -ErrorAction Stop | Measure-Object).Count
        }
        catch {
            $tcpCount = 0
        }
        $telemetry["ActiveTCPConnections"] = $tcpCount

        # --- System Uptime ---
        $uptime = (Get-Date) - $os.LastBootUpTime
        $telemetry["UptimeSeconds"] = [math]::Round($uptime.TotalSeconds)
        $telemetry["UptimeHuman"]   = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"

        # --- Process Count ---
        $telemetry["ProcessCount"] = (Get-CimInstance -ClassName Win32_Process -ErrorAction Stop | Measure-Object).Count

        # --- Service Count (running) ---
        $telemetry["RunningServices"] = (Get-CimInstance -ClassName Win32_Service -ErrorAction Stop | Where-Object { $_.State -eq "Running" } | Measure-Object).Count
    }
    catch {
        Write-CBUPLog "Error collecting telemetry: $_" -Level ERROR
    }

    return $telemetry
}
