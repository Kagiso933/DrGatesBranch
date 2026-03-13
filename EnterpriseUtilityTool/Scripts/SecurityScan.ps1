# Security Scan Script
try {
    Write-Output "=========================================="
    Write-Output "SECURITY STATUS SCAN"
    Write-Output "=========================================="
    Write-Output ""
    
    # Windows Defender Status
    Write-Output "Windows Defender Status..."
    Write-Output "--------------------------------"
    try {
        $defender = Get-MpComputerStatus
        Write-Output "Real-time Protection: $($defender.RealTimeProtectionEnabled)"
        Write-Output "Antivirus Enabled: $($defender.AntivirusEnabled)"
        Write-Output "Antispyware Enabled: $($defender.AntispywareEnabled)"
        Write-Output "Last Quick Scan: $($defender.QuickScanEndTime)"
        Write-Output "Last Full Scan: $($defender.FullScanEndTime)"
    } catch {
        Write-Output "Could not retrieve Windows Defender status"
    }
    
    Write-Output ""
    Write-Output "Firewall Status..."
    Write-Output "--------------------------------"
    $firewall = Get-NetFirewallProfile
    foreach ($profile in $firewall) {
        Write-Output "$($profile.Name) Profile: $($profile.Enabled)"
    }
    
    Write-Output ""
    Write-Output "Windows Update Status..."
    Write-Output "--------------------------------"
    $wuService = Get-Service -Name wuauserv
    Write-Output "Windows Update Service: $($wuService.Status)"
    
    Write-Output ""
    Write-Output "=========================================="
    Write-Output "Security scan completed!"
    Write-Output "=========================================="
} catch {
    Write-Output "Error: $_"
    exit 1
}
