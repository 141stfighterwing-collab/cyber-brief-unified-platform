# =============================================================================
# CBUP-Registry.ps1
# Module: Registry persistence for CBUP Agent configuration.
# Handles reading, writing, and removing agent settings from HKLM registry.
# =============================================================================

function Set-RegistryConfig {
    <#
    .SYNOPSIS
        Persists agent configuration to the registry.
    #>
    param(
        [hashtable]$Settings
    )

    try {
        if (-not (Test-Path $script:RegKeyPath)) {
            New-Item -Path $script:RegKeyPath -Force | Out-Null
        }
        foreach ($key in $Settings.Keys) {
            Set-ItemProperty -Path $script:RegKeyPath -Name $key -Value $Settings[$key] -Force
        }
        Write-CBUPLog "Registry configuration updated." -Level DEBUG
    }
    catch {
        Write-CBUPLog "Failed to write registry config: $_" -Level ERROR
    }
}

function Get-RegistryConfig {
    <#
    .SYNOPSIS
        Reads persisted agent configuration from the registry.
    #>
    try {
        if (Test-Path $script:RegKeyPath) {
            $props = Get-ItemProperty -Path $script:RegKeyPath
            if ($props.ServerUrl)    { $script:Config.ServerUrl    = $props.ServerUrl }
            if ($props.AgentId)      { $script:Config.AgentId      = $props.AgentId }
            if ($props.AuthToken)    { $script:Config.AuthToken    = $props.AuthToken }
            if ($props.Interval)     { $script:Config.Interval     = [int]$props.Interval }
            if ($props.ScanInterval) { $script:Config.ScanInterval = [int]$props.ScanInterval }
            if ($props.InstallDate)  { $script:Config.InstallDate  = $props.InstallDate }
            Write-CBUPLog "Loaded configuration from registry. AgentId=$($script:Config.AgentId)" -Level DEBUG
        }
    }
    catch {
        Write-CBUPLog "Failed to read registry config: $_" -Level ERROR
    }
}

function Remove-RegistryConfig {
    <#
    .SYNOPSIS
        Removes all CBUP agent registry keys.
    #>
    try {
        if (Test-Path $script:RegKeyPath) {
            Remove-Item -Path $script:RegKeyPath -Recurse -Force -ErrorAction Stop
            Write-CBUPLog "Registry configuration removed."
        }
    }
    catch {
        Write-CBUPLog "Failed to remove registry config: $_" -Level ERROR
    }
}
