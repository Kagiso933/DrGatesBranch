# ============================================================================
# System Uptime Check
# ============================================================================
# Description: Gets system uptime and provides restart recommendations
# Integrated with Dr Gates health status cards
# ============================================================================

$ErrorActionPreference = "Continue"

try {
    # Get last boot time
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $lastBootTime = $os.LastBootUpTime
    $currentTime = Get-Date
    
    # Calculate uptime
    $uptime = $currentTime - $lastBootTime
    
    # Format uptime
    $days = $uptime.Days
    $hours = $uptime.Hours
    $minutes = $uptime.Minutes
    
    # Determine status and details for health card
    $status = ""
    $details = ""
    
    # Format uptime display
    if ($days -eq 0 -and $hours -eq 0) {
        $uptimeDisplay = "$minutes minutes"
    } elseif ($days -eq 0) {
        $uptimeDisplay = "$hours hours, $minutes minutes"
    } else {
        $uptimeDisplay = "$days days, $hours hours"
    }
    
    # Determine health status
    if ($days -ge 14) {
        $status = "CRITICAL"
        $details = "$uptimeDisplay - Restart urgently recommended"
        
    } elseif ($days -ge 7) {
        $status = "WARNING"
        $details = "$uptimeDisplay - Restart recommended"
        
    } else {
        $status = "HEALTHY"
        $details = "$uptimeDisplay - Last restart: $($lastBootTime.ToString('MMM dd'))"
    }
    
    # Send STATUS_UPDATE for health card integration
    $statusUpdate = @{
        section = "uptime"
        status = $status
        details = $details
    }
    
    Write-Host "STATUS_UPDATE:$($statusUpdate | ConvertTo-Json -Compress)"
    
} catch {
    # Error state
    $errorUpdate = @{
        section = "uptime"
        status = "ERROR"
        details = "Could not retrieve uptime"
    }
    
    Write-Host "STATUS_UPDATE:$($errorUpdate | ConvertTo-Json -Compress)"
}
