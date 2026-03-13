# Startup Programs Script
try {
    Write-Output "=========================================="
    Write-Output "STARTUP PROGRAMS"
    Write-Output "=========================================="
    Write-Output ""
    
    Write-Output "Programs that run at startup:"
    Write-Output ""
    
    # Registry startup locations
    $startupPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    )
    
    foreach ($path in $startupPaths) {
        if (Test-Path $path) {
            $items = Get-ItemProperty -Path $path
            $items.PSObject.Properties | Where-Object {$_.Name -notlike "PS*"} | ForEach-Object {
                Write-Output "Name: $($_.Name)"
                Write-Output "  Command: $($_.Value)"
                Write-Output ""
            }
        }
    }
    
    # Startup folder
    $startupFolder = [Environment]::GetFolderPath('Startup')
    if (Test-Path $startupFolder) {
        $items = Get-ChildItem -Path $startupFolder
        if ($items) {
            Write-Output "Startup Folder Items:"
            foreach ($item in $items) {
                Write-Output "- $($item.Name)"
            }
        }
    }
    
    Write-Output ""
    Write-Output "=========================================="
} catch {
    Write-Output "Error: $_"
    exit 1
}
