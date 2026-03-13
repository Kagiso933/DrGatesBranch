# This script automates disk cleanup tasks.
# It is called by the C# host and writes output for the GUI.

function Write-Log {
    param(
        [string]$Message
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Output "[$timestamp] $Message"
}

try {
    Write-Log -Message "--- Starting Disk Cleanup ---"
    
    # 1. Empty the Recycle Bin
    Write-Log -Message "Emptying Recycle Bin..."
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Log -Message "Recycle Bin has been emptied."
    
    # 2. Delete temporary files
    Write-Log -Message "Deleting temporary files..."
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log -Message "Temporary files deleted."
    
    # 3. Clear Windows Update history
    Write-Log -Message "Checking Windows Update Service..."
    
    # Stop the service only if it's running
    if ((Get-Service wuauserv).Status -eq 'Running') {
        Write-Log -Message "Stopping Windows Update service..."
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    
    Write-Log -Message "Clearing Windows Update cache..."
    Rename-Item -Path C:\Windows\SoftwareDistribution -NewName SoftwareDistribution.old -ErrorAction SilentlyContinue
    
    # Start the service only if it's not running
    if ((Get-Service wuauserv).Status -ne 'Running') {
        Write-Log -Message "Starting Windows Update service..."
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    }

    Write-Log -Message "Windows Update cache has been cleared."
    Write-Log -Message "--- Disk Cleanup Complete ---"

} catch {
    Write-Log -Message "An unhandled error occurred during the disk cleanup process."
    Write-Log -Message "Exception: $($_.Exception.Message)"
}