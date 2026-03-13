# RunProfileRepair.ps1
# This script launches the Outlook Profile Repair Tool (SCANPST) via VBScript.

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Output "[$timestamp] $Message"
}

try {
    Write-Log "--- Launching Outlook Profile Repair Tool (ScanPST) ---"
    
    # Path to the VBS file (assumes it is copied into the Scripts folder)
    $vbsScriptPath = Join-Path $PSScriptRoot "LaunchScanPST.vbs"
    
    if (Test-Path $vbsScriptPath) {
        Write-Log "Launching tool via VBScript. Please check your screen for the window."
        
        # Use Start-Process to execute the VBS script using wscript.exe
        Start-Process -FilePath "wscript.exe" -ArgumentList "/nologo", "$vbsScriptPath" -WindowStyle Normal -ErrorAction Stop
        
        Write-Log "VBScript launched successfully."
    } else {
        Write-Log "ERROR: VBScript launcher not found at $vbsScriptPath"
    }

} catch {
    Write-Log "ERROR: An error occurred while attempting to launch the repair tool."
    Write-Output $_.Exception.Message
}