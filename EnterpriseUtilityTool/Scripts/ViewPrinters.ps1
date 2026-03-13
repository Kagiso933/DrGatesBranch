# View Printers Script

try {
    Write-Output "=========================================="
    Write-Output "PRINTER INFORMATION"
    Write-Output "=========================================="
    Write-Output ""
    
    $printers = Get-Printer
    
    if ($printers.Count -eq 0) {
        Write-Output "No printers found on this system."
    } else {
        Write-Output "Found $($printers.Count) printer(s):"
        Write-Output ""
        
        foreach ($printer in $printers) {
            Write-Output "Printer Name: $($printer.Name)"
            Write-Output "  Status: $($printer.PrinterStatus)"
            Write-Output "  Type: $($printer.Type)"
            Write-Output "  Port: $($printer.PortName)"
            Write-Output "  Shared: $($printer.Shared)"
            if ($printer.Location) {
                Write-Output "  Location: $($printer.Location)"
            }
            Write-Output ""
            Write-Output "----------------------------------------"
            Write-Output ""
        }
    }
    
    Write-Output "=========================================="
    
} catch {
    Write-Output "Error retrieving printer information: $_"
    exit 1
}
