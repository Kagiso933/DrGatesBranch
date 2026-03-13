# Temp Files Cleanup Script
try {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "TEMPORARY FILES CLEANUP" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Output ""
    
    # Unique list of paths to avoid double-cleaning
    $tempPaths = @($env:TEMP, "$env:SystemRoot\Temp", "$env:LOCALAPPDATA\Temp") | Select-Object -Unique
    
    $totalFreed = 0
    
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            Write-Output "Scanning: $path"
            
            # Calculate size before cleanup (handling nulls with [double])
            $filesBefore = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            $sizeBefore = ($filesBefore | Measure-Object -Property Length -Sum).Sum
            if ($null -eq $sizeBefore) { $sizeBefore = 0 }

            try {
                # Attempt deletion; -ErrorAction SilentlyContinue is vital as some files WILL be in use
                Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                
                # Calculate size after cleanup
                $filesAfter = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                $sizeAfter = ($filesAfter | Measure-Object -Property Length -Sum).Sum
                if ($null -eq $sizeAfter) { $sizeAfter = 0 }

                $freedBytes = $sizeBefore - $sizeAfter
                $freedMB = [math]::Round($freedBytes / 1MB, 2)
                
                if ($freedMB -gt 0) {
                    Write-Output "[OK] Freed: $freedMB MB"
                    $totalFreed += $freedMB
                } else {
                    Write-Output "[-] No files were removable (likely in use or already empty)"
                }
            } catch {
                Write-Output "[!] Error accessing folder: $($_.Exception.Message)"
            }
            Write-Output ""
        }
    }
    
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "[DONE] Cleanup completed!" -ForegroundColor Green
    Write-Host "Total space recovered: $totalFreed MB" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Cyan
} catch {
    Write-Error "Critical Script Error: $($_.Exception.Message)"
    exit 1
}