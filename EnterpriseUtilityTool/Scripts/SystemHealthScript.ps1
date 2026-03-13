# Get-SystemHealthReport.ps1
# Comprehensive system health check with real-time UI status updates

Write-Host "=== COMPREHENSIVE SYSTEM HEALTH REPORT ===" -ForegroundColor Cyan
Write-Host ""

# Initialize status variables
$InternetOn = $null
$ZIAOn = $null
$ZPAOn = $null
$SSIDName = $null

# Function to output status update in JSON format for UI
function Send-StatusUpdate {
    param(
        [string]$Section,
        [string]$Status,
        [string]$Details = ""
    )
    
    $statusObj = @{
        section = $Section
        status = $Status
        details = $Details
        timestamp = (Get-Date -Format 'HH:mm:ss')
    } | ConvertTo-Json -Compress
    
    Write-Output "STATUS_UPDATE:$statusObj"
}

# ============================================
# NETWORK CONNECTION DETECTION
# ============================================
Write-Host "[Network Connection]" -ForegroundColor Yellow
Send-StatusUpdate -Section "internet" -Status "CHECKING" -Details "Detecting network adapters..."

try {
    $NetworkConnection = Get-WmiObject Win32_NetworkAdapter | Where-Object {
        ($_.NetConnectionStatus -eq "2") -and 
        ($_.Name -notlike "*Virtual*" -and $_.Name -notlike "*Fortinet*" -and 
         $_.Name -notlike "*Cisco*" -and $_.Name -notlike "*PPPoP*")
    } | Select-Object NetConnectionID, Name, InterfaceIndex, NetConnectionStatus, AdapterType

    $IPAddress = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled -eq 'TRUE'}

    if ($NetworkConnection) {
        $ConnectionType = $NetworkConnection.NetConnectionID
        $AdapterName = $NetworkConnection.Name
        $IPAddr = $IPAddress.IPAddress[0]

        # Determine connection type
        Switch -Wildcard ($ConnectionType) {
            'Wi-Fi' {
                try {
                    $WLANInfo = netsh wlan show interfaces | Select-String ' SSID' | ConvertFrom-String -Delimiter ": "
                    $SSIDName = $WLANInfo.P2
                    Write-Host "  Type: Wi-Fi" -ForegroundColor Green
                    Write-Host "  Network: $SSIDName" -ForegroundColor Green
                    Send-StatusUpdate -Section "internet" -Status "CHECKING" -Details "Wi-Fi: $SSIDName"
                }
                catch {
                    Write-Host "  Type: Wi-Fi" -ForegroundColor Green
                    Write-Host "  Network: Unable to detect SSID" -ForegroundColor Yellow
                    Send-StatusUpdate -Section "internet" -Status "CHECKING" -Details "Wi-Fi Connected"
                }
            }
            '*Ethernet*' {
                $SSIDName = "Wired Network"
                Write-Host "  Type: Ethernet" -ForegroundColor Green
                Write-Host "  Network: Wired Connection" -ForegroundColor Green
                Send-StatusUpdate -Section "internet" -Status "CHECKING" -Details "Ethernet Connected"
            }
            'Cellular' {
                Write-Host "  Type: Cellular" -ForegroundColor Green
                Send-StatusUpdate -Section "internet" -Status "CHECKING" -Details "Cellular Connected"
            }
            default {
                Write-Host "  Type: $ConnectionType" -ForegroundColor Green
                Send-StatusUpdate -Section "internet" -Status "CHECKING" -Details "$ConnectionType"
            }
        }

        Write-Host "  Adapter: $AdapterName"
        Write-Host "  IP Address: $IPAddr"
    }
    else {
        Write-Host "  ✗ No active network connection detected" -ForegroundColor Red
        $SSIDName = "No Network"
        Send-StatusUpdate -Section "internet" -Status "ERROR" -Details "No network connection"
    }
}
catch {
    Write-Host "  ✗ Error detecting network: $($_.Exception.Message)" -ForegroundColor Red
    Send-StatusUpdate -Section "internet" -Status "ERROR" -Details "Network detection failed"
}

Write-Host ""

# ============================================
# INTERNET CONNECTIVITY CHECK
# ============================================
Write-Host "[Internet Connectivity]" -ForegroundColor Yellow
Send-StatusUpdate -Section "internet" -Status "CHECKING" -Details "Testing internet connection..."

if ($NetworkConnection) {
    try {
        # Test internet connectivity with timeout
        $WebTest = Invoke-RestMethod -Uri 'https://ipinfo.io/' -TimeoutSec 10 -ErrorAction Stop
        
        if ($WebTest) {
            $InternetOn = $true
            Write-Host "  Status: ✓ Connected" -ForegroundColor Green
            Write-Host "  Public IP: $($WebTest.ip)"
            Write-Host "  Location: $($WebTest.city), $($WebTest.region), $($WebTest.country)"
            Write-Host "  ISP: $($WebTest.org)"
            
            Send-StatusUpdate -Section "internet" -Status "CONNECTED" -Details "$($WebTest.city), $($WebTest.country)"
            
            # Store org for Zscaler check
            $OrgInfo = $WebTest.org
        }
        else {
            Write-Host "  Status: ✗ No Internet Connection" -ForegroundColor Red
            Write-Host "  Details: Web check failed" -ForegroundColor Red
            Send-StatusUpdate -Section "internet" -Status "ERROR" -Details "Web check failed"
        }
    }
    catch {
        Write-Host "  Status: ✗ No Internet Connection" -ForegroundColor Red
        Write-Host "  Details: Connectivity error - $($_.Exception.Message)" -ForegroundColor Red
        Send-StatusUpdate -Section "internet" -Status "ERROR" -Details "No internet access"
    }
}
else {
    Write-Host "  Status: ✗ No Internet Connection" -ForegroundColor Red
    Write-Host "  Details: No active network adapter" -ForegroundColor Red
    Send-StatusUpdate -Section "internet" -Status "ERROR" -Details "No network adapter"
}

Write-Host ""

# ============================================
# ZSCALER INTERNET ACCESS (ZIA) CHECK
# ============================================
Write-Host "[Zscaler Internet Access - ZIA]" -ForegroundColor Yellow
Send-StatusUpdate -Section "security" -Status "CHECKING" -Details "Checking security status..."

if ($InternetOn) {
    Switch -Wildcard ($OrgInfo) {
        '*Zscaler*' {
            $ZIAOn = $true
            Write-Host "  Status: ✓ Active (Cloud Proxy)" -ForegroundColor Green
            Write-Host "  Mode: Cloud-based filtering"
            Send-StatusUpdate -Section "security" -Status "ACTIVE" -Details "Zscaler Cloud Proxy"
        }
        '*CAPITEC*' {
            $ZIAOn = $true
            Write-Host "  Status: ✓ Active (On-Prem Proxy)" -ForegroundColor Green
            Write-Host "  Mode: On-premises filtering"
            Send-StatusUpdate -Section "security" -Status "ACTIVE" -Details "On-Prem Proxy"
        }
        default {
            Write-Host "  Status: ✗ Not Active" -ForegroundColor Yellow
            Write-Host "  Details: Direct internet connection (no proxy)"
            Send-StatusUpdate -Section "security" -Status "WARNING" -Details "No security proxy"
        }
    }
}
else {
    Write-Host "  Status: ✗ Not Active" -ForegroundColor Red
    Write-Host "  Details: No internet connectivity"
    Send-StatusUpdate -Section "security" -Status "ERROR" -Details "No internet"
}

Write-Host ""

# ============================================
# ZSCALER PRIVATE ACCESS (ZPA) CHECK
# ============================================
Write-Host "[Zscaler Private Access - ZPA]" -ForegroundColor Yellow
Send-StatusUpdate -Section "private" -Status "CHECKING" -Details "Checking VPN status..."

try {
    $ZPAState = (Get-ItemProperty -Path "HKCU:\Software\Zscaler\App" -Name "ZPA_State" -ErrorAction SilentlyContinue).ZPA_State
    
    if ($ZPAState -eq "TUNNEL_FORWARDING") {
        $ZPAOn = $true
        Write-Host "  Status: ✓ Active (Tunnel Forwarding)" -ForegroundColor Green
        Write-Host "  Mode: Private application access enabled"
        Send-StatusUpdate -Section "private" -Status "ACTIVE" -Details "Tunnel Active"
    }
    elseif ($ZPAState) {
        Write-Host "  Status: ◐ Connected but not forwarding" -ForegroundColor Yellow
        Write-Host "  State: $ZPAState"
        Send-StatusUpdate -Section "private" -Status "WARNING" -Details "Connected, not forwarding"
    }
    else {
        Write-Host "  Status: ✗ Not Active" -ForegroundColor Yellow
        Write-Host "  Details: Zscaler client not detected or ZPA disabled"
        Send-StatusUpdate -Section "private" -Status "INACTIVE" -Details "ZPA not enabled"
    }
}
catch {
    Write-Host "  Status: ✗ Not Active" -ForegroundColor Yellow
    Write-Host "  Details: Zscaler client not installed"
    Send-StatusUpdate -Section "private" -Status "INACTIVE" -Details "Client not installed"
}

Write-Host ""

# ============================================
# ACTIVE DIRECTORY STATUS
# ============================================
Write-Host "[Active Directory Status]" -ForegroundColor Yellow

try {
    $CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $Domain = $env:USERDOMAIN
    $DomainController = $env:LOGONSERVER -replace '\\\\', ''
    
    Write-Host "  Current User: $CurrentUser"
    Write-Host "  Domain: $Domain"
    Write-Host "  Domain Controller: $DomainController"
    
    # Check if account is locked
    try {
        $UserName = $env:USERNAME
        $ADUser = ([adsisearcher]"samaccountname=$UserName").FindOne()
        
        if ($ADUser) {
            $IsLocked = $ADUser.Properties.lockouttime
            if ($IsLocked -and $IsLocked -gt 0) {
                Write-Host "  Account Status: ✗ LOCKED" -ForegroundColor Red
                Write-Host "  Action Required: Contact IT to unlock account"
            }
            else {
                Write-Host "  Account Status: ✓ Active" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Host "  Account Status: Unable to verify (AD query failed)"
    }
}
catch {
    Write-Host "  Domain Status: Not domain-joined or offline"
}

Write-Host ""

# ============================================
# SYSTEM RESOURCES
# ============================================
Write-Host "[System Resources]" -ForegroundColor Yellow

$OS = Get-CimInstance Win32_OperatingSystem
$CPU = Get-CimInstance Win32_Processor

# Memory
$TotalRAM = [math]::Round($OS.TotalVisibleMemorySize / 1MB, 2)
$FreeRAM = [math]::Round($OS.FreePhysicalMemory / 1MB, 2)
$UsedRAM = $TotalRAM - $FreeRAM
$MemPercent = [math]::Round(($UsedRAM / $TotalRAM) * 100, 2)

Write-Host "  Memory Usage: $MemPercent% ($UsedRAM GB / $TotalRAM GB)"

# CPU
$CPULoad = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
if ($CPULoad) {
    Write-Host "  CPU Usage: $([math]::Round($CPULoad, 2))%"
}

# Disk
Write-Host ""
Write-Host "[Disk Health]" -ForegroundColor Yellow
Send-StatusUpdate -Section "disk" -Status "CHECKING" -Details "Checking disk space..."

$SystemDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$DiskFreeGB = [math]::Round($SystemDrive.FreeSpace / 1GB, 2)
$DiskTotalGB = [math]::Round($SystemDrive.Size / 1GB, 2)
$DiskPercent = [math]::Round(($DiskFreeGB / $DiskTotalGB) * 100, 2)

Write-Host "  Disk Space (C:): $DiskFreeGB GB free of $DiskTotalGB GB ($DiskPercent% free)"

if ($DiskPercent -lt 10) {
    Send-StatusUpdate -Section "disk" -Status "CRITICAL" -Details "$DiskFreeGB GB free (${DiskPercent}%)"
}
elseif ($DiskPercent -lt 20) {
    Send-StatusUpdate -Section "disk" -Status "WARNING" -Details "$DiskFreeGB GB free (${DiskPercent}%)"
}
else {
    Send-StatusUpdate -Section "disk" -Status "HEALTHY" -Details "$DiskFreeGB GB free (${DiskPercent}%)"
}

Write-Host ""

# ============================================
# OVERALL HEALTH STATUS
# ============================================
Write-Host "=== OVERALL HEALTH STATUS ===" -ForegroundColor Cyan

$Issues = @()
if (-not $NetworkConnection) { $Issues += "No network connection" }
if (-not $InternetOn) { $Issues += "No internet connectivity" }
if ($MemPercent -gt 90) { $Issues += "High memory usage ($MemPercent%)" }
if ($DiskPercent -lt 10) { $Issues += "Low disk space ($DiskPercent% free)" }

if ($Issues.Count -eq 0) {
    Write-Host "✓ System health is GOOD" -ForegroundColor Green
    Write-Host "  Network: Connected"
    if ($InternetOn) { Write-Host "  Internet: Active" }
    if ($ZIAOn) { Write-Host "  Zscaler ZIA: Enabled" }
    if ($ZPAOn) { Write-Host "  Zscaler ZPA: Enabled" }
}
else {
    Write-Host "⚠ Issues detected:" -ForegroundColor Yellow
    foreach ($Issue in $Issues) {
        Write-Host "  - $Issue" -ForegroundColor Yellow
    }
}

Write-Host ""

# ============================================
# RECOMMENDATIONS
# ============================================
if ($Issues.Count -gt 0) {
    Write-Host "[Recommended Actions]" -ForegroundColor Cyan
    
    if (-not $NetworkConnection) {
        Write-Host "  → Check network cable or WiFi connection"
    }
    if (-not $InternetOn) {
        Write-Host "  → Verify router/modem connectivity"
        Write-Host "  → Try flushing DNS: Clear DNS Cache tool"
    }
    if (-not $ZIAOn -and $InternetOn) {
        Write-Host "  → Contact IT if Zscaler protection is required"
    }
    if ($MemPercent -gt 90) {
        Write-Host "  → Close unused applications"
        Write-Host "  → Restart computer to free memory"
    }
    if ($DiskPercent -lt 10) {
        Write-Host "  → Run Disk Cleanup tool"
        Write-Host "  → Clear temporary files"
    }
    
    Write-Host ""
}

Write-Host "Report completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# Final summary output
Send-StatusUpdate -Section "complete" -Status "DONE" -Details "Health check completed"
