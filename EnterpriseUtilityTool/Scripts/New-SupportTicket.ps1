# New-SupportTicket.ps1
# Enhanced IT Support Ticket Generator with Comprehensive Diagnostics
# Collects system data, creates HTML report, and opens ITSM portal

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Software", "Hardware", "None")]
    [string]$SupportType = "None",
    
    [switch]$SkipITSMOpen = $false
)

# Load settings from appsettings.json
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$SettingsPath = Join-Path (Split-Path -Parent $ScriptPath) "appsettings.json"

# Default values if config file doesn't exist
$SoftwareITSMUrl = ""
$HardwareITSMUrl = "https://youritsmportal.com/submit-hardware"

# Try to load settings from appsettings.json
if (Test-Path $SettingsPath) {
    try {
        $Settings = Get-Content $SettingsPath -Raw | ConvertFrom-Json
        $SoftwareITSMUrl = $Settings.ITSM.SoftwareSupportURL
        $HardwareITSMUrl = $Settings.ITSM.HardwareSupportURL
        Write-Host "[CONFIG] Loaded settings from: $SettingsPath" -ForegroundColor Gray
    }
    catch {
        Write-Host "[WARN] Could not load appsettings.json, using defaults" -ForegroundColor Yellow
    }
}
else {
    Write-Host "[INFO] appsettings.json not found, using default ITSM URLs" -ForegroundColor Gray
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "           SYSTEM DIAGNOSTIC REPORT GENERATOR" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Generate unique report ID
$ReportID = "DIAG-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$ReportDate = Get-Date -Format 'MMMM dd, yyyy - HH:mm:ss'

Write-Host "Report ID: $ReportID" -ForegroundColor Yellow
Write-Host "Generated: $Timestamp" -ForegroundColor Gray
Write-Host ""

# ============================================
# SECTION 1: USER INFORMATION
# ============================================
Write-Host "[1/8] Collecting user information..." -ForegroundColor Cyan

$CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$Domain = $env:USERDOMAIN
$MachineName = $env:COMPUTERNAME
$Username = $env:USERNAME
$UserProfile = $env:USERPROFILE
$LogonServer = $env:LOGONSERVER -replace '\\\\', ''

# Get user's email from Active Directory if possible
try {
    $ADUser = ([adsisearcher]"samaccountname=$Username").FindOne()
    $UserEmail = $ADUser.Properties.mail[0]
    if ([string]::IsNullOrEmpty($UserEmail)) {
        $UserEmail = "$Username@$env:USERDNSDOMAIN"
    }
}
catch {
    $UserEmail = "$Username@$env:USERDNSDOMAIN"
}

$UserInfo = @{
    FullName = $CurrentUser
    Username = $Username
    Email = $UserEmail
    Domain = $Domain
    Computer = $MachineName
    LogonServer = $LogonServer
}

Write-Host "  [OK] User: $CurrentUser" -ForegroundColor Green

# ============================================
# SECTION 2: HARDWARE INFORMATION
# ============================================
Write-Host "[2/8] Collecting hardware information..." -ForegroundColor Cyan

$ComputerInfo = Get-ComputerInfo -ErrorAction SilentlyContinue
$Computer = Get-CimInstance Win32_ComputerSystem
$BIOS = Get-CimInstance Win32_BIOS
$CPU = Get-CimInstance Win32_Processor
$GPU = Get-CimInstance Win32_VideoController

$HardwareInfo = @{
    Manufacturer = $Computer.Manufacturer
    Model = $Computer.Model
    SerialNumber = $BIOS.SerialNumber
    BIOSVersion = $BIOS.SMBIOSBIOSVersion
    Processor = $CPU.Name
    ProcessorCores = $CPU.NumberOfCores
    ProcessorThreads = $CPU.NumberOfLogicalProcessors
    TotalRAM = [math]::Round($Computer.TotalPhysicalMemory / 1GB, 2)
    GPU = $GPU.Name
    GPUMemory = [math]::Round($GPU.AdapterRAM / 1GB, 2)
}

Write-Host "  [OK] Hardware: $($HardwareInfo.Manufacturer) $($HardwareInfo.Model)" -ForegroundColor Green

# ============================================
# SECTION 3: OPERATING SYSTEM INFORMATION
# ============================================
Write-Host "[3/8] Collecting operating system information..." -ForegroundColor Cyan

$OS = Get-CimInstance Win32_OperatingSystem
$TimeZone = (Get-TimeZone).DisplayName
$LastBoot = $OS.LastBootUpTime
$Uptime = (Get-Date) - $LastBoot

$OSInfo = @{
    Name = $OS.Caption
    Version = $OS.Version
    BuildNumber = $OS.BuildNumber
    Architecture = $OS.OSArchitecture
    InstallDate = $OS.InstallDate
    LastBootTime = $LastBoot
    UptimeDays = [math]::Round($Uptime.TotalDays, 2)
    TimeZone = $TimeZone
    SystemDrive = $OS.SystemDrive
}

Write-Host "  [OK] OS: $($OSInfo.Name) (Build $($OSInfo.BuildNumber))" -ForegroundColor Green

# ============================================
# SECTION 4: DISK INFORMATION
# ============================================
Write-Host "[4/8] Collecting disk information..." -ForegroundColor Cyan

$Disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    @{
        Drive = $_.DeviceID
        TotalGB = [math]::Round($_.Size / 1GB, 2)
        FreeGB = [math]::Round($_.FreeSpace / 1GB, 2)
        UsedGB = [math]::Round(($_.Size - $_.FreeSpace) / 1GB, 2)
        PercentFree = [math]::Round(($_.FreeSpace / $_.Size) * 100, 2)
        FileSystem = $_.FileSystem
        VolumeName = $_.VolumeName
    }
}

Write-Host "  [OK] Disks: $($Disks.Count) drive(s) scanned" -ForegroundColor Green

# ============================================
# SECTION 5: NETWORK INFORMATION
# ============================================
Write-Host "[5/8] Collecting network information..." -ForegroundColor Cyan

$ActiveAdapters = Get-NetAdapter | Where-Object {$_.Status -eq 'Up'}
$NetworkInfo = @()

foreach ($Adapter in $ActiveAdapters) {
    # Get configuration details for this specific adapter
    $Config = Get-NetIPConfiguration -InterfaceAlias $Adapter.Name -ErrorAction SilentlyContinue
    
    # Corrected Speed Calculation
    $RawSpeed = [math]::Round($Adapter.ReceiveLinkSpeed / 1000000, 0)
    $SpeedDisplay = if ($RawSpeed -ge 1000) { "$([math]::Round($RawSpeed/1000, 1)) Gbps" } else { "$RawSpeed Mbps" }

    $NetworkInfo += @{
        Name        = $Adapter.Name
        Description = $Adapter.InterfaceDescription
        Status      = $Adapter.Status
        Speed       = $SpeedDisplay
        MACAddress  = $Adapter.MacAddress
        # Pulls the first IPv4 address found
        IPAddress   = ($Config.IPv4Address.IPAddress | Select-Object -First 1)
        # Joins multiple DNS servers with a comma
        DNSServers  = ($Config.DNSServer.ServerAddresses -join ', ')
    }
}

# Optimized internet connectivity test (Fast Ping)
# Checks Google (8.8.8.8) OR Cloudflare (1.1.1.1)
if ((Test-Connection -ComputerName "capitecbank.fin.sky" -Count 1 -Quiet) -or 
    (Test-Connection -ComputerName "1.1.1.1" -Count 1 -Quiet)) {
    $InternetStatus = "Connected"
} else {
    $InternetStatus = "Disconnected"
}

Write-Host "  [OK] Network: $($ActiveAdapters.Count) active adapter(s), Internet: $InternetStatus" -ForegroundColor Green

# ============================================
# SECTION 6: INSTALLED SOFTWARE
# ============================================
Write-Host "[6/8] Collecting installed software (top 20)..." -ForegroundColor Cyan

$InstalledSoftware = @()
$RegistryPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

foreach ($Path in $RegistryPaths) {
    $InstalledSoftware += Get-ItemProperty $Path -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName } |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
}

$TopSoftware = $InstalledSoftware | 
    Select-Object -Unique DisplayName, DisplayVersion, Publisher, InstallDate |
    Sort-Object DisplayName |
    Select-Object -First 20

Write-Host "  [OK] Software: $($InstalledSoftware.Count) applications found" -ForegroundColor Green

# ============================================
# SECTION 7: RECENT UPDATES
# ============================================
Write-Host "[7/8] Checking recent Windows updates..." -ForegroundColor Cyan

try {
    $RecentUpdates = Get-HotFix | 
        Sort-Object InstalledOn -Descending | 
        Select-Object -First 10 |
        ForEach-Object {
            @{
                HotFixID = $_.HotFixID
                Description = $_.Description
                InstalledBy = $_.InstalledBy
                InstalledOn = $_.InstalledOn
            }
        }
    Write-Host "  [OK] Updates: $($RecentUpdates.Count) recent updates found" -ForegroundColor Green
}
catch {
    $RecentUpdates = @()
    Write-Host "  [WARN] Unable to retrieve update information" -ForegroundColor Yellow
}

# ============================================
# SECTION 8: ERROR LOGS & DIAGNOSTICS
# ============================================
Write-Host "[8/8] Collecting recent error logs..." -ForegroundColor Cyan

$DiagnosticData = @{
    ApplicationErrors = @()
    SystemErrors = @()
}

# Application errors
try {
    $AppErrors = Get-EventLog -LogName Application -EntryType Error -Newest 10 -ErrorAction SilentlyContinue
    $DiagnosticData.ApplicationErrors = $AppErrors | ForEach-Object {
        @{
            Time = $_.TimeGenerated
            Source = $_.Source
            EventID = $_.EventID
            Message = $_.Message.Substring(0, [Math]::Min(200, $_.Message.Length))
        }
    }
}
catch {
    Write-Host "  [WARN] Unable to retrieve application errors" -ForegroundColor Yellow
}

# System errors
try {
    $SysErrors = Get-EventLog -LogName System -EntryType Error -Newest 10 -ErrorAction SilentlyContinue
    $DiagnosticData.SystemErrors = $SysErrors | ForEach-Object {
        @{
            Time = $_.TimeGenerated
            Source = $_.Source
            EventID = $_.EventID
            Message = $_.Message.Substring(0, [Math]::Min(200, $_.Message.Length))
        }
    }
}
catch {
    Write-Host "  [WARN] Unable to retrieve system errors" -ForegroundColor Yellow
}

Write-Host "  [OK] Diagnostics: Collected recent error logs" -ForegroundColor Green
Write-Host ""

# ============================================
# GENERATE HTML REPORT
# ============================================
Write-Host "Generating comprehensive HTML report..." -ForegroundColor Cyan

$HTMLReport = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>System Diagnostic Report - $ReportID</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #f0f2f5;
            padding: 20px;
            color: #333;
        }
        .container {
            max-width: 1000px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #0078D4 0%, #005A9E 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 {
            font-size: 28px;
            margin-bottom: 10px;
        }
        .header .ticket-id {
            font-size: 18px;
            opacity: 0.9;
            font-weight: normal;
        }
        .header .timestamp {
            font-size: 14px;
            opacity: 0.8;
            margin-top: 5px;
        }
        .content {
            padding: 30px;
        }
        .section {
            margin-bottom: 30px;
            border-bottom: 2px solid #f0f2f5;
            padding-bottom: 20px;
        }
        .section:last-child {
            border-bottom: none;
        }
        .section-title {
            font-size: 20px;
            color: #0078D4;
            margin-bottom: 15px;
            padding-bottom: 10px;
            border-bottom: 2px solid #0078D4;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .section-icon {
            font-size: 14px;
            font-weight: bold;
            background: #0078D4;
            color: white;
            padding: 4px 8px;
            border-radius: 4px;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }
        .info-item {
            background: #f8f9fa;
            padding: 12px 15px;
            border-radius: 6px;
            border-left: 3px solid #0078D4;
        }
        .info-label {
            font-size: 12px;
            color: #666;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 5px;
        }
        .info-value {
            font-size: 14px;
            color: #333;
            font-weight: 500;
        }
        .table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        .table th {
            background: #0078D4;
            color: white;
            padding: 10px;
            text-align: left;
            font-weight: 600;
            font-size: 13px;
        }
        .table td {
            padding: 10px;
            border-bottom: 1px solid #e0e0e0;
            font-size: 13px;
        }
        .table tr:hover {
            background: #f8f9fa;
        }
        .alert {
            padding: 15px;
            border-radius: 6px;
            margin-bottom: 15px;
        }
        .alert-warning {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            color: #856404;
        }
        .alert-info {
            background: #d1ecf1;
            border-left: 4px solid #17a2b8;
            color: #0c5460;
        }
        .status-badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 600;
        }
        .status-good {
            background: #d4edda;
            color: #155724;
        }
        .status-warning {
            background: #fff3cd;
            color: #856404;
        }
        .status-error {
            background: #f8d7da;
            color: #721c24;
        }
        .footer {
            background: #f8f9fa;
            padding: 20px 30px;
            text-align: center;
            font-size: 13px;
            color: #666;
            border-top: 2px solid #e0e0e0;
        }
        .error-log {
            background: #f8f9fa;
            border: 1px solid #dee2e6;
            border-radius: 4px;
            padding: 10px;
            margin-top: 10px;
            max-height: 300px;
            overflow-y: auto;
        }
        .error-entry {
            padding: 8px;
            margin-bottom: 8px;
            background: white;
            border-left: 3px solid #dc3545;
            font-size: 12px;
        }
        .error-time {
            color: #666;
            font-weight: 600;
        }
        .error-source {
            color: #0078D4;
            font-weight: 600;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>System Diagnostic Report</h1>
            <div class="ticket-id">Report ID: $ReportID</div>
            <div class="timestamp">Generated: $ReportDate</div>
        </div>
        
        <div class="content">
            <!-- User Information -->
            <div class="section">
                <div class="section-title">
                    <span class="section-icon">USER</span>
                    User Information
                </div>
                <div class="info-grid">
                    <div class="info-item">
                        <div class="info-label">Full Name</div>
                        <div class="info-value">$($UserInfo.FullName)</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Username</div>
                        <div class="info-value">$($UserInfo.Username)</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Email</div>
                        <div class="info-value">$($UserInfo.Email)</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Domain</div>
                        <div class="info-value">$($UserInfo.Domain)</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Computer Name</div>
                        <div class="info-value">$($UserInfo.Computer)</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Logon Server</div>
                        <div class="info-value">$($UserInfo.LogonServer)</div>
                    </div>
                </div>
            </div>
            
            <!-- Hardware Information -->
            <div class="section">
                <div class="section-title">
                    <span class="section-icon">HARDWARE</span>
                    Hardware Information
                </div>
                <div class="info-grid">
                    <div class="info-item">
                        <div class="info-label">Manufacturer</div>
                        <div class="info-value">$($HardwareInfo.Manufacturer)</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Model</div>
                        <div class="info-value">$($HardwareInfo.Model)</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Serial Number</div>
                        <div class="info-value">$($HardwareInfo.SerialNumber)</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">BIOS Version</div>
                        <div class="info-value">$($HardwareInfo.BIOSVersion)</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Processor</div>
                        <div class="info-value">$($HardwareInfo.Processor)</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">CPU Cores / Threads</div>
                        <div class="info-value">$($HardwareInfo.ProcessorCores) cores / $($HardwareInfo.ProcessorThreads) threads</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Total RAM</div>
                        <div class="info-value">$($HardwareInfo.TotalRAM) GB</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Graphics Card</div>
                        <div class="info-value">$($HardwareInfo.GPU)</div>
                    </div>
                </div>
            </div>
            
            <!-- Operating System -->
            <div class="section">
                <div class="section-title">
                    <span class="section-icon">OS</span>
                    Operating System
                </div>
                <div class="info-grid">
                    <div class="info-item">
                        <div class="info-label">OS Name</div>
                        <div class="info-value">$($OSInfo.Name)</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Version / Build</div>
                        <div class="info-value">$($OSInfo.Version) (Build $($OSInfo.BuildNumber))</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Architecture</div>
                        <div class="info-value">$($OSInfo.Architecture)</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Install Date</div>
                        <div class="info-value">$($OSInfo.InstallDate)</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">Last Boot Time</div>
                        <div class="info-value">$($OSInfo.LastBootTime)</div>
                    </div>
                    <div class="info-item">
                        <div class="info-label">System Uptime</div>
                        <div class="info-value">$($OSInfo.UptimeDays) days</div>
                    </div>
                </div>
            </div>
            
            <!-- Disk Information -->
            <div class="section">
                <div class="section-title">
                    <span class="section-icon">DISK</span>
                    Disk Information
                </div>
                <table class="table">
                    <thead>
                        <tr>
                            <th>Drive</th>
                            <th>Volume Name</th>
                            <th>Total Size</th>
                            <th>Used</th>
                            <th>Free</th>
                            <th>% Free</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
"@

foreach ($Disk in $Disks) {
    $StatusClass = if ($Disk.PercentFree -lt 10) { "status-error" } 
                   elseif ($Disk.PercentFree -lt 20) { "status-warning" } 
                   else { "status-good" }
    
    $StatusText = if ($Disk.PercentFree -lt 10) { "Critical" }
                  elseif ($Disk.PercentFree -lt 20) { "Warning" }
                  else { "Good" }
    
    $HTMLReport += @"
                        <tr>
                            <td><strong>$($Disk.Drive)</strong></td>
                            <td>$($Disk.VolumeName)</td>
                            <td>$($Disk.TotalGB) GB</td>
                            <td>$($Disk.UsedGB) GB</td>
                            <td>$($Disk.FreeGB) GB</td>
                            <td>$($Disk.PercentFree)%</td>
                            <td><span class="status-badge $StatusClass">$StatusText</span></td>
                        </tr>
"@
}

$HTMLReport += @"
                    </tbody>
                </table>
            </div>
            
            <!-- Network Information -->
            <div class="section">
                <div class="section-title">
                    <span class="section-icon">NETWORK</span>
                    Network Information
                </div>
                <div class="alert alert-info">
                    <strong>Internet Status:</strong> $InternetStatus
                </div>
                <table class="table">
                    <thead>
                        <tr>
                            <th>Adapter</th>
                            <th>Status</th>
                            <th>Speed</th>
                            <th>IP Address</th>
                            <th>MAC Address</th>
                        </tr>
                    </thead>
                    <tbody>
"@

foreach ($Network in $NetworkInfo) {
    $HTMLReport += @"
                        <tr>
                            <td>$($Network.Name)</td>
                            <td><span class="status-badge status-good">$($Network.Status)</span></td>
                            <td>$($Network.Speed)</td>
                            <td>$($Network.IPAddress)</td>
                            <td>$($Network.MACAddress)</td>
                        </tr>
"@
}

$HTMLReport += @"
                    </tbody>
                </table>
            </div>
            
            <!-- Recent Windows Updates -->
            <div class="section">
                <div class="section-title">
                    <span class="section-icon">UPDATES</span>
                    Recent Windows Updates (Last 10)
                </div>
                <table class="table">
                    <thead>
                        <tr>
                            <th>HotFix ID</th>
                            <th>Description</th>
                            <th>Installed On</th>
                            <th>Installed By</th>
                        </tr>
                    </thead>
                    <tbody>
"@

foreach ($Update in $RecentUpdates) {
    $HTMLReport += @"
                        <tr>
                            <td><strong>$($Update.HotFixID)</strong></td>
                            <td>$($Update.Description)</td>
                            <td>$($Update.InstalledOn)</td>
                            <td>$($Update.InstalledBy)</td>
                        </tr>
"@
}

$HTMLReport += @"
                    </tbody>
                </table>
            </div>
            
            <!-- Installed Software -->
            <div class="section">
                <div class="section-title">
                    <span class="section-icon">SOFTWARE</span>
                    Installed Software (Top 20)
                </div>
                <table class="table">
                    <thead>
                        <tr>
                            <th>Application</th>
                            <th>Version</th>
                            <th>Publisher</th>
                            <th>Install Date</th>
                        </tr>
                    </thead>
                    <tbody>
"@

foreach ($Software in $TopSoftware) {
    $HTMLReport += @"
                        <tr>
                            <td>$($Software.DisplayName)</td>
                            <td>$($Software.DisplayVersion)</td>
                            <td>$($Software.Publisher)</td>
                            <td>$($Software.InstallDate)</td>
                        </tr>
"@
}

$HTMLReport += @"
                    </tbody>
                </table>
            </div>
            
            <!-- Error Logs -->
            <div class="section">
                <div class="section-title">
                    <span class="section-icon">ERRORS</span>
                    Recent Error Logs
                </div>
                
                <h3 style="color: #666; font-size: 16px; margin-bottom: 10px;">Application Errors (Last 10)</h3>
                <div class="error-log">
"@

if ($DiagnosticData.ApplicationErrors.Count -gt 0) {
    foreach ($LogEntry in $DiagnosticData.ApplicationErrors) {
        $HTMLReport += @"
                    <div class="error-entry">
                        <div class="error-time">$($LogEntry.Time)</div>
                        <div class="error-source">Source: $($LogEntry.Source) | Event ID: $($LogEntry.EventID)</div>
                        <div>$($LogEntry.Message)</div>
                    </div>
"@
    }
} else {
    $HTMLReport += "<div style='padding: 10px; color: #666;'>No recent application errors found.</div>"
}

$HTMLReport += @"
                </div>
                
                <h3 style="color: #666; font-size: 16px; margin: 20px 0 10px 0;">System Errors (Last 10)</h3>
                <div class="error-log">
"@

if ($DiagnosticData.SystemErrors.Count -gt 0) {
    foreach ($LogEntry in $DiagnosticData.SystemErrors) {
        $HTMLReport += @"
                    <div class="error-entry">
                        <div class="error-time">$($LogEntry.Time)</div>
                        <div class="error-source">Source: $($LogEntry.Source) | Event ID: $($LogEntry.EventID)</div>
                        <div>$($LogEntry.Message)</div>
                    </div>
"@
    }
} else {
    $HTMLReport += "<div style='padding: 10px; color: #666;'>No recent system errors found.</div>"
}

$HTMLReport += @"
                </div>
            </div>
            
            <!-- Issue Description Section -->
            <div class="section">
                <div class="section-title">
                    <span class="section-icon">ISSUE</span>
                    Issue Description
                </div>
                <div class="alert alert-warning">
                    <strong>Important:</strong> Please describe your issue when logging your request in the ITSM portal.
                    Attach this report file to provide comprehensive system information to the support team.
                </div>
                <div style="background: #f8f9fa; padding: 15px; border-radius: 6px; margin-top: 15px;">
                    <h4 style="margin-bottom: 10px;">Checklist for logging your request:</h4>
                    <ul style="list-style-position: inside; line-height: 2;">
                        <li>Describe the issue in detail</li>
                        <li>When did it start occurring?</li>
                        <li>What were you doing when it happened?</li>
                        <li>Have you tried any troubleshooting steps?</li>
                        <li>Attach this diagnostic report</li>
                        <li>Include screenshots if applicable</li>
                    </ul>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p><strong>System Diagnostic Report</strong></p>
            <p>Report ID: $ReportID | Generated: $ReportDate</p>
            <p>This report was automatically generated by the WindowPane Utility Tool</p>
        </div>
    </div>
</body>
</html>
"@

# ============================================
# SAVE FILES
# ============================================
Write-Host ""
Write-Host "Saving diagnostic reports..." -ForegroundColor Cyan

$OutputFolder = "$env:USERPROFILE\Desktop\DiagnosticReport_$ReportID"
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

$HTMLPath = "$OutputFolder\DiagnosticReport_$ReportID.html"
$TxtPath = "$OutputFolder\DiagnosticReport_$ReportID.txt"
$SummaryPath = "$OutputFolder\ATTACH_THIS_FILE.html"

# Save HTML report
$HTMLReport | Out-File -FilePath $HTMLPath -Encoding UTF8

# Create simplified text version
$TextReport = @"
================================================================================
                    SYSTEM DIAGNOSTIC REPORT
================================================================================

Report ID: $ReportID
Generated: $ReportDate

USER INFORMATION
--------------------------------------------------------------------------------
Name: $($UserInfo.FullName)
Email: $($UserInfo.Email)
Computer: $($UserInfo.Computer)
Domain: $($UserInfo.Domain)

HARDWARE
--------------------------------------------------------------------------------
Manufacturer: $($HardwareInfo.Manufacturer)
Model: $($HardwareInfo.Model)
Serial Number: $($HardwareInfo.SerialNumber)
Processor: $($HardwareInfo.Processor)
RAM: $($HardwareInfo.TotalRAM) GB

OPERATING SYSTEM
--------------------------------------------------------------------------------
OS: $($OSInfo.Name)
Version: $($OSInfo.Version) (Build $($OSInfo.BuildNumber))
Uptime: $($OSInfo.UptimeDays) days

DISK INFORMATION
--------------------------------------------------------------------------------
"@

foreach ($Disk in $Disks) {
    $TextReport += "Drive $($Disk.Drive): $($Disk.FreeGB) GB free of $($Disk.TotalGB) GB ($($Disk.PercentFree)% free)`n"
}

$TextReport += @"

NETWORK
--------------------------------------------------------------------------------
Internet Status: $InternetStatus
"@

foreach ($Network in $NetworkInfo) {
    $TextReport += "Adapter: $($Network.Name) - $($Network.Status) - IP: $($Network.IPAddress)`n"
}

$TextReport += @"

================================================================================
                        END OF DIAGNOSTIC REPORT
================================================================================
"@

$TextReport | Out-File -FilePath $TxtPath -Encoding UTF8

# Copy HTML as the main attachment file
Copy-Item $HTMLPath $SummaryPath

Write-Host "  [OK] HTML Report: $HTMLPath" -ForegroundColor Green
Write-Host "  [OK] Text Report: $TxtPath" -ForegroundColor Green
Write-Host "  [OK] Attachment File: $SummaryPath" -ForegroundColor Green
Write-Host ""

# ============================================
# OPEN ITSM PORTAL
# ============================================
Write-Host "================================================================" -ForegroundColor Green
Write-Host "                   REPORT GENERATED" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Report Location: $OutputFolder" -ForegroundColor Cyan
Write-Host ""

# Determine which ITSM portal to open based on parameter
if ($SupportType -eq "Software") {
    $SelectedITSMUrl = $SoftwareITSMUrl
    $SupportTypeText = "Software Support"
    Write-Host "Support Type: SOFTWARE SUPPORT" -ForegroundColor Cyan
}
elseif ($SupportType -eq "Hardware") {
    $SelectedITSMUrl = $HardwareITSMUrl
    $SupportTypeText = "Hardware Support"
    Write-Host "Support Type: HARDWARE SUPPORT" -ForegroundColor Cyan
}
else {
    # No support type specified - skip ITSM opening
    $SkipITSMOpen = $true
    $SupportTypeText = "Not Specified"
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. The ITSM portal will open in your browser" -ForegroundColor White
Write-Host "  2. Fill in your issue description" -ForegroundColor White
Write-Host "  3. Attach the file: ATTACH_THIS_FILE.html" -ForegroundColor White
Write-Host "  4. Submit your request" -ForegroundColor White
Write-Host ""

# Open the folder with reports
Write-Host "Opening report folder..." -ForegroundColor Gray
Start-Process explorer.exe -ArgumentList $OutputFolder

Start-Sleep -Seconds 2

# Open ITSM portal
if (-not $SkipITSMOpen) {
    Write-Host "Opening ITSM portal ($SupportTypeText)..." -ForegroundColor Gray
    Write-Host ""
    
    # Check if URLs are configured
    $DefaultSoftwareUrl = ""
    $DefaultHardwareUrl = ""
    
    if ($SelectedITSMUrl -eq $DefaultSoftwareUrl -or $SelectedITSMUrl -eq $DefaultHardwareUrl) {
        Write-Host "[WARN] ITSM URLs not configured!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To configure ITSM URLs:" -ForegroundColor Cyan
        Write-Host "  1. Open the application" -ForegroundColor White
        Write-Host "  2. Go to Settings tab" -ForegroundColor White
        Write-Host "  3. Enter your Software and Hardware Support URLs" -ForegroundColor White
        Write-Host "  4. Click 'Save Settings'" -ForegroundColor White
        Write-Host ""
        Write-Host "Or edit settings.json manually:" -ForegroundColor Gray
        Write-Host "  Location: $SettingsPath" -ForegroundColor Gray
        Write-Host ""
    }
    else {
        try {
            Start-Process $SelectedITSMUrl
            Write-Host "  [OK] ITSM portal opened in browser" -ForegroundColor Green
        }
        catch {
            Write-Host "  [ERROR] Failed to open ITSM portal" -ForegroundColor Red
            Write-Host "  Please navigate to: $SelectedITSMUrl" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "              THANK YOU FOR SUBMITTING YOUR REQUEST" -ForegroundColor Cyan
#Write-Host "         IT Support will contact you shortly!" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Report ID: $ReportID" -ForegroundColor Yellow
Write-Host "Keep this ID for your reference!" -ForegroundColor Gray
Write-Host ""