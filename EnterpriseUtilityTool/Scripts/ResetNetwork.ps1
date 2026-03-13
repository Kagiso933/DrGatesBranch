# Network Reset Script
try {
    Write-Output "=========================================="
    Write-Output "NETWORK STACK RESET"
    Write-Output "=========================================="
    Write-Output ""
    Write-Output "WARNING: This will reset network adapters"
    Write-Output "A system restart may be required."
    Write-Output ""
    
    Write-Output "Resetting IP configuration..."
    ipconfig /release
    ipconfig /renew
    
    Write-Output ""
    Write-Output "Flushing DNS..."
    ipconfig /flushdns
    
    Write-Output ""
    Write-Output "Resetting Winsock..."
    netsh winsock reset
    
    Write-Output ""
    Write-Output "Network reset completed!"
    Write-Output ""
    Write-Output "Please restart your computer for changes to take full effect."
    Write-Output "=========================================="
} catch {
    Write-Output "Error resetting network: $_"
    exit 1
}
