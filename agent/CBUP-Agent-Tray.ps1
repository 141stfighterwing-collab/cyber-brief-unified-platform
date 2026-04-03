#Requires -Version 5.1
<#
.SYNOPSIS
    CBUP Agent System Tray Application
.DESCRIPTION
    Windows Forms-based system tray application for the CBUP Monitoring Agent.
    Provides visual status indicator, context menu actions, and balloon notifications
    for agent events. Does NOT run the agent itself - monitors the service status.
.NOTES
    Version:    2.1.0
    Author:     CBUP Security Engineering
    Project:    Cyber Brief Unified Platform
    Requires:   Windows PowerShell 5.1+ with Windows Forms support

.EXAMPLE
    .\CBUP-Agent-Tray.ps1
    Launches the system tray application.

.EXAMPLE
    .\CBUP-Agent-Tray.ps1 -DashboardUrl "https://cbup.example.com"
    Launches with a custom dashboard URL.
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "URL of the CBUP dashboard")]
    [string]$DashboardUrl,

    [Parameter(HelpMessage = "Name of the CBUP agent service")]
    [string]$ServiceName = "CBUPAgent",

    [Parameter(HelpMessage = "Registry key path for agent config")]
    [string]$RegKeyPath = "HKLM:\SOFTWARE\CBUP"
)

# =============================================================================
# CONFIGURATION
# =============================================================================

$script:AgentVersion = "2.1.0"
$script:ServiceName = $ServiceName
$script:RegKeyPath = $RegKeyPath
$script:StatusCheckInterval = 10000  # 10 seconds in milliseconds
$script:NotificationCooldown = 60000  # 60 seconds between same-type notifications
$script:LastNotificationType = $null
$script:LastNotificationTime = [datetime]::MinValue

# =============================================================================
# GLOBAL FORM OBJECTS
# =============================================================================

$script:NotifyIcon = $null
$script:ContextMenu = $null
$script:StatusTimer = $null
$script:AgentStatus = "unknown"
$script:LastHeartbeat = "Never"
$script:PreviousStatus = "unknown"

# Color definitions for status
$script:StatusColors = @{
    "online"      = [System.Drawing.Color]::FromArgb(0, 180, 100)    # Green
    "warning"     = [System.Drawing.Color]::FromArgb(220, 170, 0)     # Yellow/Amber
    "critical"    = [System.Drawing.Color]::FromArgb(220, 50, 50)     # Red
    "offline"     = [System.Drawing.Color]::FromArgb(150, 150, 150)   # Gray
    "unknown"     = [System.Drawing.Color]::FromArgb(150, 150, 150)   # Gray
}

# =============================================================================
# SHIELD ICON DRAWING (Generates icons in memory - no file dependencies)
# =============================================================================

function New-ShieldBitmap {
    <#
    .SYNOPSIS
        Creates a shield bitmap for the tray icon with the specified color.
    .PARAMETER Size
        Icon size in pixels.
    .PARAMETER StatusColor
        Color based on agent status.
    #>
    param(
        [int]$Size = 16,
        [System.Drawing.Color]$StatusColor = [System.Drawing.Color]::Gray
    )

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size)
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gfx.Clear([System.Drawing.Color]::Transparent)

    $scale = $Size / 16.0
    $margin = 1.5 * $scale
    $w = ($Size - 2 * $margin)

    # Shield path
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($margin, $margin, $w * 0.45, $w * 0.3, 180, 90)
    $path.AddArc($margin + $w * 0.55, $margin, $w * 0.45, $w * 0.3, 270, 90)
    $path.AddLine($margin + $w, $margin + $w * 0.15, $margin + $w, $margin + $w * 0.55)
    $path.AddLine($margin + $w, $margin + $w * 0.55, $Size / 2, $Size - $margin)
    $path.AddLine($Size / 2, $Size - $margin, $margin, $margin + $w * 0.55)
    $path.AddLine($margin, $margin + $w * 0.55, $margin, $margin + $w * 0.15)
    $path.CloseFigure()

    # Fill shield
    $fillBrush = New-Object System.Drawing.SolidBrush($StatusColor)
    $gfx.FillPath($fillBrush, $path)

    # Border
    $borderColor = [System.Drawing.Color]::FromArgb(
        [math]::Max(0, $StatusColor.R - 40),
        [math]::Max(0, $StatusColor.G - 40),
        [math]::Max(0, $StatusColor.B - 40)
    )
    $borderPen = New-Object System.Drawing.Pen($borderColor, 1 * $scale)
    $gfx.DrawPath($borderPen, $path)

    # Checkmark (for online/ok status) or X (for offline/error)
    if ($script:AgentStatus -eq "online" -or $script:AgentStatus -eq "warning") {
        # Checkmark
        $checkPen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 1.5 * $scale)
        $checkPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $checkPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $gfx.DrawLines($checkPen, @(
            (New-Object System.Drawing.PointF(($Size * 0.22), ($Size * 0.50))),
            (New-Object System.Drawing.PointF(($Size * 0.40), ($Size * 0.70))),
            (New-Object System.Drawing.PointF(($Size * 0.78), ($Size * 0.30)))
        ))
        $checkPen.Dispose()
    }
    elseif ($script:AgentStatus -eq "critical" -or $script:AgentStatus -eq "offline") {
        # X mark
        $xPen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 1.5 * $scale)
        $xPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $xPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $gfx.DrawLines($xPen, @(
            (New-Object System.Drawing.PointF(($Size * 0.35), ($Size * 0.35))),
            (New-Object System.Drawing.PointF(($Size * 0.65), ($Size * 0.65))),
            (New-Object System.Drawing.PointF(($Size * 0.35), ($Size * 0.35)))
        ))
        $gfx.DrawLines($xPen, @(
            (New-Object System.Drawing.PointF(($Size * 0.65), ($Size * 0.35))),
            (New-Object System.Drawing.PointF(($Size * 0.35), ($Size * 0.65))),
            (New-Object System.Drawing.PointF(($Size * 0.65), ($Size * 0.35)))
        ))
        $xPen.Dispose()
    }
    else {
        # Question mark for unknown
        $font = New-Object System.Drawing.Font("Segoe UI", (7 * $scale), [System.Drawing.FontStyle]::Bold)
        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment = [System.Drawing.StringAlignment]::Center
        $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
        $gfx.DrawString("?", $font, (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)),
            (New-Object System.Drawing.RectangleF(0, 0, $Size, $Size)), $sf)
        $font.Dispose()
        $sf.Dispose()
    }

    $fillBrush.Dispose()
    $borderPen.Dispose()
    $gfx.Dispose()

    return $bmp
}

function Get-TrayIconHandle {
    <#
    .SYNOPSIS
        Creates a GDI+ icon handle from a shield bitmap.
    #>
    param(
        [System.Drawing.Color]$StatusColor
    )

    # Generate multiple resolutions for crisp display
    $bmp16 = New-ShieldBitmap -Size 16 -StatusColor $StatusColor
    $bmp20 = New-ShieldBitmap -Size 20 -StatusColor $StatusColor
    $bmp24 = New-ShieldBitmap -Size 24 -StatusColor $StatusColor
    $bmp32 = New-ShieldBitmap -Size 32 -StatusColor $StatusColor

    # Convert to icon using Bitmap.MakeTransparent workaround
    # The NotifyIcon.Icon expects an Icon object
    $ms = New-Object System.IO.MemoryStream

    # Use the 16x16 as the base (most compatible for system tray)
    $handle16 = $bmp16.GetHicon()
    $icon16 = [System.Drawing.Icon]::FromHandle($handle16)

    # Cleanup bitmaps
    $bmp16.Dispose()
    $bmp20.Dispose()
    $bmp24.Dispose()
    $bmp32.Dispose()

    return $icon16
}

# =============================================================================
# STATUS DETECTION
# =============================================================================

function Get-AgentServiceStatus {
    <#
    .SYNOPSIS
        Checks the CBUP Agent Windows service status.
    .OUTPUTS
        String: online, offline, warning, critical, unknown
    #>
    try {
        $svc = Get-Service -Name $script:ServiceName -ErrorAction Stop

        if ($svc.Status -eq 'Running') {
            # Service is running. Check if we can get more detail from registry.
            $status = "online"

            if (Test-Path $script:RegKeyPath) {
                $props = Get-ItemProperty -Path $script:RegKeyPath -ErrorAction SilentlyContinue
                if ($props) {
                    # Check last heartbeat time
                    if ($props.LastHeartbeat) {
                        try {
                            $lastHB = [datetime]::Parse($props.LastHeartbeat)
                            $elapsed = ((Get-Date) - $lastHB).TotalSeconds

                            if ($elapsed -gt 120) {
                                $status = "offline"  # No heartbeat for 2+ minutes
                            }
                            elseif ($elapsed -gt 60) {
                                $status = "warning"  # No heartbeat for 1+ minute
                            }

                            # Store for display
                            if ($elapsed -lt 60) {
                                $script:LastHeartbeat = "$([math]::Floor($elapsed))s ago"
                            }
                            elseif ($elapsed -lt 3600) {
                                $script:LastHeartbeat = "$([math]::Floor($elapsed / 60))m ago"
                            }
                            else {
                                $script:LastHeartbeat = "$([math]::Floor($elapsed / 3600))h ago"
                            }
                        }
                        catch {}
                    }

                    # Check CPU/memory for critical status
                    if ($props.LastCpuPercent -and [int]$props.LastCpuPercent -gt 95) {
                        $status = "critical"
                    }
                    if ($props.LastMemPercent -and [int]$props.LastMemPercent -gt 98) {
                        $status = "critical"
                    }
                }
            }

            return $status
        }
        elseif ($svc.Status -eq 'Stopped') {
            return "offline"
        }
        else {
            return "warning"
        }
    }
    catch {
        return "offline"
    }
}

function Get-AgentDashboardUrl {
    <#
    .SYNOPSIS
        Gets the dashboard URL from parameter, registry, or default.
    #>
    if ($DashboardUrl) {
        return $DashboardUrl
    }

    if (Test-Path $script:RegKeyPath) {
        $props = Get-ItemProperty -Path $script:RegKeyPath -ErrorAction SilentlyContinue
        if ($props.ServerUrl) {
            return $props.ServerUrl
        }
    }

    return "https://cbup.example.com"
}

function Get-AgentLogPath {
    <#
    .SYNOPSIS
        Gets the agent log file path.
    #>
    if (Test-Path $script:RegKeyPath) {
        $props = Get-ItemProperty -Path $script:RegKeyPath -ErrorAction SilentlyContinue
        if ($props.LogFilePath -and (Test-Path (Split-Path $props.LogFilePath -Parent))) {
            return $props.LogFilePath
        }
    }

    # Default path
    $defaultLog = "$env:ProgramData\CBUP\agent.log"
    if (Test-Path $defaultLog) {
        return $defaultLog
    }

    return $null
}

# =============================================================================
# NOTIFICATIONS
# =============================================================================

function Show-BalloonNotification {
    <#
    .SYNOPSIS
        Shows a balloon tip notification with cooldown to prevent spam.
    .PARAMETER Title
        Notification title.
    .PARAMETER Text
        Notification text.
    .PARAMETER NotificationType
        Type for cooldown tracking.
    .PARAMETER Icon
        Tooltip icon: Info, Warning, Error, None.
    #>
    param(
        [string]$Title,
        [string]$Text,
        [string]$NotificationType,
        [System.Windows.Forms.ToolTipIcon]$Icon = [System.Windows.Forms.ToolTipIcon]::Info
    )

    # Cooldown check
    if ($script:LastNotificationType -eq $NotificationType -and
        ((Get-Date) - $script:LastNotificationTime).TotalMilliseconds -lt $script:NotificationCooldown) {
        return
    }

    try {
        $script:NotifyIcon.BalloonTipTitle = $Title
        $script:NotifyIcon.BalloonTipText = $Text
        $script:NotifyIcon.BalloonTipIcon = $Icon
        $script:NotifyIcon.ShowBalloonTip(5000)

        $script:LastNotificationType = $NotificationType
        $script:LastNotificationTime = Get-Date
    }
    catch {
        # Silent fail for notifications
    }
}

# =============================================================================
# CONTEXT MENU ACTIONS
# =============================================================================

function Open-Dashboard {
    <#
    .SYNOPSIS
        Opens the CBUP dashboard in the default browser.
    #>
    $url = Get-AgentDashboardUrl
    Start-Process $url
}

function Invoke-EDRScan {
    <#
    .SYNOPSIS
        Triggers an EDR scan via the agent command API.
    #>
    try {
        $url = Get-AgentDashboardUrl
        # Open the scan trigger URL directly in the dashboard
        Start-Process "$url/monitoring?action=trigger-scan"
    }
    catch {
        Show-BalloonNotification -Title "CBUP Agent" -Text "Failed to trigger scan: $_" -NotificationType "scan_error" -Icon Error
    }
}

function Show-AgentLogs {
    <#
    .SYNOPSIS
        Opens the agent log file in Notepad.
    #>
    $logPath = Get-AgentLogPath
    if ($logPath) {
        Start-Process notepad.exe -ArgumentList $logPath
    }
    else {
        [System.Windows.Forms.MessageBox]::Show(
            "Agent log file not found.`nDefault location: $env:ProgramData\CBUP\agent.log",
            "CBUP Agent - Log Not Found",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
    }
}

function Restart-AgentService {
    <#
    .SYNOPSIS
        Restarts the CBUP Agent service.
    #>
    try {
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Are you sure you want to restart the CBUP Agent service?",
            "CBUP Agent - Restart Service",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            Restart-Service -Name $script:ServiceName -Force -ErrorAction Stop
            Show-BalloonNotification -Title "CBUP Agent" -Text "Agent service restarted successfully." -NotificationType "restart" -Icon Info
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to restart agent service: $_",
            "CBUP Agent - Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

function Exit-TrayApp {
    <#
    .SYNOPSIS
        Exits the tray application (does NOT stop the service).
    #>
    $script:StatusTimer.Stop()
    $script:StatusTimer.Dispose()
    $script:NotifyIcon.Visible = $false
    $script:NotifyIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
}

# =============================================================================
# FORM INITIALIZATION
# =============================================================================

function Initialize-TrayApp {
    <#
    .SYNOPSIS
        Creates and initializes the system tray application.
    #>

    # Load required assemblies
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop

    # Create NotifyIcon
    $script:NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
    $script:NotifyIcon.Text = "CBUP Agent v$($script:AgentVersion) - Initializing..."
    $script:NotifyIcon.Visible = $false  # Will show after first status check

    # Set initial icon
    $initialIcon = Get-TrayIconHandle -StatusColor $script:StatusColors["unknown"]
    $script:NotifyIcon.Icon = $initialIcon

    # Build context menu
    $script:ContextMenu = New-Object System.Windows.Forms.ContextMenuStrip

    # --- Version header (disabled) ---
    $headerItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $headerItem.Text = "CBUP Agent v$($script:AgentVersion)"
    $headerItem.Enabled = $false
    $script:ContextMenu.Items.Add($headerItem) | Out-Null

    # Separator
    $script:ContextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

    # --- Status display (disabled, updates dynamically) ---
    $script:StatusMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $script:StatusMenuItem.Text = "Status: Checking..."
    $script:StatusMenuItem.Enabled = $false
    $script:ContextMenu.Items.Add($script:StatusMenuItem) | Out-Null

    # --- Last heartbeat (disabled, updates dynamically) ---
    $script:HeartbeatMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $script:HeartbeatMenuItem.Text = "Last Heartbeat: Never"
    $script:HeartbeatMenuItem.Enabled = $false
    $script:ContextMenu.Items.Add($script:HeartbeatMenuItem) | Out-Null

    # Separator
    $script:ContextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

    # --- Open Dashboard ---
    $dashboardItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $dashboardItem.Text = "Open Dashboard"
    $dashboardItem.ShortcutKeys = [System.Windows.Forms.Keys]::Control + [System.Windows.Forms.Keys]::D
    $dashboardItem.Add_Click({ Open-Dashboard })
    $script:ContextMenu.Items.Add($dashboardItem) | Out-Null

    # --- Run EDR Scan ---
    $scanItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $scanItem.Text = "Run EDR Scan"
    $scanItem.ShortcutKeys = [System.Windows.Forms.Keys]::Control + [System.Windows.Forms.Keys]::S
    $scanItem.Add_Click({ Invoke-EDRScan })
    $script:ContextMenu.Items.Add($scanItem) | Out-Null

    # Separator
    $script:ContextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

    # --- Show Logs ---
    $logsItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $logsItem.Text = "Show Logs"
    $logsItem.ShortcutKeys = [System.Windows.Forms.Keys]::Control + [System.Windows.Forms.Keys]::L
    $logsItem.Add_Click({ Show-AgentLogs })
    $script:ContextMenu.Items.Add($logsItem) | Out-Null

    # --- Restart Agent ---
    $restartItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $restartItem.Text = "Restart Agent"
    $restartItem.ShortcutKeys = [System.Windows.Forms.Keys]::Control + [System.Windows.Forms.Keys]::R
    $restartItem.Add_Click({ Restart-AgentService })
    $script:ContextMenu.Items.Add($restartItem) | Out-Null

    # Separator
    $script:ContextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

    # --- Exit ---
    $exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $exitItem.Text = "Exit"
    $exitItem.ShortcutKeys = [System.Windows.Forms.Keys]::Alt + [System.Windows.Forms.Keys]::F4
    $exitItem.Add_Click({ Exit-TrayApp })
    $script:ContextMenu.Items.Add($exitItem) | Out-Null

    # Assign context menu
    $script:NotifyIcon.ContextMenuStrip = $script:ContextMenu

    # Double-click opens dashboard
    $script:NotifyIcon.Add_DoubleClick({ Open-Dashboard })

    # Create status check timer
    $script:StatusTimer = New-Object System.Windows.Forms.Timer
    $script:StatusTimer.Interval = $script:StatusCheckInterval
    $script:StatusTimer.Add_Tick({
        Update-TrayStatus
    })
}

# =============================================================================
# STATUS UPDATE
# =============================================================================

function Update-TrayStatus {
    <#
    .SYNOPSIS
        Periodically checks and updates the tray icon based on agent status.
    #>
    $status = Get-AgentServiceStatus

    # Update icon color
    $color = $script:StatusColors[$status]
    if (-not $color) {
        $color = $script:StatusColors["unknown"]
    }

    try {
        $newIcon = Get-TrayIconHandle -StatusColor $color
        $script:NotifyIcon.Icon = $newIcon
    }
    catch {}

    # Update tooltip
    $statusText = switch ($status) {
        "online"    { "Online" }
        "warning"   { "Warning" }
        "critical"  { "Critical" }
        "offline"   { "Offline" }
        default     { "Unknown" }
    }
    $script:NotifyIcon.Text = "CBUP Agent - $statusText"

    # Update context menu items
    $script:StatusMenuItem.Text = "Status: $statusText"
    $script:HeartbeatMenuItem.Text = "Last Heartbeat: $($script:LastHeartbeat)"

    # Color the status menu text
    $statusColor = switch ($status) {
        "online"    { [System.Drawing.Color]::FromArgb(0, 140, 80) }
        "warning"   { [System.Drawing.Color]::FromArgb(180, 130, 0) }
        "critical"  { [System.Drawing.Color]::FromArgb(200, 40, 40) }
        "offline"   { [System.Drawing.Color]::FromArgb(120, 120, 120) }
        default     { [System.Drawing.Color]::Black }
    }
    $script:StatusMenuItem.ForeColor = $statusColor

    # Make tray icon visible on first successful check
    if (-not $script:NotifyIcon.Visible) {
        $script:NotifyIcon.Visible = $true
    }

    # Notify on status changes
    if ($script:PreviousStatus -ne "unknown" -and $script:PreviousStatus -ne $status) {
        switch ($status) {
            "online" {
                Show-BalloonNotification -Title "CBUP Agent Connected" `
                    -Text "Agent is online and reporting telemetry." `
                    -NotificationType "connected" `
                    -Icon Info
            }
            "offline" {
                Show-BalloonNotification -Title "CBUP Agent Disconnected" `
                    -Text "Agent service appears to be offline or not responding." `
                    -NotificationType "disconnected" `
                    -Icon Error
            }
            "critical" {
                Show-BalloonNotification -Title "CBUP Agent - Critical" `
                    -Text "Agent system resources critically high!" `
                    -NotificationType "critical" `
                    -Icon Error
            }
            "warning" {
                Show-BalloonNotification -Title "CBUP Agent - Warning" `
                    -Text "Agent performance warnings detected." `
                    -NotificationType "warning" `
                    -Icon Warning
            }
        }
    }

    $script:PreviousStatus = $status
}

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

try {
    # Initialize
    Initialize-TrayApp

    # Initial status check
    Update-TrayStatus

    # Start monitoring timer
    $script:StatusTimer.Start()

    # Show connected notification on start
    if ($script:AgentStatus -eq "online") {
        Show-BalloonNotification -Title "CBUP Agent" `
            -Text "Agent connected successfully." `
            -NotificationType "startup" `
            -Icon Info
    }

    # Run the application message loop (blocking call)
    [System.Windows.Forms.Application]::Run()

    # Cleanup on exit
    if ($script:NotifyIcon -ne $null) {
        $script:NotifyIcon.Visible = $false
        $script:NotifyIcon.Dispose()
    }
    if ($script:StatusTimer -ne $null) {
        $script:StatusTimer.Stop()
        $script:StatusTimer.Dispose()
    }
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        "CBUP Agent Tray App encountered an error: $_`n`nStack Trace: $($_.ScriptStackTrace)",
        "CBUP Agent - Fatal Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}
