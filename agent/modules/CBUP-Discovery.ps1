# =============================================================================
# CBUP-Discovery.ps1
# Module: System inventory discovery for CBUP Agent.
# Collects comprehensive hardware, OS, network, disk, and user information
# during agent registration.
# =============================================================================

function Get-SystemDiscoveryData {
    <#
    .SYNOPSIS
        Collects comprehensive system inventory (runs once at install).
    .OUTPUTS
        Hashtable with all system discovery fields.
    #>
    Write-CBUPLog "Collecting system discovery data..."
    $discovery = @{}

    try {
        # --- OS Information ---
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $discovery["Hostname"]       = $osInfo.CSName
        $discovery["Domain"]         = if ($osInfo.PartOfDomain) { $osInfo.Domain } else { "WORKGROUP" }
        $discovery["OSName"]         = $osInfo.Caption
        $discovery["OSVersion"]      = $osInfo.Version
        $discovery["OSArchitecture"] = $osInfo.OSArchitecture
        $discovery["InstallDate"]    = $osInfo.InstallDate.ToString("o")
        $discovery["LastBootTime"]   = $osInfo.LastBootUpTime.ToString("o")
        $discovery["TotalRAM_GB"]    = [math]::Round($osInfo.TotalVisibleMemorySize / 1MB, 2)

        # --- Computer System ---
        $csInfo = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $discovery["Manufacturer"] = $csInfo.Manufacturer
        $discovery["Model"]        = $csInfo.Model
        $discovery["SystemType"]   = $csInfo.SystemType
        $discovery["NumberOfProcessors"] = $csInfo.NumberOfProcessors
        $discovery["NumberOfLogicalProcessors"] = $csInfo.NumberOfLogicalProcessors

        # --- Serial Number / BIOS ---
        $biosInfo = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
        $discovery["SerialNumber"]  = $biosInfo.SerialNumber
        $discovery["BIOSVersion"]   = "$($biosInfo.SMBIOSBIOSVersion) ($($biosInfo.ReleaseDate.ToString('yyyy-MM-dd')))"
        $discovery["ServiceTag"]    = try { $biosInfo.SerialNumber } catch { "N/A" }

        # --- CPU ---
        $cpuInfo = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $discovery["CPUModel"]      = $cpuInfo.Name
        $discovery["CPUCores"]      = $cpuInfo.NumberOfCores
        $discovery["CPUSpeed_MHz"]  = $cpuInfo.MaxClockSpeed

        # --- Network Adapters ---
        $adapters = @()
        Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -ErrorAction Stop |
            Where-Object { $_.IPEnabled -eq $true } |
            ForEach-Object {
                $adapters += @{
                    Description = $_.Description
                    MACAddress  = $_.MACAddress
                    IPAddress   = @($_.IPAddress) -join ", "
                    DefaultGateway = @($_.DefaultIPGateway) -join ", "
                    DHCPEnabled = $_.DHCPEnabled
                }
            }
        $discovery["NetworkAdapters"] = $adapters

        # --- Disk Volumes ---
        $disks = @()
        Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction Stop |
            Where-Object { $_.DriveType -eq 3 } |
            ForEach-Object {
                $disks += @{
                    DriveLetter = $_.DeviceID
                    FileSystem  = $_.FileSystem
                    TotalGB     = [math]::Round($_.Size / 1GB, 2)
                    FreeGB      = [math]::Round($_.FreeSpace / 1GB, 2)
                }
            }
        $discovery["Disks"] = $disks

        # --- Logged-in Users ---
        $users = @()
        Get-CimInstance -ClassName Win32_LoggedOnUser -ErrorAction Stop |
            ForEach-Object {
                $users += $_.Antecedent -replace '.*Domain="', '' -replace '".*Name="', '\' -replace '".*'
            }
        $discovery["LoggedInUsers"] = $users

        # --- TimeZone ---
        $discovery["TimeZone"] = (Get-TimeZone).Id
        $discovery["UTCOffset"] = (Get-TimeZone).BaseUtcOffset.ToString()

        Write-CBUPLog "System discovery completed. Hostname=$($discovery['Hostname']), OS=$($discovery['OSName'])"
    }
    catch {
        Write-CBUPLog "Error during system discovery: $_" -Level ERROR
    }

    return $discovery
}
