# Clear-AllCache.ps1
# Comprehensive cache clearing for web browsers and applications

Write-Host "=== COMPREHENSIVE CACHE CLEANER ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will clear cache for:" -ForegroundColor Yellow
Write-Host "  • Microsoft Edge" -ForegroundColor Gray
Write-Host "  • Google Chrome" -ForegroundColor Gray
Write-Host "  • Mozilla Firefox" -ForegroundColor Gray
Write-Host "  • Microsoft Teams" -ForegroundColor Gray
Write-Host "  • Outlook" -ForegroundColor Gray
Write-Host "  • OneDrive" -ForegroundColor Gray
Write-Host "  • Windows Store" -ForegroundColor Gray
Write-Host "  • DNS Cache" -ForegroundColor Gray
Write-Host "  • Windows Temp Files" -ForegroundColor Gray
Write-Host ""

$TotalCleared = 0
$AppsCleared = 0

# Function to get folder size
function Get-FolderSize {
    param([string]$Path)
    if (Test-Path $Path) {
        return (Get-ChildItem $Path -Recurse -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1MB
    }
    return 0
}

# Function to clear folder
function Clear-Folder {
    param(
        [string]$Path,
        [string]$Name
    )
    
    if (Test-Path $Path) {
        $SizeBefore = Get-FolderSize -Path $Path
        
        try {
            Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue | 
                Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            
            $SizeAfter = Get-FolderSize -Path $Path
            $Cleared = $SizeBefore - $SizeAfter
            
            if ($Cleared -gt 0) {
                Write-Host "  ✓ $Name" -ForegroundColor Green -NoNewline
                Write-Host " - Cleared $([math]::Round($Cleared, 2)) MB" -ForegroundColor Gray
                return $Cleared
            }
            else {
                Write-Host "  ○ $Name - Already clean" -ForegroundColor Gray
                return 0
            }
        }
        catch {
            Write-Host "  ✗ $Name - Error: $($_.Exception.Message)" -ForegroundColor Red
            return 0
        }
    }
    else {
        Write-Host "  ○ $Name - Not found (app may not be installed)" -ForegroundColor Gray
        return 0
    }
}

# Microsoft Edge
Write-Host "[Microsoft Edge]" -ForegroundColor Yellow
$EdgePaths = @(
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Service Worker\CacheStorage",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Service Worker\ScriptCache"
)

foreach ($Path in $EdgePaths) {
    $Cleared = Clear-Folder -Path $Path -Name "Edge Cache"
    $TotalCleared += $Cleared
}
$AppsCleared++
Write-Host ""

# Google Chrome
Write-Host "[Google Chrome]" -ForegroundColor Yellow
$ChromePaths = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Service Worker\CacheStorage",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Service Worker\ScriptCache"
)

foreach ($Path in $ChromePaths) {
    $Cleared = Clear-Folder -Path $Path -Name "Chrome Cache"
    $TotalCleared += $Cleared
}
$AppsCleared++
Write-Host ""

# Mozilla Firefox
Write-Host "[Mozilla Firefox]" -ForegroundColor Yellow
$FirefoxProfile = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue | 
                  Select-Object -First 1

if ($FirefoxProfile) {
    $FirefoxPaths = @(
        "$($FirefoxProfile.FullName)\cache2",
        "$($FirefoxProfile.FullName)\startupCache",
        "$($FirefoxProfile.FullName)\thumbnails"
    )
    
    foreach ($Path in $FirefoxPaths) {
        $Cleared = Clear-Folder -Path $Path -Name "Firefox Cache"
        $TotalCleared += $Cleared
    }
}
else {
    Write-Host "  ○ Firefox - Not installed" -ForegroundColor Gray
}
$AppsCleared++
Write-Host ""

# Microsoft Teams
Write-Host "[Microsoft Teams]" -ForegroundColor Yellow
$TeamsPaths = @(
    "$env:APPDATA\Microsoft\Teams\Cache",
    "$env:APPDATA\Microsoft\Teams\blob_storage",
    "$env:APPDATA\Microsoft\Teams\databases",
    "$env:APPDATA\Microsoft\Teams\GPUcache",
    "$env:APPDATA\Microsoft\Teams\IndexedDB",
    "$env:APPDATA\Microsoft\Teams\Local Storage",
    "$env:APPDATA\Microsoft\Teams\tmp"
)

# Check if Teams is running
$TeamsRunning = Get-Process -Name Teams -ErrorAction SilentlyContinue

if ($TeamsRunning) {
    Write-Host "  ⚠ Teams is currently running" -ForegroundColor Yellow
    Write-Host "    Attempting to close Teams..." -ForegroundColor Gray
    
    try {
        Stop-Process -Name Teams -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Write-Host "  ✓ Teams closed successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Could not close Teams - please close manually" -ForegroundColor Red
    }
}

foreach ($Path in $TeamsPaths) {
    $Cleared = Clear-Folder -Path $Path -Name "Teams Cache"
    $TotalCleared += $Cleared
}
$AppsCleared++
Write-Host ""

# Outlook
Write-Host "[Microsoft Outlook]" -ForegroundColor Yellow
$OutlookPaths = @(
    "$env:LOCALAPPDATA\Microsoft\Outlook\RoamCache",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\Content.Outlook"
)

foreach ($Path in $OutlookPaths) {
    $Cleared = Clear-Folder -Path $Path -Name "Outlook Cache"
    $TotalCleared += $Cleared
}
$AppsCleared++
Write-Host ""

# OneDrive
Write-Host "[OneDrive]" -ForegroundColor Yellow
$OneDrivePaths = @(
    "$env:LOCALAPPDATA\Microsoft\OneDrive\logs",
    "$env:LOCALAPPDATA\Microsoft\OneDrive\setup\logs"
)

foreach ($Path in $OneDrivePaths) {
    $Cleared = Clear-Folder -Path $Path -Name "OneDrive Logs"
    $TotalCleared += $Cleared
}
$AppsCleared++
Write-Host ""

# Windows Store Cache
Write-Host "[Windows Store]" -ForegroundColor Yellow
try {
    Write-Host "  Resetting Windows Store cache..." -ForegroundColor Gray
    Start-Process wsreset.exe -WindowStyle Hidden
    Start-Sleep -Seconds 3
    Write-Host "  ✓ Store cache reset initiated" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Could not reset Store cache" -ForegroundColor Red
}
$AppsCleared++
Write-Host ""

# DNS Cache
Write-Host "[DNS Cache]" -ForegroundColor Yellow
try {
    Clear-DnsClientCache
    Write-Host "  ✓ DNS cache flushed successfully" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Could not flush DNS cache (may need admin rights)" -ForegroundColor Red
}
$AppsCleared++
Write-Host ""

# Windows Temp Files
Write-Host "[Windows Temp Files]" -ForegroundColor Yellow
$TempPaths = @(
    $env:TEMP,
    "C:\Windows\Temp",
    "$env:LOCALAPPDATA\Temp"
)

foreach ($Path in $TempPaths) {
    $Cleared = Clear-Folder -Path $Path -Name "Temp Files"
    $TotalCleared += $Cleared
}
$AppsCleared++
Write-Host ""

# Prefetch (if admin)
Write-Host "[Windows Prefetch]" -ForegroundColor Yellow
try {
    $Cleared = Clear-Folder -Path "C:\Windows\Prefetch" -Name "Prefetch Files"
    $TotalCleared += $Cleared
}
catch {
    Write-Host "  ○ Prefetch - Requires administrator privileges" -ForegroundColor Gray
}
Write-Host ""

# Thumbnail Cache
Write-Host "[Thumbnail Cache]" -ForegroundColor Yellow
$ThumbCachePath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
if (Test-Path $ThumbCachePath) {
    try {
        Get-ChildItem $ThumbCachePath -Filter "thumbcache_*.db" -ErrorAction SilentlyContinue | 
            Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Thumbnail cache cleared" -ForegroundColor Green
    }
    catch {
        Write-Host "  ○ Some thumbnail files in use" -ForegroundColor Gray
    }
}
Write-Host ""

# Summary
Write-Host "=== CLEANUP SUMMARY ===" -ForegroundColor Cyan
Write-Host "  Applications Processed: $AppsCleared" -ForegroundColor White
Write-Host "  Total Space Freed: $([math]::Round($TotalCleared, 2)) MB" -ForegroundColor Green
Write-Host ""

# Recommendations
Write-Host "[Recommendations]" -ForegroundColor Yellow

if ($TotalCleared -gt 100) {
    Write-Host "  ✓ Significant cache cleared - you may notice improved performance" -ForegroundColor Green
}
elseif ($TotalCleared -gt 10) {
    Write-Host "  ✓ Cache cleared successfully" -ForegroundColor Green
}
else {
    Write-Host "  ○ Minimal cache found - your system was already clean" -ForegroundColor Gray
}

Write-Host ""
Write-Host "  → Restart applications to ensure changes take effect" -ForegroundColor Cyan
Write-Host "  → If Teams was closed, you can reopen it now" -ForegroundColor Cyan
Write-Host "  → First launch of browsers may be slightly slower" -ForegroundColor Cyan
Write-Host ""

Write-Host "Cache cleanup completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
