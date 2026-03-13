# Test-OneDriveBackup.ps1
# Comprehensive OneDrive Diagnostic and Repair Tool - v3 (Multi-Path Support)

Write-Host "=== ONEDRIVE ADVANCED DIAGNOSTIC & REPAIR ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

$OneDriveIssues = 0
$OneDriveWarnings = 0

# --- PATH DETECTION ---
$UserPath = "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
$SystemPath = "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe"
$SystemPathx86 = "${env:ProgramFiles(x86)}\Microsoft OneDrive\OneDrive.exe"

if (Test-Path $SystemPath) { $OneDrivePath = $SystemPath }
elseif (Test-Path $SystemPathx86) { $OneDrivePath = $SystemPathx86 }
else { $OneDrivePath = $UserPath }

# --- HELPER FUNCTIONS ---

function Invoke-OneDriveReset {
    Write-Host "[!] INITIATING FULL ONEDRIVE RESET..." -ForegroundColor Red -BackgroundColor Black
    Write-Host "This will clear the sync cache and re-index files. No data will be deleted." -ForegroundColor Yellow
    
    Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    
    if (Test-Path $OneDrivePath) {
        Start-Process $OneDrivePath -ArgumentList "/reset"
        Write-Host "Reset command sent. OneDrive may take a few minutes to restart automatically." -ForegroundColor Green
    }
}

function Restart-OneDriveProcess {
    Write-Host "Attempting to restart OneDrive process..." -ForegroundColor Yellow
    Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (Test-Path $OneDrivePath) {
        Start-Process $OneDrivePath
        Write-Host "OneDrive restart command issued." -ForegroundColor Green
    }
}

# --- 1. INSTALLATION CHECK ---
Write-Host "[1/7] OneDrive Installation" -ForegroundColor Yellow
if (Test-Path $OneDrivePath) {
    $Version = (Get-Item $OneDrivePath).VersionInfo.FileVersion
    Write-Host "  Installed: Yes (Path: $OneDrivePath)" -ForegroundColor Green
    Write-Host "  Version: $Version" -ForegroundColor Gray
}
else {
    Write-Host "  CRITICAL: OneDrive was not found in AppData or Program Files." -ForegroundColor Red
    $OneDriveIssues++
    return 
}

# --- 2. SERVICE STATUS ---
Write-Host "[2/7] Service Status" -ForegroundColor Yellow
$Process = Get-Process -Name OneDrive -ErrorAction SilentlyContinue
if ($Process) {
    Write-Host "  Running: Yes (PID: $($Process.Id))" -ForegroundColor Green
}
else {
    Write-Host "  Running: NO. Attempting auto-start..." -ForegroundColor Red
    Restart-OneDriveProcess
    $OneDriveWarnings++
}

# --- 3. CONFIGURATION & ACCOUNTS ---
Write-Host "[3/7] Configuration" -ForegroundColor Yellow
$Accounts = Get-ChildItem "HKCU:\Software\Microsoft\OneDrive\Accounts" -ErrorAction SilentlyContinue
$SyncRoot = "" # Will be set by account check

if ($Accounts) {
    foreach ($Acc in $Accounts) {
        $Props = Get-ItemProperty $Acc.PSPath
        Write-Host "  Account: $($Props.UserEmail)" -ForegroundColor White
        Write-Host "  Local Path: $($Props.UserFolder)" -ForegroundColor Gray
        $SyncRoot = $Props.UserFolder
        
        if (-not (Test-Path $Props.UserFolder)) {
            Write-Host "  ERROR: Local sync folder is missing!" -ForegroundColor Red
            $OneDriveIssues++
        }
    }
} else {
    Write-Host "  No OneDrive accounts configured on this profile." -ForegroundColor Yellow
    $OneDriveWarnings++
}

# Files On-Demand check
$FOD = Get-ItemProperty -Path "HKCU:\Software\Microsoft\OneDrive" -Name "FilesOnDemandEnabled" -ErrorAction SilentlyContinue
if ($null -ne $FOD -and $FOD.FilesOnDemandEnabled -eq 1) {
    Write-Host "  Files On-Demand: ENABLED" -ForegroundColor Cyan
}

# --- 4. KNOWN FOLDER BACKUP (KFM) ---
Write-Host "[4/7] Known Folder Backup" -ForegroundColor Yellow
$Folders = @("Desktop", "MyDocuments", "MyPictures")
foreach ($F in $Folders) {
    $Path = [Environment]::GetFolderPath($F)
    if ($Path -match "OneDrive") {
        Write-Host "  ${F}: BACKED UP" -ForegroundColor Green
    } else {
        Write-Host "  ${F}: LOCAL ONLY" -ForegroundColor Yellow
        $OneDriveWarnings++
    }
}

# --- 5. SYNC CONFLICTS ---
Write-Host "[5/7] Sync Conflicts" -ForegroundColor Yellow
if ([string]::IsNullOrEmpty($SyncRoot)) { $SyncRoot = [Environment]::GetFolderPath('UserProfile') + "\OneDrive" }

if (Test-Path $SyncRoot) {
    $Conflicts = Get-ChildItem $SyncRoot -Recurse -Include "*-Copy.*", "*-PC.*" -ErrorAction SilentlyContinue
    if ($Conflicts) {
        Write-Host "  Found $($Conflicts.Count) conflict files." -ForegroundColor Red
        $Conflicts | Select-Object -First 3 | ForEach-Object { Write-Host "    - $($_.Name)" -ForegroundColor Gray }
        $OneDriveWarnings++
    } else {
        Write-Host "  No conflicts detected." -ForegroundColor Green
    }
}

# --- 6. WRITE TEST ---
Write-Host "[6/7] Write Test" -ForegroundColor Yellow
try {
    if (Test-Path $SyncRoot) {
        $TestFile = "$SyncRoot\SyncTest_$(Get-Date -UFormat '%s').txt"
        "Test" | Out-File $TestFile -ErrorAction Stop
        if (Test-Path $TestFile) {
            Remove-Item $TestFile
            Write-Host "  Sync Folder Write Test: PASSED" -ForegroundColor Green
        }
    } else {
        Write-Host "  Write Test skipped: Sync folder not found." -ForegroundColor Gray
    }
} catch {
    Write-Host "  Sync Folder Write Test: FAILED ($($_.Exception.Message))" -ForegroundColor Red
    $OneDriveIssues++
}

# --- SUMMARY ---
Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
$IssueColor = "Green"; if ($OneDriveIssues -gt 0) { $IssueColor = "Red" }
$WarnColor = "Green"; if ($OneDriveWarnings -gt 0) { $WarnColor = "Yellow" }

Write-Host "Critical Issues: $OneDriveIssues" -ForegroundColor $IssueColor
Write-Host "Warnings: $OneDriveWarnings" -ForegroundColor $WarnColor
Write-Host ""

if ($OneDriveIssues -gt 0) {
    $Action = Read-Host "Critical issues found. Attempt RESET? (Y/N)"
    if ($Action -eq "Y") { Invoke-OneDriveReset }
}
elseif ($OneDriveWarnings -gt 0) {
    Write-Host "Review warnings. Ensure KFM (Manage Backup) is enabled in OneDrive settings." -ForegroundColor Yellow
}

Write-Host "Done."