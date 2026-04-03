# =============================================================================
# CBUP-EDR-Autorun.ps1
# Module: EDR autorun/persistence scanning for CBUP Agent.
# Scans registry run keys, startup folders, and scheduled tasks for suspicious
# persistence entries.
# =============================================================================

function Invoke-EDRAutorunScan {
    <#
    .SYNOPSIS
        Scans common persistence locations for suspicious autorun entries.
    .OUTPUTS
        Array of autorun entries with flagged items.
    #>
    Write-CBUPLog "Starting EDR autorun scan..."
    $results = @()
    $suspiciousCount = 0

    # Known safe autorun entries (Microsoft-signed or common software)
    $safePatterns = @(
        '^Microsoft',
        '^Intel',
        '^AMD',
        '^NVIDIA',
        '^Adobe',
        '^Google',
        '^Dropbox',
        '^OneDrive',
        '^Skype',
        '^Slack',
        '^Zoom',
        '^Teams',
        '^Apple',
        '^VMware',
        '^VirtualBox',
        '^Dell',
        '^HP',
        '^Lenovo'
    )

    # --- HKLM Run Keys ---
    $hklmPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    )

    foreach ($regPath in $hklmPaths) {
        if (Test-Path $regPath) {
            Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue |
            Get-Member -MemberType NoteProperty |
            Where-Object { $_.Name -notmatch "^PS" } |
            ForEach-Object {
                $name = $_.Name
                $value = (Get-ItemProperty -Path $regPath -Name $name -ErrorAction SilentlyContinue).$name

                $flags = @()
                $isSafe = $false
                foreach ($safe in $safePatterns) {
                    if ($name -match $safe) { $isSafe = $true; break }
                }
                if (-not $isSafe) {
                    $flags += "UNKNOWN_PUBLISHER"
                    # Check if the binary path exists and is signed
                    $exePath = if ($value -match '"([^"]+)"') { $Matches[1] } elseif ($value -match '^([^\s]+)') { $Matches[1] } else { $null }
                    if ($exePath -and (Test-Path $exePath -ErrorAction SilentlyContinue)) {
                        $sig = Get-AuthenticodeSignature -FilePath $exePath -ErrorAction SilentlyContinue
                        if ($sig.Status -ne "Valid") {
                            $flags += "UNSIGNED"
                        }
                    }
                    elseif ($exePath) {
                        $flags += "PATH_NOT_FOUND"
                    }
                }

                if ($flags.Count -gt 0) {
                    $suspiciousCount++
                }

                $results += @{
                    Location  = $regPath
                    Name      = $name
                    Value     = $value
                    Flags     = $flags
                    Suspicious = ($flags.Count -gt 0)
                }
            }
        }
    }

    # --- HKCU Run Keys ---
    $hkcuPaths = @(
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    )

    foreach ($regPath in $hkcuPaths) {
        if (Test-Path $regPath) {
            Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue |
            Get-Member -MemberType NoteProperty |
            Where-Object { $_.Name -notmatch "^PS" } |
            ForEach-Object {
                $name = $_.Name
                $value = (Get-ItemProperty -Path $regPath -Name $name -ErrorAction SilentlyContinue).$name

                $flags = @()
                $isSafe = $false
                foreach ($safe in $safePatterns) {
                    if ($name -match $safe) { $isSafe = $true; break }
                }
                if (-not $isSafe) { $flags += "UNKNOWN_PUBLISHER" }

                if ($flags.Count -gt 0) { $suspiciousCount++ }

                $results += @{
                    Location  = $regPath
                    Name      = $name
                    Value     = $value
                    Flags     = $flags
                    Suspicious = ($flags.Count -gt 0)
                }
            }
        }
    }

    # --- Startup Folder ---
    $startupFolder = [Environment]::GetFolderPath('Startup')
    if (Test-Path $startupFolder) {
        Get-ChildItem -Path $startupFolder -ErrorAction SilentlyContinue |
        ForEach-Object {
            $flags = @()
            $target = $null
            try {
                $shell = New-Object -ComObject WScript.Shell
                $shortcut = $shell.CreateShortcut($_.FullName)
                $target = $shortcut.TargetPath
            }
            catch { }

            if ($target -and -not (Test-Path $target -ErrorAction SilentlyContinue)) {
                $flags += "TARGET_MISSING"
            }

            if ($flags.Count -gt 0) { $suspiciousCount++ }

            $results += @{
                Location  = "StartupFolder"
                Name      = $_.Name
                Value     = $target
                Flags     = $flags
                Suspicious = ($flags.Count -gt 0)
            }
        }
    }

    # --- Scheduled Tasks (non-Microsoft, non-disabled) ---
    try {
        Get-ScheduledTask -ErrorAction SilentlyContinue |
            Where-Object { $_.State -ne "Disabled" -and $_.Author -notmatch "Microsoft" -and $_.TaskPath -notmatch "\\Microsoft\\" } |
            Select-Object -First 50 |
            ForEach-Object {
                $flags = @()
                $taskAction = ($_.Actions | Select-Object -First 1).Execute

                if ($taskAction -match '\.ps1|\.bat|\.cmd|\.vbs|\.js') {
                    $flags += "SCRIPT_TASK"
                }

                if ($flags.Count -gt 0) { $suspiciousCount++ }

                $results += @{
                    Location  = "ScheduledTask"
                    Name      = $_.TaskName
                    Value     = $taskAction
                    Flags     = $flags
                    Suspicious = ($flags.Count -gt 0)
                }
            }
    }
    catch {
        Write-CBUPLog "Error scanning scheduled tasks: $_" -Level WARN
    }

    Write-CBUPLog "Autorun scan complete. Total=$($results.Count), Suspicious=$suspiciousCount"
    return @{ ScanType = "AUTORUN"; Timestamp = [datetime]::UtcNow.ToString("o"); Results = $results; SuspiciousCount = $suspiciousCount }
}
