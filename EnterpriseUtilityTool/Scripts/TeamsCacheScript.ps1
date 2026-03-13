# This script closes Teams and clears its cache for the new client.
# It is called by the C# host and writes output for the GUI.

try {
    Write-Output "INFO: Attempting to close Teams..."
    # Stop the Teams process to prevent file-in-use errors
    Get-Process -ProcessName ms-teams -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 3
    
    Write-Output "INFO: Teams process successfully stopped."
    
    Write-Output "INFO: Clearing Teams cache..."
    $teamsCachePath = "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache"
    
    # Check if the cache path exists before attempting to delete
    if (Test-Path $teamsCachePath) {
        Remove-Item -Path "$teamsCachePath\*" -Recurse -Force
        Write-Output "SUCCESS: Teams cache has been cleared."
    } else {
        Write-Output "WARNING: Teams cache directory not found. No action taken."
    }
    
} catch {
    Write-Output "ERROR: An error occurred during the cache clearing process."
    Write-Output "ERROR: Exception: $($_.Exception.Message)"
} finally {
    Write-Output "INFO: Script execution finished."
}