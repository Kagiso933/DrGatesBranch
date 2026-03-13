# Browser Cache Clear Script
try {
    Write-Output "=========================================="
    Write-Output "BROWSER CACHE CLEANUP"
    Write-Output "=========================================="
    Write-Output ""
    
    # Close browsers
    $browsers = @("chrome", "msedge", "firefox", "iexplore")
    foreach ($browser in $browsers) {
        $process = Get-Process -Name $browser -ErrorAction SilentlyContinue
        if ($process) {
            Write-Output "Closing $browser..."
            Stop-Process -Name $browser -Force -ErrorAction SilentlyContinue
        }
    }
    
    Start-Sleep -Seconds 2
    
    # Clear Edge cache
    Write-Output "Clearing Microsoft Edge cache..."
    $edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
    if (Test-Path $edgePath) {
        Remove-Item -Path "$edgePath\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Output " Edge cache cleared"
    }
    
    # Clear Chrome cache
    Write-Output "Clearing Chrome cache..."
    $chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
    if (Test-Path $chromePath) {
        Remove-Item -Path "$chromePath\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Output "Chrome cache cleared"
    }
    
    Write-Output ""
    Write-Output "Browser cache cleanup completed!"
    Write-Output "=========================================="
} catch {
    Write-Output "Error: $_"
    exit 1
}