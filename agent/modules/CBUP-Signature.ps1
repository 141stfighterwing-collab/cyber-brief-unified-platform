# =============================================================================
# CBUP-Signature.ps1
# Module: Company-specific agent signature support for CBUP Agent.
# Generates, embeds, and verifies cryptographic signatures tied to a tenant
# and company, providing tamper-evident agent identity.
# =============================================================================

function Get-AgentSignature {
    <#
    .SYNOPSIS
        Generates a signature metadata object for the agent tied to a tenant and company.
    .PARAMETER TenantId
        The unique tenant identifier from the CBUP portal.
    .PARAMETER CompanyName
        The company/organization name for this agent deployment.
    .OUTPUTS
        Hashtable with signature metadata including SHA256 fingerprint.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$CompanyName
    )

    # Build the fingerprint payload: tenantId + companyName + version
    $payload = "$TenantId|$CompanyName|$($script:AgentVersion)"
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
    $hashBytes = $hasher.ComputeHash($bytes)
    $fingerprint = ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ''

    $signature = @{
        TenantId    = $TenantId
        CompanyName = $CompanyName
        SignedBy    = "CBUP Security Engineering"
        Timestamp   = [datetime]::UtcNow.ToString("o")
        Fingerprint = $fingerprint
        Version     = $script:AgentVersion
    }

    Write-CBUPLog "Agent signature generated. Fingerprint=$fingerprint" -Level DEBUG
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
        $sig = Get-AgentSignature -TenantId $TenantId -CompanyName $CompanyName

        Set-RegistryConfig -Settings @{
            SignatureTenantId    = $sig.TenantId
            SignatureCompanyName = $sig.CompanyName
            SignatureSignedBy    = $sig.SignedBy
            SignatureTimestamp   = $sig.Timestamp
            SignatureFingerprint = $sig.Fingerprint
            SignatureVersion     = $sig.Version
        }

        Write-CBUPLog "Agent signature embedded in registry. Tenant=$TenantId, Company=$CompanyName"
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

        # Recompute fingerprint and compare
        $expectedSig = Get-AgentSignature -TenantId $storedTenantId -CompanyName $storedCompanyName
        if ($expectedSig.Fingerprint -ne $storedFingerprint) {
            Write-CBUPLog "Signature fingerprint mismatch. Possible tampering detected!" -Level ERROR
            return $false
        }

        Write-CBUPLog "Agent signature verified. Tenant=$TenantId, Fingerprint=$storedFingerprint" -Level DEBUG
        return $true
    }
    catch {
        Write-CBUPLog "Error verifying agent signature: $_" -Level ERROR
        return $false
    }
}
