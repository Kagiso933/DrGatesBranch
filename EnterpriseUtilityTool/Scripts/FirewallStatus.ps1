# Firewall Status Script
try {
    Write-Output "=========================================="
    Write-Output "WINDOWS FIREWALL STATUS"
    Write-Output "=========================================="
    Write-Output ""
    
    $profiles = Get-NetFirewallProfile
    
    foreach ($profile in $profiles) {
        Write-Output "$($profile.Name) Profile"
        Write-Output "  Enabled: $($profile.Enabled)"
        Write-Output "  Default Inbound Action: $($profile.DefaultInboundAction)"
        Write-Output "  Default Outbound Action: $($profile.DefaultOutboundAction)"
        Write-Output ""
    }
    
    Write-Output "=========================================="
} catch {
    Write-Output "Error: $_"
    exit 1
}
