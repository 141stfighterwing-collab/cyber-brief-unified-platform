# =============================================================================
# CBUP-Registry.ps1
# Module: Registry persistence for CBUP Agent configuration.
# Handles reading, writing, and removing agent settings from HKLM registry.
#
# Security hardening (v2.2.0):
#   - Added DPAPI-based encryption for sensitive values (auth tokens)
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
            if ($props.Interval)     { $script:Config.Interval     = [int]$props.Interval }
            if ($props.ScanInterval) { $script:Config.ScanInterval = [int]$props.ScanInterval }
            if ($props.InstallDate)  { $script:Config.InstallDate  = $props.InstallDate }

            # Decrypt AuthToken from registry if stored encrypted (v2.2.0+)
            if ($props.AuthToken) {
                try {
                    $decrypted = Unprotect-RegistryValue -Base64 $props.AuthToken
                    $script:Config.AuthToken = $decrypted
                    Write-CBUPLog "AuthToken decrypted from registry (DPAPI)." -Level DEBUG
                }
                catch {
                    # Fallback: if decryption fails, try using as plaintext (backward compat with pre-2.2.0)
                    Write-CBUPLog "AuthToken decryption failed, using as plaintext (legacy fallback): $_" -Level WARN
                    $script:Config.AuthToken = $props.AuthToken
                }
            }

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

# =============================================================================
# DPAPI ENCRYPTION FOR SENSITIVE REGISTRY VALUES (v2.2.0)
# =============================================================================

function Protect-RegistryValue {
    <#
    .SYNOPSIS
        Encrypts a plaintext string using Windows DPAPI (LocalMachine scope).
        Returns a base64-encoded encrypted string safe for registry storage.
    .PARAMETER Plaintext
        The plaintext string to encrypt.
    .OUTPUTS
        Base64-encoded encrypted string.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Plaintext
    )

    try {
        # Convert plaintext to UTF8 bytes
        $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($Plaintext)

        # Encrypt using DPAPI with LocalMachine scope
        # LocalMachine scope allows the encryption to be undone by any process
        # running on the same machine (appropriate for a system-level service)
        $entropy = [System.Text.Encoding]::UTF8.GetBytes("CBUP-Agent-v2.2-DPAPI")
        $encryptedBytes = [System.Security.Cryptography.ProtectedData]::Protect(
            $plainBytes,
            $entropy,
            [System.Security.Cryptography.DataProtectionScope]::LocalMachine
        )

        # Return as base64 for safe registry storage
        return [System.Convert]::ToBase64String($encryptedBytes)
    }
    catch {
        Write-CBUPLog "DPAPI encryption failed: $_" -Level ERROR
        throw "Failed to encrypt registry value: $($_.Exception.Message)"
    }
}

function Unprotect-RegistryValue {
    <#
    .SYNOPSIS
        Decrypts a base64-encoded DPAPI-encrypted string back to plaintext.
    .PARAMETER Base64
        The base64-encoded encrypted string from the registry.
    .OUTPUTS
        Decrypted plaintext string.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Base64
    )

    try {
        $encryptedBytes = [System.Convert]::FromBase64String($Base64)

        # Decrypt using DPAPI with the same entropy and scope
        $entropy = [System.Text.Encoding]::UTF8.GetBytes("CBUP-Agent-v2.2-DPAPI")
        $decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $encryptedBytes,
            $entropy,
            [System.Security.Cryptography.DataProtectionScope]::LocalMachine
        )

        return [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
    }
    catch {
        Write-CBUPLog "DPAPI decryption failed: $_" -Level WARN
        throw "Failed to decrypt registry value. Value may be corrupt or from a different machine."
    }
}
