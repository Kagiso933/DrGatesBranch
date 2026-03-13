# This script maps all available printers from a list of print servers.

function Write-Log {
    param(
        [string]$Message
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Output "[$timestamp] $Message"
}

try {
    Write-Log -Message "--- Checking for Printers ---"

    # Check if any printers are already installed
    $existingPrinters = Get-Printer -ErrorAction SilentlyContinue

    if ($existingPrinters) {
        Write-Log -Message "Printers are already installed. No action needed."
        $existingPrinters | Format-Table -AutoSize
        return
    }

    Write-Log -Message "No printers found. Attempting to map all available printers..."
    
    # Define a list of your print servers
    $printServerNames = @(
        "cbwlddrapw165.capitecbank.fin.sky",
        "CBWLPPRAPW282.capitecbank.fin.sky",
        "cbwlpprapw283.capitecbank.fin.sky"
        #"cbwlddrapw165.capitecbank.fin.sky"
    )

    $mappedCount = 0
    foreach ($serverName in $printServerNames) {
        try {
            Write-Log -Message "Attempting to connect to print server: '$serverName'..."
            
            # Get a list of all printers on the current print server
            $availablePrinters = Get-Printer -ComputerName $serverName -ErrorAction Stop

            Write-Log -Message "Found $($availablePrinters.Count) printers on '$serverName'."

            if ($availablePrinters) {
                foreach ($printer in $availablePrinters) {
                    try {
                        Write-Log -Message "Attempting to map printer: '$($printer.Name)'"
                        
                        # Use the printer object directly to map it
                        Add-Printer -ConnectionName "\\$serverName\$($printer.Name)" -ErrorAction Stop
                        
                        $mappedCount++
                        Write-Log -Message "Printer '$($printer.Name)' has been successfully mapped."
                    }
                    catch {
                        Write-Log -Message "ERROR: Failed to map printer '$($printer.Name)'."
                        Write-Log -Message "Exception: $($_.Exception.Message)"
                    }
                }
            }
            
            # Exit the server loop after a successful connection to a server
            break
        }
        catch {
            Write-Log -Message "ERROR: Failed to connect to print server '$serverName'."
            Write-Log -Message "Exception: $($_.Exception.Message)"
        }
    }
    
    if ($mappedCount -gt 0) {
        Write-Log -Message "Successfully mapped $mappedCount printer(s)."
    } else {
        Write-Log -Message "ERROR: No printers could be mapped from any server."
        Write-Log -Message "Ensure the PC is on the network and has access to a print server."
    }

} catch {
    Write-Log -Message "An unhandled error occurred during the printer mapping process."
    Write-Log -Message "Exception: $($_.Exception.Message)"
}