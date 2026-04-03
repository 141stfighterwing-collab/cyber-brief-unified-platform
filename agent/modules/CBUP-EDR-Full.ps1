# =============================================================================
# CBUP-EDR-Full.ps1
# Module: Full EDR scan orchestrator for CBUP Agent.
# Runs all individual EDR scan types and combines results.
# =============================================================================

function Invoke-FullEDRScan {
    <#
    .SYNOPSIS
        Runs all EDR scan types and returns combined results.
    .OUTPUTS
        Hashtable with results from all scan types.
    #>
    Write-CBUPLog "===== Starting Full EDR Scan ====="

    $scanResults = @{
        AgentId   = $script:Config.AgentId
        Timestamp = [datetime]::UtcNow.ToString("o")
        Hostname  = $env:COMPUTERNAME
        Scans     = @()
    }

    # Run each scan type
    $scanResults.Scans += Invoke-EDRProcessScan
    $scanResults.Scans += Invoke-EDRServiceScan
    $scanResults.Scans += Invoke-EDRPortScan
    $scanResults.Scans += Invoke-EDRAutorunScan
    $scanResults.Scans += Invoke-EDRVulnerabilityScan

    # Calculate totals
    $scanResults["TotalFindings"] = ($scanResults.Scans | Measure-Object -Property SuspiciousCount -Sum).Sum
    $scanResults["TotalIssues"]   = ($scanResults.Scans | Where-Object { $_.IssuesFound } | Measure-Object -Property IssuesFound -Sum).Sum

    Write-CBUPLog "===== Full EDR Scan Complete. Total Findings=$($scanResults.TotalFindings) ====="

    return $scanResults
}
