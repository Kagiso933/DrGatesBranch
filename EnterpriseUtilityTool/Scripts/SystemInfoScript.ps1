# This script retrieves and displays detailed system information.
# It is called by the C# host and writes output for the GUI.

function Write-Log {
    param(
        [string]$Message
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Output "[$timestamp] $Message"
}

try {
    Write-Log -Message "--- Retrieving System Information ---"
    
    # Get general computer information
    $ComputerInfo = Get-ComputerInfo -Property OsName, OsVersion, OsArchitecture, CsPhysicalMemory, CsManufacturer, CsModel, CsNumberOfProcessors | Select-Object -First 1
    
    # Get CPU and RAM details
    $Processor = Get-CimInstance Win32_Processor | Select-Object -First 1
    $OS = Get-Ciminstance Win32_OperatingSystem
    $RamUsage = (100 - ($OS.FreePhysicalMemory / $OS.TotalVisibleMemorySize) * 100)
    
    Write-Log -Message "Operating System: $($ComputerInfo.OsName)"
    Write-Log -Message "OS Version: $($ComputerInfo.OsVersion)"
    Write-Log -Message "Architecture: $($ComputerInfo.OsArchitecture)"
    Write-Log -Message "Manufacturer: $($ComputerInfo.CsManufacturer)"
    Write-Log -Message "Model: $($ComputerInfo.CsModel)"
    Write-Log -Message "Processor(s): $($ComputerInfo.CsNumberOfProcessors)"
    Write-Log -Message "CPU: $($Processor.Name)"
    Write-Log -Message "CPU Load: $($Processor.LoadPercentage)%"
    Write-Log -Message "Total RAM: $([math]::Round($OS.TotalVisibleMemorySize / 1MB)) GB"
    Write-Log -Message "RAM Usage: $([math]::Round($RamUsage, 2))%"
    
    Write-Log -Message "--- Check Complete ---"

} catch {
    Write-Log -Message "An unhandled error occurred during the system info check."
    Write-Log -Message "Exception: $($_.Exception.Message)"
}