<#
.SYNOPSIS
    Claude Code User-Level Setup (No Admin Required)
.DESCRIPTION
    Installs Claude Code for the current user when Node.js is already installed.
    Does NOT require administrator privileges.
    Perfect for standard users when IT has pre-installed Node.js.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$LogPath = "$env:USERPROFILE\AppData\Local\DrGates\Logs\ClaudeCodeSetup.log"
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

# ==========================
# BANNER
# ==========================
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " Dr Gates - Claude Code User Setup" -ForegroundColor Yellow
Write-Host " No Administrator Privileges Required" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Log "════════════════════════════════════════════════════════" "INFO"
Write-Log "Dr Gates - Claude Code User-Level Setup" "INFO"
Write-Log "User: $env:USERNAME" "INFO"
Write-Log "Profile: $env:USERPROFILE" "INFO"
Write-Log "════════════════════════════════════════════════════════" "INFO"

# ==========================
# STEP 1: CHECK NODE.JS
# ==========================
Write-Host "STEP 1: Verifying Node.js Installation" -ForegroundColor Yellow
Write-Host "�@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@" -ForegroundColor Gray
Write-Host ""

$nodeCommand = Get-Command node -ErrorAction SilentlyContinue

if (-not $nodeCommand) {
    Write-Log "ERROR: Node.js not found in PATH" "ERROR"
    Write-Host ""
    Write-Host "� Node.js is not installed or not in PATH" -ForegroundColor Red
    Write-Host ""
    Write-Host "Node.js must be installed before Claude Code can be set up." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Solutions:" -ForegroundColor Cyan
    Write-Host "  1. Request Node.js installation via IT Support" -ForegroundColor White
    Write-Host "  2. Open an ITSM ticket for software installation" -ForegroundColor White
    Write-Host ""
    Write-Host "Press Enter to open ITSM support portal..." -ForegroundColor Gray
    Read-Host
    
    # Open ITSM portal for software request
    $itsm_url = "https://itsm-capitecbank.ivanticloud.com/?Scope=SelfService&CommandId=NewServiceRequestByOfferingId&Tab=ServiceCatalog&Template=B488BA74A8894281AC5F330AA2DBA3C3"
    Start-Process $itsm_url
    
    Write-Host "ITSM portal opened. Please submit a request for Node.js installation." -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

$nodeVersion = & node --version 2>$null
$npmVersion = & npm --version 2>$null

Write-Log "Node.js version: $nodeVersion" "SUCCESS"
Write-Log "npm version: $npmVersion" "SUCCESS"

Write-Host " Node.js found: $nodeVersion" -ForegroundColor Green
Write-Host " npm found: $npmVersion" -ForegroundColor Green
Write-Host ""

Start-Sleep -Seconds 2

# ==========================
# STEP 2: CONFIGURE NPM
# ==========================
Write-Host "STEP 2: Configuring npm Registry" -ForegroundColor Yellow
Write-Host "@@@@@@@@@@@@@@@@@@@@@@@@@@@@�" -ForegroundColor Gray
Write-Host ""

Write-Log "Configuring Capitec npm registry (user-level)" "INFO"

try {
    # Configure registry at user level (no admin required)
    $registryUrl = "https://artifacts.capitecbank.co.za/artifactory/api/npm/engineering-acceleration-npm-local/"
    
    Write-Host "Setting @capitec registry..." -ForegroundColor Cyan
    & npm config set "@capitec:registry" $registryUrl --location user 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log "npm registry configured successfully" "SUCCESS"
        Write-Host " npm registry configured" -ForegroundColor Green
    } else {
        throw "npm config command failed"
    }
}
catch {
    Write-Log "ERROR: Failed to configure npm registry - $_" "ERROR"
    Write-Host "� npm configuration failed" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    exit 1
}

Write-Host ""
Start-Sleep -Seconds 2

# ==========================
# STEP 3: INSTALL CLAUDE CODE
# ==========================
Write-Host "STEP 3: Installing Claude Code" -ForegroundColor Yellow
Write-Host "@@@@@@@@@@@@@@@@@@@@@@@@@@" -ForegroundColor Gray
Write-Host ""

Write-Log "Starting Claude Code installation..." "INFO"
Write-Host "This may take a few minutes while packages are downloaded..." -ForegroundColor Cyan
Write-Host ""

try {
    # Run the Claude Code setup
    Write-Host "Executing: npx --yes @capitec/roocode-kickstart@latest --claude-code-setup" -ForegroundColor Gray
    Write-Host ""
    
    $setupOutput = & npx --yes @capitec/roocode-kickstart@latest --claude-code-setup 2>&1
    
    # Log the output
    Write-Log "Setup output: $setupOutput" "INFO"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Claude Code setup completed successfully" "SUCCESS"
        Write-Host ""
        Write-Host " Claude Code installed successfully!" -ForegroundColor Green
    } else {
        Write-Log "Claude Code setup failed with exit code $LASTEXITCODE" "ERROR"
        Write-Host ""
        Write-Host "� Claude Code installation failed (Exit code: $LASTEXITCODE)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Setup output:" -ForegroundColor Yellow
        Write-Host $setupOutput -ForegroundColor Gray
        exit 1
    }
}
catch {
    Write-Log "ERROR: Exception during Claude Code setup - $_" "ERROR"
    Write-Host ""
    Write-Host "� Installation error occurred" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    exit 1
}

Write-Host ""
Start-Sleep -Seconds 2

# ==========================
# STEP 4: VERIFICATION
# ==========================
Write-Host "STEP 4: Verifying Installation" -ForegroundColor Yellow
Write-Host "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@" -ForegroundColor Gray
Write-Host ""

$claudeCodeCli = Join-Path $env:USERPROFILE "AppData\Roaming\npm\claude-code.cmd"
$claudeConfig = Join-Path $env:USERPROFILE ".claude"

if (Test-Path $claudeCodeCli) {
    Write-Log "Claude Code CLI found: $claudeCodeCli" "SUCCESS"
    Write-Host " Claude Code CLI installed" -ForegroundColor Green
} else {
    Write-Log "WARNING: Claude Code CLI not found at expected location" "WARNING"
    Write-Host "� Claude Code CLI not found (may require PATH refresh)" -ForegroundColor Yellow
}

if (Test-Path $claudeConfig) {
    Write-Log "Claude config directory found: $claudeConfig" "SUCCESS"
    Write-Host " Claude configuration directory created" -ForegroundColor Green
} else {
    Write-Log "INFO: Claude config directory not yet created (normal)" "INFO"
    Write-Host "Configuration directory will be created on first use" -ForegroundColor Cyan
}

# ==========================
# COMPLETION
# ==========================
Write-Host ""
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host " Installation Complete!" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Open a NEW PowerShell or Command Prompt window" -ForegroundColor White
Write-Host "  2. Run: claude-code" -ForegroundColor White
Write-Host "  3. Follow the authentication prompts" -ForegroundColor White
Write-Host ""
Write-Host "Note: You may need to close and reopen your terminal" -ForegroundColor Yellow
Write-Host "      for the PATH changes to take effect." -ForegroundColor Yellow
Write-Host ""
Write-Host "Log file saved to:" -ForegroundColor Cyan
Write-Host "  $LogPath" -ForegroundColor Gray
Write-Host ""
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Green

Write-Log "════════════════════════════════════════════════════════" "SUCCESS"
Write-Log "Installation Complete!" "SUCCESS"
Write-Log "Log file: $LogPath" "SUCCESS"
Write-Log "════════════════════════════════════════════════════════" "SUCCESS"

Write-Host ""
Write-Host "Press Enter to close..." -ForegroundColor Gray
Read-Host

exit 0
