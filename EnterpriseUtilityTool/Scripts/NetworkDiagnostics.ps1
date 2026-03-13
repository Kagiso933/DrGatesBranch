# Network Diagnostics Script

try {
    Write-Output "=========================================="
    Write-Output "NETWORK DIAGNOSTICS REPORT"
    Write-Output "=========================================="
    Write-Output ""
    
    # Test internet connectivity
    Write-Output "Testing Internet Connectivity..."
    Write-Output "--------------------------------"
    
    $targets = @(
        @{Name="Google DNS"; Address="8.8.8.8"},
        @{Name="Cloudflare DNS"; Address="1.1.1.1"},
        @{Name="Google.com"; Address="www.google.com"}
    )
    
    foreach ($target in $targets) {
        # Using -Count 1 for speed; -Quiet returns a boolean
        $result = Test-Connection -ComputerName $target.Address -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($result) {
            Write-Output "[OK] $($target.Name) ($($target.Address)): REACHABLE"
        } else {
            Write-Output "[FAIL] $($target.Name) ($($target.Address)): UNREACHABLE"
        }
    }
    
    Write-Output ""
    Write-Output "DNS Resolution Test..."
    Write-Output "--------------------------------"
    
    try {
        $dnsTest = Resolve-DnsName www.google.com -ErrorAction Stop
        Write-Output "[OK] DNS resolution working"
        # Selecting the first IP address found
        $resolvedIP = ($dnsTest | Where-Object { $_.IPAddress }).IPAddress | Select-Object -First 1
        Write-Output "     Resolved to: $resolvedIP"
    } catch {
        Write-Output "[FAIL] DNS resolution failed"
    }
    
    Write-Output ""
    Write-Output "Network Adapters Status..."
    Write-Output "--------------------------------"
    
    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue
    foreach ($adapter in $adapters) {
        $statusSym = if ($adapter.Status -eq "Up") { "[OK]" } else { "[DOWN]" }
        Write-Output "$statusSym $($adapter.Name): $($adapter.Status) ($($adapter.LinkSpeed))"
    }
    
    Write-Output ""
    Write-Output "IP Configuration..."
    Write-Output "--------------------------------"
    
    $ipconfigs = Get-NetIPConfiguration
    foreach ($config in $ipconfigs) {
        # Only show detailed info for active adapters with an IP address
        if ($config.IPv4Address) {
            Write-Output "Interface: $($config.InterfaceAlias)"
            Write-Output "  IPv4 Address: $($config.IPv4Address.IPAddress)"
            
            $gateway = if ($config.IPv4DefaultGateway) { $config.IPv4DefaultGateway.NextHop } else { "None" }
            Write-Output "  Default Gateway: $gateway"
            
            $dns = if ($config.DNSServer) { $config.DNSServer.ServerAddresses -join ', ' } else { "None" }
            Write-Output "  DNS Servers: $dns"
            Write-Output ""
        }
    }
    
    Write-Output "=========================================="
    Write-Output "Diagnostic complete!"
    Write-Output "=========================================="
    
} catch {
    Write-Error "An unexpected error occurred: $($_.Exception.Message)"
    exit 1
}