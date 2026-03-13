# This script triggers a Company Portal (Intune) sync.
# It is called by the C# host and writes output for the GUI.

try {
    Write-Output "INFO: Initiating Company Portal (Intune) policy sync..."
    
    # Trigger the sync using the dedicated URI [4]
    Start-Process "intunemanagementextension://syncapp"
    
    Write-Output "SUCCESS: Company Portal sync action has been initiated."
    Write-Output "INFO: The Company Portal app will now perform a sync in the background."
    
} catch {
    Write-Output "ERROR: An error occurred during the Intune sync attempt."
    Write-Output "ERROR: Exception: $($_.Exception.Message)"
} finally {
    Write-Output "INFO: Script execution finished."
}