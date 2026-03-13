# Network Information Script

try {
    Write-Output "=========================================="
    Write-Output "NETWORK INFORMATION REPORT"
    Write-Output "=========================================="
    Write-Output ""
    
    # Get active network adapters
    $adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
    
    foreach ($adapter in $adapters) {
        Write-Output "Adapter: $($adapter.Name)"
        Write-Output "Description: $($adapter.InterfaceDescription)"
        Write-Output "Status: $($adapter.Status)"
        Write-Output "Link Speed: $($adapter.LinkSpeed)"
        Write-Output "MAC Address: $($adapter.MacAddress)"
        
        # Get IP configuration
        $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue | Where-Object {$_.AddressFamily -eq "IPv4"}
        if ($ipConfig) {
            Write-Output "IP Address: $($ipConfig.IPAddress)"
            Write-Output "Subnet Mask: $($ipConfig.PrefixLength)"
        }
        
        # Get DNS servers
        $dns = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($dns) {
            Write-Output "DNS Servers: $($dns.ServerAddresses -join ', ')"
        }
        
        Write-Output ""
        Write-Output "----------------------------------------"
        Write-Output ""
    }
    
    # Gateway information
    $gateway = Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($gateway) {
        Write-Output "Default Gateway: $($gateway.NextHop)"
    }
    
    Write-Output ""
    Write-Output "=========================================="
    
} catch {
    Write-Output "Error retrieving network information: $_"
    exit 1
}
