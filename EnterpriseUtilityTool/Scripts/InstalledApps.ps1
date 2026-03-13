Write-Output "Running Installed Software Report..."
try {
    # Get Computer Apps
    $InstalledComputerApps = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    # Get User Apps
    $InstalledUserApps = Get-ChildItem "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"

    $InstalledApps = @()
    # Process Computer-level apps
    foreach ($obj in $InstalledComputerApps) {
        $App = New-Object PSObject
        $App | Add-Member -type NoteProperty -Name 'DisplayName' -Value $obj.GetValue('DisplayName')
        $App | Add-Member -type NoteProperty -Name 'DisplayVersion' -Value $obj.GetValue('DisplayVersion')
        $App | Add-Member -type NoteProperty -Name 'InstallDate' -Value $obj.GetValue('InstallDate')
        $InstalledApps += $App
    }
    # Process User-level apps
    foreach ($obj in $InstalledUserApps) {
        $App = New-Object PSObject
        $App | Add-Member -type NoteProperty -Name 'DisplayName' -Value $obj.GetValue('DisplayName')
        $App | Add-Member -type NoteProperty -Name 'DisplayVersion' -Value $obj.GetValue('DisplayVersion')
        $App | Add-Member -type NoteProperty -Name 'InstallDate' -Value $obj.GetValue('InstallDate')
        $InstalledApps += $App
    }

    $InstalledApps = $InstalledApps | Sort-Object -Property DisplayName

    Write-Output "--- Installed Applications ---"
    $InstalledApps | Format-Table -AutoSize
}
catch {
    Write-Output "ERROR: An error occurred while retrieving installed software information."
    Write-Output $_.Exception.Message
}