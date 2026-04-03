# =============================================================================
# CBUP-API.ps1
# Module: API communication with the CBUP portal.
# Provides authentication header generation, HTTP request handling with retry
# logic, and gzip compression for large payloads.
# =============================================================================

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
