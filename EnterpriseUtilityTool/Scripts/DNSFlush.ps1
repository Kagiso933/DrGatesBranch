# DNS Cache Flush & Refresh Script
try {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "DNS CACHE FLUSH & REFRESH" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Output ""
    
    Write-Output "Step 1: Clearing DNS Client Cache..."
    # Using native PowerShell cmdlet for better reliability
    Clear-DnsClientCache -ErrorAction Stop
    Write-Host "[OK] Cache cleared successfully." -ForegroundColor Green
    
    Write-Output ""
    Write-Output "Step 2: Re-registering DNS records..."
    # Triggers a refresh of the computer's name and IP address with the DNS server
    ipconfig /registerdns | Out-Null
    Write-Host "[OK] Registration initiated." -ForegroundColor Green

    Write-Output ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host " DNS maintenance complete!" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Cyan
    
} catch {
    Write-Error "Failed to perform DNS maintenance: $($_.Exception.Message)"
    exit 1
}