# GPUpdate Script - Updates Group Policy

try {
    Write-Output "=========================================="
    Write-Output "GROUP POLICY UPDATE"
    Write-Output "=========================================="
    Write-Output ""
    Write-Output "Starting Group Policy update..."
    Write-Output "This may take a few minutes..."
    Write-Output ""
    
    # Run gpupdate
    $result = & gpupdate.exe /force 2>&1
    
    Write-Output $result
    Write-Output ""
    
    if ($LASTEXITCODE -eq 0) {
        Write-Output " Group Policy updated successfully!"
        Write-Output ""
        Write-Output "Note: Some changes may require a restart to take effect."
    } else {
        Write-Output "Group Policy update encountered issues."
        Write-Output "Exit Code: $LASTEXITCODE"
    }
    
    Write-Output ""
    Write-Output "=========================================="
    
} catch {
    Write-Output "Error running GPUpdate: $_"
    exit 1
}
