<#
.SYNOPSIS
    Claude Code Deployment for Dr Gates
.DESCRIPTION
    Step-by-step Claude Code installation with status updates for Dr Gates UI
.NOTES
    - Sends STATUS_UPDATE messages for Dr Gates UI
    - Step-by-step with pause breaks or auto-continue mode
    - Comprehensive logging and error handling
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter()]
    [string]$TargetUsername,

    [Parameter()]
    [string]$LogPath = "$env:ProgramData\DrGates\Logs\ClaudeCodeSetup.log",
    
    [Parameter()]
    [switch]$AutoContinue
)

# ==========================
# STATUS UPDATES
# ==========================
function Send-StatusUpdate {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('internet', 'security', 'private', 'disk')]
        [string]$Section,
        
        [Parameter(Mandatory)]
        [ValidateSet('CHECKING', 'CONNECTED', 'ACTIVE', 'HEALTHY', 'ERROR', 'WARNING', 'INACTIVE', 'CRITICAL')]
        [string]$Status,
        
        [Parameter()]
        [string]$Details = ""
    )
    
    $statusJson = @{
        section = $Section
        status = $Status
        details = $Details
    } | ConvertTo-Json -Compress
    
    Write-Host "STATUS_UPDATE:$statusJson"
}

# ==========================
# LOGGING
# ==========================
function Write-Log {
    param(
        [string]$Message, 
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    $logDir = Split-Path $LogPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    Add-Content -Path $LogPath -Value $logMessage -ErrorAction SilentlyContinue

    switch ($Level) {
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default   { Write-Host $logMessage -ForegroundColor Cyan }
    }
}

# ==========================
# PROGRESS DISPLAY
# ==========================
function Show-Step {
    param(
        [int]$StepNumber,
        [string]$Title,
        [string]$Description
    )
    
    Write-Host ""
    Write-Host "--------------------------------------------------------------------------------------------------------------" -ForegroundColor Cyan
    # FIX: Use ${StepNumber} to properly delimit the variable before the colon
    Write-Host " STEP ${StepNumber}: $Title" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------------------------------------------------------------ê" -ForegroundColor Cyan
    Write-Host " $Description" -ForegroundColor White
    Write-Host ""
}

function Show-Pause {
    param(
        [string]$Message = "Press any key to continue...",
        [int]$Seconds = 3
    )
    
    if ($AutoContinue) {
        Write-Host ""
        Write-Host "[AUTO-CONTINUE] Proceeding in $Seconds seconds..." -ForegroundColor Green
        Start-Sleep -Seconds $Seconds
        Write-Host ""
        return
    }
    
    if ($Seconds -gt 0) {
        Write-Host ""
        Write-Host "[PAUSE] $Message (auto-continuing in $Seconds seconds)" -ForegroundColor Yellow
        Start-Sleep -Seconds $Seconds
    } else {
        Write-Host ""
        Write-Host "[PAUSE] $Message" -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    Write-Host ""
}

# ==========================
# INITIALIZATION
# ==========================
Write-Log "--------------------------------------------------------------------------------------------------------------ê" "INFO"
Write-Log "Dr Gates - Claude Code Deployment" "INFO"
Write-Log "--------------------------------------------------------------------------------------------------------------" "INFO"

Send-StatusUpdate -Section "private" -Status "CHECKING" -Details "Initializing deployment..."

# ==========================
# STEP 1: PRE-FLIGHT CHECKS
# ==========================
Show-Step -StepNumber 1 -Title "Pre-Flight Checks" -Description "Verifying system requirements and environment"

Write-Log "Checking admin privileges..." "INFO"
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Log "ERROR: This script requires administrator privileges" "ERROR"
    Send-StatusUpdate -Section "security" -Status "ERROR" -Details "Admin privileges required"
    Write-Host ""
    Write-Host "This script must be run as Administrator!" -ForegroundColor Red
    exit 1
}

Write-Log "NB-  Running with administrator privileges" "SUCCESS"
Write-Host "  NB-  Administrator privileges confirmed" -ForegroundColor Green
Send-StatusUpdate -Section "security" -Status "ACTIVE" -Details "Running as admin"

# Detect logged-in user
Write-Host "  Detecting logged-in user..." -ForegroundColor Cyan

function Get-CurrentLoggedInUser {
    try {
        $quser = quser 2>&1
        if ($quser -match "Active") {
            $lines = $quser | Select-Object -Skip 1
            foreach ($line in $lines) {
                if ($line -match '^\s*(\S+)\s+.*Active') {
                    return $matches[1]
                }
            }
        }

        # Fallback to WMI
        $user = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty UserName
        if ($user -and $user.Contains('\')) {
            return $user.Split('\')[1]
        }
    }
    catch {
        Write-Log "Error detecting user: $_" "ERROR"
    }
    return $null
}

if (-not $TargetUsername) {
    $TargetUsername = Get-CurrentLoggedInUser
}

if (-not $TargetUsername) {
    Write-Log "Cannot determine target user. Exiting." "ERROR"
    Send-StatusUpdate -Section "private" -Status "ERROR" -Details "User detection failed"
    Write-Host "  NB- Could not detect logged-in user" -ForegroundColor Red
    exit 1
}

Write-Log "NB-  Target User: $TargetUsername" "SUCCESS"
Write-Host "  NB-  Target User: $TargetUsername" -ForegroundColor Green

# Check internet connectivity
Write-Host "  Testing internet connectivity..." -ForegroundColor Cyan
Send-StatusUpdate -Section "internet" -Status "CHECKING" -Details "Testing connection..."

try {
    $pingResult = Test-Connection -ComputerName "8.8.8.8" -Count 2 -Quiet
    if ($pingResult) {
        Write-Log "NB-  Internet connection available" "SUCCESS"
        Write-Host "  NB-  Internet connection verified" -ForegroundColor Green
        Send-StatusUpdate -Section "internet" -Status "CONNECTED" -Details "8.8.8.8 reachable"
    } else {
        Write-Log "WARNING: Internet connection test failed" "WARNING"
        Write-Host "  NB- † Internet connection test failed" -ForegroundColor Yellow
        Send-StatusUpdate -Section "internet" -Status "WARNING" -Details "Limited connectivity"
    }
}
catch {
    Write-Log "WARNING: Could not verify internet connectivity" "WARNING"
    Write-Host "  NB- † Could not verify internet connectivity" -ForegroundColor Yellow
    Send-StatusUpdate -Section "internet" -Status "WARNING" -Details "Connection test failed"
}

Write-Host ""
Write-Host "-ê-ê-ê Pre-Flight Summary -ê-ê-ê" -ForegroundColor Green
Write-Host "  User:     $TargetUsername" -ForegroundColor Cyan
Write-Host "  Admin:    Yes" -ForegroundColor Green
Write-Host "  Internet: $(if ($pingResult) { 'Connected' } else { 'Limited' })" -ForegroundColor $(if ($pingResult) { 'Green' } else { 'Yellow' })
Write-Host ""

Show-Pause -Message "Review pre-flight checks above. Press any key to continue..." -Seconds 5

# ==========================
# STEP 2: NODE.JS INSTALLATION
# ==========================
Show-Step -StepNumber 2 -Title "Node.js Installation" -Description "Installing or verifying Node.js LTS"

Send-StatusUpdate -Section "private" -Status "CHECKING" -Details "Checking Node.js..."
Write-Host "  Checking for existing Node.js installation..." -ForegroundColor Cyan

$nodeInstalled = Get-Command node -ErrorAction SilentlyContinue

if ($nodeInstalled) {
    $nodeVersion = & node --version 2>$null
    Write-Log "NB-  Node.js already installed: $nodeVersion" "SUCCESS"
    Write-Host "  NB-  Node.js is already installed: $nodeVersion" -ForegroundColor Green
    Send-StatusUpdate -Section "private" -Status "ACTIVE" -Details "Node.js $nodeVersion installed"
    
    Write-Host ""
    Write-Host "  Skipping Node.js installation (already present)" -ForegroundColor Cyan
} else {
    Write-Log "Node.js not found. Installing Node.js LTS..." "INFO"
    Write-Host "  Node.js not found. Installing via winget..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  This may take a few minutes..." -ForegroundColor Yellow
    
    Send-StatusUpdate -Section "private" -Status "CHECKING" -Details "Installing Node.js..."

    try {
        Write-Host "  Executing: winget install OpenJS.NodeJS.LTS..." -ForegroundColor Cyan
        $wingetResult = winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements --silent 2>&1 | Out-String
        Write-Log "Winget output: $wingetResult" "INFO"

        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
            Write-Log "NB-  Node.js installation completed" "SUCCESS"
            Write-Host "  NB-  Node.js installed successfully!" -ForegroundColor Green

            # Refresh PATH
            Write-Host "  Refreshing environment PATH..." -ForegroundColor Cyan
            $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
            $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
            $env:Path = "$machinePath;$userPath"

            # Wait for Node.js to be available
            Write-Host "  Waiting for Node.js to initialize (5 seconds)..." -ForegroundColor Cyan
            Start-Sleep -Seconds 5

            # Verify installation
            Write-Host "  Verifying Node.js installation..." -ForegroundColor Cyan
            $nodeCheck = Get-Command node -ErrorAction SilentlyContinue
            
            if ($nodeCheck) {
                $nodeVersion = & node --version
                Write-Log "NB-  Verified Node.js: $nodeVersion" "SUCCESS"
                Write-Host "  NB-  Node.js $nodeVersion verified and ready" -ForegroundColor Green
                Send-StatusUpdate -Section "private" -Status "ACTIVE" -Details "Node.js $nodeVersion ready"
            } else {
                Write-Log "Node.js not found in PATH after installation. Attempting manual PATH update..." "WARNING"
                Write-Host "  NB- † Node.js not found in PATH. Attempting manual fix..." -ForegroundColor Yellow

                # Common Node.js installation paths
                $possiblePaths = @(
                    "${env:ProgramFiles}\nodejs",
                    "${env:ProgramFiles(x86)}\nodejs",
                    "$env:LOCALAPPDATA\Programs\nodejs"
                )

                $found = $false
                foreach ($path in $possiblePaths) {
                    if (Test-Path $path) {
                        $env:Path += ";$path"
                        Write-Log "Added to PATH: $path" "INFO"
                        Write-Host "    Added to PATH: $path" -ForegroundColor Cyan
                        $found = $true
                    }
                }

                if ($found) {
                    $nodeCheck = Get-Command node -ErrorAction SilentlyContinue
                    if ($nodeCheck) {
                        $nodeVersion = & node --version
                        Write-Log "NB-  Node.js now available: $nodeVersion" "SUCCESS"
                        Write-Host "  NB-  Node.js fixed and verified: $nodeVersion" -ForegroundColor Green
                        Send-StatusUpdate -Section "private" -Status "ACTIVE" -Details "Node.js $nodeVersion ready"
                    } else {
                        Write-Log "ERROR: Node.js still not available after PATH update" "ERROR"
                        Write-Host "  NB- Node.js installation failed - cannot locate executable" -ForegroundColor Red
                        Send-StatusUpdate -Section "private" -Status "ERROR" -Details "Node.js not found"
                        Write-Host ""
                        Write-Host "Manual intervention required. Please install Node.js manually from nodejs.org" -ForegroundColor Red
                        exit 1
                    }
                } else {
                    Write-Log "ERROR: Node.js installation directory not found" "ERROR"
                    Write-Host "  NB- Node.js installation directory not found" -ForegroundColor Red
                    Send-StatusUpdate -Section "private" -Status "ERROR" -Details "Installation failed"
                    exit 1
                }
            }
        } else {
            Write-Log "ERROR: Node.js installation failed. Exit code: $LASTEXITCODE" "ERROR"
            Write-Host "  NB- Node.js installation failed (Exit code: $LASTEXITCODE)" -ForegroundColor Red
            Send-StatusUpdate -Section "private" -Status "ERROR" -Details "Installation failed"
            Write-Host ""
            Write-Host "Winget output:" -ForegroundColor Yellow
            Write-Host $wingetResult -ForegroundColor Gray
            exit 1
        }
    }
    catch {
        Write-Log "ERROR: Exception during Node.js installation: $_" "ERROR"
        Write-Host "  NB- Exception during Node.js installation" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Red
        Send-StatusUpdate -Section "private" -Status "ERROR" -Details "Exception occurred"
        exit 1
    }
}

Write-Host ""
Show-Pause -Message "Node.js setup complete. Press any key to continue..." -Seconds 3

# ==========================
# FINAL SUMMARY
# ==========================
Write-Host ""
Write-Host "--------------------------------------------------------------------------------------------------------------ê" -ForegroundColor Green
Write-Host " DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "--------------------------------------------------------------------------------------------------------------ê" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps for user ($TargetUsername):" -ForegroundColor Cyan
Write-Host "  1. Open a new PowerShell or Command Prompt" -ForegroundColor White
Write-Host "  2. Run: npx --yes @anthropic-ai/claude-code" -ForegroundColor White
Write-Host "  3. Follow authentication prompts" -ForegroundColor White
Write-Host ""
Write-Host "Log file location:" -ForegroundColor Cyan
Write-Host "  $LogPath" -ForegroundColor White
Write-Host ""
Write-Host "--------------------------------------------------------------------------------------------------------------ê" -ForegroundColor Green

Write-Log "--------------------------------------------------------------------------------------------------------------ê" "SUCCESS"
Write-Log "Deployment Complete!" "SUCCESS"
Write-Log "--------------------------------------------------------------------------------------------------------------ê" "SUCCESS"

Send-StatusUpdate -Section "disk" -Status "HEALTHY" -Details "Deployment complete"

exit 0
