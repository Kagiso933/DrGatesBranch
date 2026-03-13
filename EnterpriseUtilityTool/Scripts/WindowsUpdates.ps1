Write-Output "Running Windows Updates Report..."
try {
    $compinfo = Get-ComputerInfo

    # Get Hotfixes
    $InstalledHotfixes = @()
    foreach ($fix in $($compinfo.OsHotFixes)) {
        $Hotfix = New-Object PSObject
        $Hotfix | Add-Member -type NoteProperty -Name 'HotFixID' -Value $fix.HotFixID
        $Hotfix | Add-Member -type NoteProperty -Name 'Description' -Value $fix.Description
        $Hotfix | Add-Member -type NoteProperty -Name 'InstalledOn' -Value $fix.InstalledOn
        $InstalledHotfixes += $Hotfix
    }
    $InstalledHotfixes = $InstalledHotfixes | Sort-Object -Property InstalledOn -Descending

    Write-Output "--- Recently Installed Hotfixes ---"
    if ($InstalledHotfixes.Count -gt 0) {
        $InstalledHotfixes | Select-Object HotFixID, Description, InstalledOn -First 10 | Format-Table -AutoSize
    } else {
        Write-Output "No hotfixes found."
    }
}
catch {
    Write-Output "ERROR: An error occurred while retrieving Windows Updates information."
    Write-Output $_.Exception.Message
}