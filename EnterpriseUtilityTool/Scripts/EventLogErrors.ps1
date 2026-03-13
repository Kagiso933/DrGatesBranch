try {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "RECENT EVENT LOG ERRORS (Modern)"
    Write-Host "==========================================" -ForegroundColor Cyan
    
    # FilterHashtable is the most efficient way to query logs
    $filter = @{
        LogName = 'System', 'Application'
        Level   = 2 # 2 = Error, 1 = Critical
    }

    $errors = Get-WinEvent -FilterHashtable $filter -MaxEvents 10 -ErrorAction SilentlyContinue

    if ($errors) {
        foreach ($event in $errors) {
            $time = $event.TimeCreated
            $source = $event.ProviderName
            $log = $event.LogName
            
            # Truncate message for readability
            $cleanMsg = $event.Message -replace "`r|`n", " " # Remove line breaks
            $shortMsg = if ($cleanMsg.Length -gt 200) { $cleanMsg.Substring(0, 200) + "..." } else { $cleanMsg }

            Write-Host "[$time] [$log] $source" -ForegroundColor Yellow
            Write-Host " Message: $shortMsg"
            Write-Output ""
        }
    } else {
        Write-Host "No recent errors found." -ForegroundColor Green
    }

    Write-Host "==========================================" -ForegroundColor Cyan
} catch {
    Write-Error "Failed to retrieve logs: $($_.Exception.Message)"
    exit 1
}