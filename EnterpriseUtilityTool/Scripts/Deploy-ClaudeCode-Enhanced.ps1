<#
.SYNOPSIS
    Enhanced Claude Code deployment with proper SYSTEM-to-user impersonation
.DESCRIPTION
    Uses scheduled tasks to run commands in user context when executed as SYSTEM.
    Designed for IT self-help tools that run as SYSTEM.
.NOTES
    - Automatically detects logged-in user
    - Creates temporary scheduled tasks for user-context operations
    - Comprehensive logging and error handling
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter()]
    [string]$TargetUsername,

    [Parameter()]
    [string]$LogPath = "$env:ProgramData\Capitec\Logs\ClaudeCodeSetup.log"
)

# ==========================
# LOGGING
# ==========================
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")

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

Write-Log "========================================" "INFO"
Write-Log "Claude Code Deployment Started" "INFO"
Write-Log "========================================" "INFO"

# ==========================
# GET LOGGED-IN USER
# ==========================
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
    exit 1
}

Write-Log "Target User: $TargetUsername" "SUCCESS"

# Get user SID and profile
$userSID = (New-Object System.Security.Principal.NTAccount($TargetUsername)).Translate([System.Security.Principal.SecurityIdentifier]).Value
$userProfile = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$userSID" -ErrorAction SilentlyContinue).ProfileImagePath

if (-not $userProfile -or -not (Test-Path $userProfile)) {
    Write-Log "User profile not found: $userProfile" "ERROR"
    exit 1
}

Write-Log "User Profile: $userProfile" "INFO"
Write-Log "User SID: $userSID" "INFO"

# ==========================
# STEP 1: INSTALL NODE.JS
# ==========================
Write-Log "=== STEP 1: Node.js Installation ===" "INFO"

$nodeInstalled = Get-Command node -ErrorAction SilentlyContinue

if ($nodeInstalled) {
    $nodeVersion = & node --version 2>$null
    Write-Log "Node.js already installed: $nodeVersion" "SUCCESS"
} else {
    Write-Log "Installing Node.js LTS..." "INFO"

    try {
        $wingetResult = winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements --silent 2>&1

        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
            Write-Log "Node.js installation completed" "SUCCESS"

            # Refresh PATH
            $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
            $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
            $env:Path = "$machinePath;$userPath"

            # Wait for Node.js to be available
            Start-Sleep -Seconds 5

            # Verify
            $nodeCheck = Get-Command node -ErrorAction SilentlyContinue
            if ($nodeCheck) {
                $nodeVersion = & node --version
                Write-Log "Verified Node.js: $nodeVersion" "SUCCESS"
            } else {
                Write-Log "Node.js not found in PATH after installation" "WARNING"
                Write-Log "Adding Node.js to current session PATH..." "INFO"

                # Common Node.js installation paths
                $possiblePaths = @(
                    "${env:ProgramFiles}\nodejs",
                    "${env:ProgramFiles(x86)}\nodejs",
                    "$env:LOCALAPPDATA\Programs\nodejs"
                )

                foreach ($path in $possiblePaths) {
                    if (Test-Path $path) {
                        $env:Path += ";$path"
                        Write-Log "Added to PATH: $path" "INFO"
                    }
                }

                $nodeCheck = Get-Command node -ErrorAction SilentlyContinue
                if (-not $nodeCheck) {
                    Write-Log "Node.js still not available. Manual intervention required." "ERROR"
                    exit 1
                }
            }
        } else {
            Write-Log "Node.js installation failed. Exit code: $LASTEXITCODE" "ERROR"
            exit 1
        }
    }
    catch {
        Write-Log "Exception during Node.js installation: $_" "ERROR"
        exit 1
    }
}

# ==========================
# STEP 2: USER-CONTEXT SETUP
# ==========================
Write-Log "=== STEP 2: User Context Setup ===" "INFO"

# Create user setup script
$userSetupScriptPath = "$env:ProgramData\Capitec\Temp\ClaudeSetup_$TargetUsername.ps1"
$userSetupDir = Split-Path $userSetupScriptPath -Parent

if (-not (Test-Path $userSetupDir)) {
    New-Item -Path $userSetupDir -ItemType Directory -Force | Out-Null
}

$userSetupScript = @"
# Claude Code User Setup Script
`$ErrorActionPreference = 'Continue'
`$logFile = '$LogPath'

function Write-UserLog {
    param([string]`$Message)
    `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path `$logFile -Value "[`$timestamp] [USER] `$Message" -ErrorAction SilentlyContinue
}

Write-UserLog "=== User Setup Started ==="
Write-UserLog "User: `$env:USERNAME"
Write-UserLog "Profile: `$env:USERPROFILE"

# Verify Node.js
`$nodePath = Get-Command node -ErrorAction SilentlyContinue
if (-not `$nodePath) {
    Write-UserLog "ERROR: Node.js not found in user PATH"
    exit 1
}

`$nodeVersion = & node --version
Write-UserLog "Node.js version: `$nodeVersion"

# Configure npm registry
Write-UserLog "Configuring npm registry..."
try {
    & npm config set "@capitec:registry" "https://artifacts.capitecbank.co.za/artifactory/api/npm/engineering-acceleration-npm-local/"
    Write-UserLog "npm registry configured successfully"
}
catch {
    Write-UserLog "ERROR: npm config failed - `$_"
    exit 1
}

# Run Claude Code setup
Write-UserLog "Running Claude Code setup..."
try {
    `$setupOutput = & npx --yes @capitec/roocode-kickstart@latest --claude-code-setup 2>&1
    Write-UserLog "Setup output: `$setupOutput"

    if (`$LASTEXITCODE -eq 0) {
        Write-UserLog "SUCCESS: Claude Code setup completed"
        exit 0
    } else {
        Write-UserLog "ERROR: Setup failed with exit code `$LASTEXITCODE"
        exit 1
    }
}
catch {
    Write-UserLog "ERROR: Exception during setup - `$_"
    exit 1
}
"@

Set-Content -Path $userSetupScriptPath -Value $userSetupScript -Force
Write-Log "Created user setup script: $userSetupScriptPath" "INFO"

# ==========================
# STEP 3: RUN AS USER VIA SCHEDULED TASK
# ==========================
Write-Log "=== STEP 3: Executing as User ===" "INFO"

$taskName = "ClaudeCodeSetup_$TargetUsername`_$(Get-Date -Format 'yyyyMMddHHmmss')"

try {
    # Create scheduled task to run as user
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$userSetupScriptPath`""
    $principal = New-ScheduledTaskPrincipal -UserId $TargetUsername -LogonType Interactive -RunLevel Limited

    Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Force | Out-Null
    Write-Log "Scheduled task created: $taskName" "INFO"

    # Run the task
    Start-ScheduledTask -TaskName $taskName
    Write-Log "Task started, waiting for completion..." "INFO"

    # Wait for task to complete (timeout 5 minutes)
    $timeout = 300
    $elapsed = 0
    $completed = $false

    while ($elapsed -lt $timeout) {
        Start-Sleep -Seconds 5
        $elapsed += 5

        $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
        if ($taskInfo.LastRunTime -gt (Get-Date).AddMinutes(-1) -and $taskInfo.LastTaskResult -ne 267009) {
            $completed = $true
            break
        }
    }

    if ($completed) {
        $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
        if ($taskInfo.LastTaskResult -eq 0) {
            Write-Log "User setup completed successfully" "SUCCESS"
        } else {
            Write-Log "User setup failed. Task result: $($taskInfo.LastTaskResult)" "ERROR"
        }
    } else {
        Write-Log "User setup timed out after $timeout seconds" "ERROR"
    }

    # Cleanup
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Log "Scheduled task removed" "INFO"
}
catch {
    Write-Log "Error running user setup: $_" "ERROR"
    exit 1
}

# ==========================
# STEP 4: VERIFY
# ==========================
Write-Log "=== STEP 4: Verification ===" "INFO"

$claudeCodeCli = Join-Path $userProfile "AppData\Roaming\npm\claude-code.cmd"
$claudeConfig = Join-Path $userProfile ".claude"

if (Test-Path $claudeCodeCli) {
    Write-Log "Claude Code CLI found: $claudeCodeCli" "SUCCESS"
} else {
    Write-Log "Claude Code CLI not found" "WARNING"
}

if (Test-Path $claudeConfig) {
    Write-Log "Claude config directory found: $claudeConfig" "SUCCESS"
} else {
    Write-Log "Claude config directory not found" "WARNING"
}

# ==========================
# CLEANUP
# ==========================
if (Test-Path $userSetupScriptPath) {
    Remove-Item $userSetupScriptPath -Force -ErrorAction SilentlyContinue
    Write-Log "Cleaned up temporary setup script" "INFO"
}

Write-Log "========================================" "SUCCESS"
Write-Log "Deployment Complete!" "SUCCESS"
Write-Log "========================================" "SUCCESS"
Write-Log ""
Write-Log "User next steps:"
Write-Log "1. Open a new PowerShell/Command Prompt"
Write-Log "2. Run: claude-code"
Write-Log "3. Follow authentication prompts"
Write-Log ""
Write-Log "Log file: $LogPath"

exit 0
