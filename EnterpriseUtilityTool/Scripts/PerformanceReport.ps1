# Performance Report Script

try {
    Write-Output "=========================================="
    Write-Output "SYSTEM PERFORMANCE REPORT"
    Write-Output "=========================================="
    Write-Output ""
    
    # CPU Usage
    Write-Output "CPU Performance..."
    Write-Output "--------------------------------"
    $cpu = Get-WmiObject Win32_Processor
    $cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue
    Write-Output "Processor: $($cpu.Name)"
    Write-Output "Current Load: $([math]::Round($cpuLoad, 2))%"
    Write-Output ""
    
    # Memory Usage
    Write-Output "Memory Usage..."
    Write-Output "--------------------------------"
    $os = Get-WmiObject Win32_OperatingSystem
    $totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedRAM = [math]::Round($totalRAM - $freeRAM, 2)
    $percentUsed = [math]::Round(($usedRAM / $totalRAM) * 100, 2)
    
    Write-Output "Total RAM: $totalRAM GB"
    Write-Output "Used RAM: $usedRAM GB"
    Write-Output "Free RAM: $freeRAM GB"
    Write-Output "Usage: $percentUsed%"
    Write-Output ""
    
    # Disk Performance
    Write-Output "Disk Performance..."
    Write-Output "--------------------------------"
    $disks = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3"
    foreach ($disk in $disks) {
        $percentFree = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2)
        $status = if ($percentFree -lt 10) { "CRITICAL" } elseif ($percentFree -lt 20) { "WARNING" } else { "OK" }
        Write-Output "Drive $($disk.DeviceID) - Free: $percentFree% - Status: $status"
    }
    Write-Output ""
    
    # Top Processes by Memory
    Write-Output "Top 10 Processes by Memory Usage..."
    Write-Output "--------------------------------"
    $processes = Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10
    foreach ($proc in $processes) {
        $memMB = [math]::Round($proc.WorkingSet / 1MB, 2)
        Write-Output "$($proc.Name): $memMB MB"
    }
    
    Write-Output ""
    Write-Output "=========================================="
    Write-Output "Performance report complete!"
    Write-Output "=========================================="
    
} catch {
    Write-Output "Error generating performance report: $_"
    exit 1
}
