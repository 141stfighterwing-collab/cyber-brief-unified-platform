# =============================================================================
# CBUP-API.ps1
# Module: API communication with the CBUP portal.
# Provides authentication header generation, HTTP request handling with retry
# logic, gzip compression for large payloads, and TLS certificate pinning.
#
# Security hardening (v2.2.0):
#   - Added optional TLS certificate pinning
#   - Logs TLS connection details at DEBUG level
# =============================================================================

# ─── TLS Certificate Pinning Configuration ──────────────────────────────────
# Set this to a specific SHA1 thumbprint to pin the server certificate.
# If set, the agent will ONLY connect to servers presenting this exact certificate.
# Leave empty/null for standard certificate chain validation (backward compatible).
$script:PinnedCertThumbprint = $null

function Initialize-TLSSecurity {
    <#
    .SYNOPSIS
        Configures TLS security settings including optional certificate pinning.
        Called during agent initialization to set up the validation callback.
    #>
    try {
        # Ensure TLS 1.2+ is used
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13

        # Check if a pinned certificate thumbprint is configured via registry
        if (Test-Path $script:RegKeyPath) {
            try {
                $props = Get-ItemProperty -Path $script:RegKeyPath -ErrorAction Stop
                if ($props.PinnedCertThumbprint) {
                    $script:PinnedCertThumbprint = $props.PinnedCertThumbprint
                }
            }
            catch { }
        }

        # Register certificate validation callback
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {
            param(
                $sender,
                [System.Security.Cryptography.X509Certificates.X509Certificate]$certificate,
                [System.Security.Cryptography.X509Certificates.X509Chain]$chain,
                [System.Net.Security.SslPolicyErrors]$sslPolicyErrors
            )

            # Always validate the certificate chain first
            if ($sslPolicyErrors -band [System.Net.Security.SslPolicyErrors]::RemoteCertificateChainErrors) {
                Write-CBUPLog "TLS: Certificate chain validation FAILED. The server certificate is not trusted." -Level ERROR
                return $false
            }

            # Check for hostname mismatch
            if ($sslPolicyErrors -band [System.Net.Security.SslPolicyErrors]::RemoteCertificateNameMismatch) {
                Write-CBUPLog "TLS: Certificate hostname mismatch detected." -Level ERROR
                return $false
            }

            # Log TLS connection details at DEBUG level
            $certSubject = $certificate.Subject
            $certIssuer = $certificate.Issuer
            $certThumbprint = $certificate.Thumbprint
            $certExpiry = $certificate.GetExpirationDateString()
            $certEffectiveDate = $certificate.GetEffectiveDateString()

            Write-CBUPLog "TLS Connection Details:" -Level DEBUG
            Write-CBUPLog "  Subject:    $certSubject" -Level DEBUG
            Write-CBUPLog "  Issuer:     $certIssuer" -Level DEBUG
            Write-CBUPLog "  Thumbprint: $certThumbprint" -Level DEBUG
            Write-CBUPLog "  Valid From: $certEffectiveDate" -Level DEBUG
            Write-CBUPLog "  Valid To:   $certExpiry" -Level DEBUG
            Write-CBUPLog "  Chain Status: $($chain.ChainStatus | ForEach-Object { $_.Status })" -Level DEBUG

            # ── Certificate Pinning Check ──
            if ($script:PinnedCertThumbprint) {
                if ($certThumbprint -eq $script:PinnedCertThumbprint) {
                    Write-CBUPLog "TLS: Certificate pinning VERIFIED (thumbprint match)." -Level DEBUG
                    return $true
                }
                else {
                    Write-CBUPLog "TLS: Certificate pinning FAILED! Expected: $($script:PinnedCertThumbprint), Got: $certThumbprint" -Level ERROR
                    return $false
                }
            }
            else {
                # No pin configured - warn at startup only
                # (we avoid logging this on every request to reduce noise)
                # The warning is logged once in the TLS initialization below
                return $true
            }
        }

        if ($script:PinnedCertThumbprint) {
            Write-CBUPLog "TLS: Certificate pinning ENABLED. Pinned to thumbprint: $($script:PinnedCertThumbprint.Substring(0, [math]::Min(16, $script:PinnedCertThumbprint.Length)))..." -Level WARN
        }
        else {
            Write-CBUPLog "TLS: Certificate pinning NOT configured. Standard chain validation only. (Set PinnedCertThumbprint in registry for enhanced security)" -Level WARN
        }
    }
    catch {
        Write-CBUPLog "TLS security initialization failed: $_" -Level WARN
    }
}

# Initialize TLS security when this module loads
Initialize-TLSSecurity

function New-ApiHeaders {
    <#
    .SYNOPSIS
        Builds authentication headers for API requests.
    #>
    $headers = @{
        "Content-Type"  = "application/json"
        "User-Agent"    = "CBUP-Agent/$($script:AgentVersion)"
        "X-Agent-Id"    = $script:Config.AgentId
        "X-Agent-Version" = $script:AgentVersion
    }
    if ($script:Config.AuthToken) {
        $headers["Authorization"] = "Bearer $($script:Config.AuthToken)"
    }
    return $headers
}

function Invoke-CBUPApi {
    <#
    .SYNOPSIS
        Sends an API request to the CBUP portal with retry logic and TLS validation.
    .PARAMETER Method
        HTTP method: GET, POST, PUT, DELETE.
    .PARAMETER Endpoint
        API endpoint path (e.g. /api/agents/heartbeat).
    .PARAMETER Body
        Request body (will be serialized to JSON).
    .PARAMETER UseCompression
        Whether to gzip-compress the request body.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("GET", "POST", "PUT", "DELETE")]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Endpoint,

        [Parameter()]
        $Body,

        [switch]$UseCompression
    )

    if (-not $script:Config.ServerUrl) {
        Write-CBUPLog "ServerUrl not configured. Cannot call API." -Level ERROR
        return $null
    }

    $uri = "$($script:Config.ServerUrl.TrimEnd('/'))$Endpoint"
    $headers = New-ApiHeaders
    $bodyJson = $null
    $compressed = $false

    if ($Body) {
        $bodyJson = $Body | ConvertTo-Json -Depth 10 -Compress
        # Use compression if payload exceeds 4KB
        if ($UseCompression -and $bodyJson.Length -gt 4096) {
            $compressed = $true
            $headers["Content-Encoding"] = "gzip"
            $headers["Content-Type"] = "application/json; charset=utf-8"
        }
    }

    $attempt = 0
    while ($attempt -lt $script:MaxRetries) {
        $attempt++
        try {
            $params = @{
                Method      = $Method
                Uri         = $uri
                Headers     = $headers
                TimeoutSec  = 30
                UseBasicParsing = $true
            }

            if ($Method -ne "GET" -and $bodyJson) {
                if ($compressed) {
                    # Gzip compress body
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes($bodyJson)
                    $ms = [System.IO.MemoryStream]::new()
                    $gz = [System.IO.Compression.GZipStream]::new($ms, [System.IO.Compression.CompressionLevel]::Optimal)
                    $gz.Write($bytes, 0, $bytes.Length)
                    $gz.Close()
                    $params["Body"] = $ms.ToArray()
                    $ms.Close()
                }
                else {
                    $params["Body"] = $bodyJson
                }
            }

            $response = Invoke-RestMethod @params -ErrorAction Stop
            Write-CBUPLog "API $Method $Endpoint -> Success (attempt $attempt)" -Level DEBUG
            return $response
        }
        catch {
            $errMsg = $_.Exception.Message
            if ($_.Exception.Response) {
                try {
                    $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                    $errBody = $streamReader.ReadToEnd()
                    $streamReader.Close()
                    $errMsg = "HTTP $([int]$_.Exception.Response.StatusCode): $errBody"
                }
                catch {
                    $errMsg = "HTTP $([int]$_.Exception.Response.StatusCode)"
                }
            }

            # Detect TLS/certificate errors specifically
            if ($errMsg -match 'certificate|TLS|SSL|authentication') {
                Write-CBUPLog "API $Method $Endpoint TLS/certificate error (attempt $attempt): $errMsg" -Level ERROR
            }

            if ($attempt -lt $script:MaxRetries) {
                $backoff = [math]::Min($script:RetryDelaySec * [math]::Pow(2, ($attempt - 1)), 60)
                Write-CBUPLog "API $Method $Endpoint failed (attempt $attempt/$($script:MaxRetries)): $errMsg. Retrying in ${backoff}s..." -Level WARN
                Start-Sleep -Seconds $backoff
            }
            else {
                Write-CBUPLog "API $Method $Endpoint failed after $attempt attempts: $errMsg" -Level ERROR
                return $null
            }
        }
    }

    return $null
}
