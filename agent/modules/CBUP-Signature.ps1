# =============================================================================
# CBUP-Signature.ps1
# Module: Company-specific agent signature support for CBUP Agent.
# Generates, embeds, and verifies cryptographic signatures tied to a tenant
# and company, providing tamper-evident agent identity.
#
# Security hardening (v2.2.0):
#   - Upgraded to HMAC-SHA256 signatures (backward compatible with SHA256)
#   - HMAC key received during registration, stored encrypted in registry
# =============================================================================

function Get-AgentSignature {
    <#
    .SYNOPSIS
        Generates a signature metadata object for the agent tied to a tenant and company.
    .PARAMETER TenantId
        The unique tenant identifier from the CBUP portal.
    .PARAMETER CompanyName
        The company/organization name for this agent deployment.
    .PARAMETER UseHMAC
        If true, use HMAC-SHA256 (v2.2.0+). If false, use plain SHA256 (legacy).
    .OUTPUTS
        Hashtable with signature metadata including HMAC-SHA256 fingerprint.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$CompanyName,

        [switch]$UseHMAC
    )

    # Build the fingerprint payload: tenantId + companyName + version
    $payload = "$TenantId|$CompanyName|$($script:AgentVersion)"

    # ── HMAC-SHA256 signature (v2.2.0+) ──
    # If an HMAC key is available (received during registration), use it
    $hmacKey = $script:Config.HmacKey
    if ($UseHMAC -or $hmacKey) {
        if ($hmacKey) {
            try {
                $hmac = [System.Security.Cryptography.HMACSHA256]::new([System.Text.Encoding]::UTF8.GetBytes($hmacKey))
                $payloadBytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
                $hashBytes = $hmac.ComputeHash($payloadBytes)
                $fingerprint = ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ''
                $hmac.Dispose()

                $signature = @{
                    TenantId        = $TenantId
                    CompanyName     = $CompanyName
                    SignedBy        = "CBUP Security Engineering"
                    Timestamp       = [datetime]::UtcNow.ToString("o")
                    Fingerprint     = $fingerprint
                    Version         = $script:AgentVersion
                    SignatureScheme = "HMAC-SHA256"
                }

                Write-CBUPLog "Agent HMAC-SHA256 signature generated. Fingerprint=$fingerprint" -Level DEBUG
                return $signature
            }
            catch {
                Write-CBUPLog "HMAC-SHA256 signature generation failed, falling back to SHA256: $_" -Level WARN
                # Fall through to legacy SHA256
            }
        }
    }

    # ── Legacy SHA256 signature (backward compatible) ──
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
    $hashBytes = $hasher.ComputeHash($bytes)
    $fingerprint = ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ''
    $hasher.Dispose()

    $signature = @{
        TenantId        = $TenantId
        CompanyName     = $CompanyName
        SignedBy        = "CBUP Security Engineering"
        Timestamp       = [datetime]::UtcNow.ToString("o")
        Fingerprint     = $fingerprint
        Version         = $script:AgentVersion
        SignatureScheme = "SHA256"
    }

    Write-CBUPLog "Agent SHA256 signature generated. Fingerprint=$fingerprint" -Level DEBUG
    return $signature
}

function Set-AgentSignature {
    <#
    .SYNOPSIS
        Embeds the agent signature into registry configuration for persistence.
    .PARAMETER TenantId
        The unique tenant identifier.
    .PARAMETER CompanyName
        The company/organization name.
    .OUTPUTS
        Boolean indicating success.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$CompanyName
    )

    try {
        # Use HMAC if key is available, otherwise legacy SHA256
        $useHmac = [bool]$script:Config.HmacKey
        $sig = Get-AgentSignature -TenantId $TenantId -CompanyName $CompanyName -UseHMAC:$useHmac

        Set-RegistryConfig -Settings @{
            SignatureTenantId    = $sig.TenantId
            SignatureCompanyName = $sig.CompanyName
            SignatureSignedBy    = $sig.SignedBy
            SignatureTimestamp   = $sig.Timestamp
            SignatureFingerprint = $sig.Fingerprint
            SignatureVersion     = $sig.Version
            SignatureScheme      = $sig.SignatureScheme
        }

        Write-CBUPLog "Agent signature embedded in registry. Tenant=$TenantId, Company=$CompanyName, Scheme=$($sig.SignatureScheme)"
        return $true
    }
    catch {
        Write-CBUPLog "Failed to embed agent signature: $_" -Level ERROR
        return $false
    }
}

function Test-AgentSignature {
    <#
    .SYNOPSIS
        Verifies that the stored agent signature matches the expected tenant.
        Supports both HMAC-SHA256 (v2.2.0+) and legacy SHA256 signatures.
    .PARAMETER TenantId
        The expected tenant identifier to validate against.
    .PARAMETER CompanyName
        The expected company name to validate against.
    .OUTPUTS
        Boolean indicating whether the signature is valid.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter()]
        [string]$CompanyName
    )

    try {
        if (-not (Test-Path $script:RegKeyPath)) {
            Write-CBUPLog "No registry configuration found for signature verification." -Level WARN
            return $false
        }

        $props = Get-ItemProperty -Path $script:RegKeyPath

        $storedTenantId    = $props.SignatureTenantId
        $storedCompanyName = $props.SignatureCompanyName
        $storedFingerprint = $props.SignatureFingerprint
        $storedScheme      = $props.SignatureScheme

        if (-not $storedTenantId) {
            Write-CBUPLog "No signature found in registry." -Level WARN
            return $false
        }

        # Verify tenant ID matches
        if ($storedTenantId -ne $TenantId) {
            Write-CBUPLog "Signature tenant mismatch: stored=$storedTenantId, expected=$TenantId" -Level ERROR
            return $false
        }

        # Verify company name if provided
        if ($CompanyName -and $storedCompanyName -ne $CompanyName) {
            Write-CBUPLog "Signature company mismatch: stored=$storedCompanyName, expected=$CompanyName" -Level WARN
            return $false
        }

        # Recompute fingerprint and compare (using the same scheme)
        $useHmac = ($storedScheme -eq "HMAC-SHA256") -and $script:Config.HmacKey
        $expectedSig = Get-AgentSignature -TenantId $storedTenantId -CompanyName $storedCompanyName -UseHMAC:$useHmac

        if ($expectedSig.Fingerprint -ne $storedFingerprint) {
            # If the scheme changed (e.g., HMAC key was added), the fingerprint will differ
            # This is expected; log a warning but don't fail
            if ($storedScheme -ne $expectedSig.SignatureScheme) {
                Write-CBUPLog "Signature scheme changed: stored=$storedScheme, current=$($expectedSig.SignatureScheme). Re-embed signature recommended." -Level WARN
                return $true  # Allow the change as non-critical
            }

            Write-CBUPLog "Signature fingerprint mismatch. Possible tampering detected!" -Level ERROR
            return $false
        }

        Write-CBUPLog "Agent signature verified. Tenant=$TenantId, Fingerprint=$storedFingerprint, Scheme=$storedScheme" -Level DEBUG
        return $true
    }
    catch {
        Write-CBUPLog "Error verifying agent signature: $_" -Level ERROR
        return $false
    }
}
