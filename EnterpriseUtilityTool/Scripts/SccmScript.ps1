# SCCM Sync Script
try {
    Write-Output "=========================================="
    Write-Output "SCCM CLIENT SYNCHRONIZATION"
    Write-Output "=========================================="
    Write-Output ""
    Write-Output "Initiating SCCM client actions..."
    Write-Output ""
    
    $actions = @(
        @{Name="Machine Policy Retrieval"; ID="{00000000-0000-0000-0000-000000000021}"},
        @{Name="Machine Policy Evaluation"; ID="{00000000-0000-0000-0000-000000000022}"},
        @{Name="Software Updates Scan"; ID="{00000000-0000-0000-0000-000000000113}"},
        @{Name="Software Updates Deployment"; ID="{00000000-0000-0000-0000-000000000108}"}
    )
    
    foreach ($action in $actions) {
        Write-Output "Triggering: $($action.Name)..."
        try {
            Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule -ArgumentList $action.ID -ErrorAction Stop | Out-Null
            Write-Output " $($action.Name) triggered successfully"
        } catch {
            Write-Output "Could not trigger $($action.Name)"
        }
        Write-Output ""
    }
    
    Write-Output "=========================================="
    Write-Output " SCCM sync completed!"
    Write-Output "=========================================="
} catch {
    Write-Output "Error: $_"
    exit 1
}
