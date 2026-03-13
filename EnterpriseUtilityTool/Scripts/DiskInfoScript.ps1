# Disk Information Script

try {
    Write-Output "=========================================="
    Write-Output "DISK INFORMATION REPORT"
    Write-Output "=========================================="
    Write-Output ""
    
    $disks = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3"
    
    foreach ($disk in $disks) {
        $totalSize = [math]::Round($disk.Size / 1GB, 2)
        $freeSpace = [math]::Round($disk.FreeSpace / 1GB, 2)
        $usedSpace = [math]::Round($totalSize - $freeSpace, 2)
        $percentFree = [math]::Round(($freeSpace / $totalSize) * 100, 2)
        
        Write-Output "Drive: $($disk.DeviceID)"
        Write-Output "Volume Name: $($disk.VolumeName)"
        Write-Output "File System: $($disk.FileSystem)"
        Write-Output "Total Size: $totalSize GB"
        Write-Output "Used Space: $usedSpace GB"
        Write-Output "Free Space: $freeSpace GB ($percentFree%)"
        
        if ($percentFree -lt 10) {
            Write-Output "STATUS: CRITICAL - Low disk space!"
        } elseif ($percentFree -lt 20) {
            Write-Output "STATUS: WARNING - Disk space running low"
        } else {
            Write-Output "STATUS: Healthy"
        }
        
        Write-Output ""
        Write-Output "----------------------------------------"
        Write-Output ""
    }
    
    Write-Output "=========================================="
    
} catch {
    Write-Output "Error retrieving disk information: $_"
    exit 1
}
