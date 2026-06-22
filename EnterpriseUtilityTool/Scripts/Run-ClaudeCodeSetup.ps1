#Requires -Version 5.1
<#
.SYNOPSIS
    Automated Claude Code + AWS Bedrock installer for Capitec (Windows).
.DESCRIPTION
    Single-script setup covering all steps from the Capitec
    engineering-acceleration-entities documentation:
      1.  Preflight  (ISE guard, 64-bit check, admin warning)
      2.  ExecutionPolicy
      3.  Node.js LTS  (winget, validates LTS major)
      4.  npm registry  (global = npmjs.org, @capitec scoped to Artifactory)
      5.  CA certificate bundle  (Zscaler + Asgard from trust store)
      6.  Git for Windows  (winget fallback)
      7.  roocode-kickstart --claude-code-setup
      8.  Patch settings.json  (Git Bash path + NODE_EXTRA_CA_CERTS)
      9.  PowerShell profile  (token-update alias)
      10. Bedrock token  (opens browser for Azure AD login)
      11. VS Code extension  (if VS Code is detected)
      12. Health check
.NOTES
    Run in Windows PowerShell or pwsh as Administrator.
    Do NOT use PowerShell ISE.
    Close this elevated window after setup; run claude in a normal terminal.
.PARAMETER SkipTokenSetup
    Skip Bedrock token step (use when credentials are already valid).
.PARAMETER SkipVSCode
    Skip VS Code extension setup.
.PARAMETER SkipHealthCheck
    Skip final health check.
.PARAMETER Force
    Re-run all steps even if already configured.
#>
[CmdletBinding()]
param(
    [switch]$SkipTokenSetup,
    [switch]$SkipVSCode,
    [switch]$SkipHealthCheck,
    [switch]$Force,

    # Passed by Dr Gates to suppress interactive prompts and run fully unattended.
    [switch]$AutoContinue
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Execution policy self-bypass ───────────────────────────────────────────
# Applies Bypass to this process only so the script always runs, regardless
# of machine or user policy. Has no effect on any other session.
if ((Get-ExecutionPolicy -Scope Process) -notin @('Bypass','Unrestricted','RemoteSigned')) {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
}

# ── Helpers ───────────────────────────────────────────────────────────────────
$script:idx = 0

function Write-Header {
    param([string]$T)
    Write-Host ""
    Write-Host ("=" * 64) -ForegroundColor Cyan
    Write-Host "  $T" -ForegroundColor Cyan
    Write-Host ("=" * 64) -ForegroundColor Cyan
}
function Write-Step {
    param([string]$T)
    $script:idx++
    Write-Host "`n[$script:idx] $T" -ForegroundColor Yellow
}
function Write-OK   { param([string]$T); Write-Host "    [OK]  $T" -ForegroundColor Green    }
function Write-Skip { param([string]$T); Write-Host "    [--]  $T" -ForegroundColor DarkGray }
function Write-Info { param([string]$T); Write-Host "     >    $T" -ForegroundColor White    }
function Write-Warn { param([string]$T); Write-Host "    [!!]  $T" -ForegroundColor Yellow   }
function Write-Fail {
    param([string]$T)
    Write-Host "`n  [FAILED] $T`n" -ForegroundColor Red
}

function Refresh-Path {
    $m = [Environment]::GetEnvironmentVariable('Path','Machine')
    $u = [Environment]::GetEnvironmentVariable('Path','User')
    $env:Path = "$m;$u"
}
function Test-Cmd { param([string]$C); $null -ne (Get-Command $C -ErrorAction SilentlyContinue) }

# ── Banner ────────────────────────────────────────────────────────────────────
Write-Header "Claude Code + Bedrock  |  Capitec Automated Installer  |  Windows"

# ═════════════════════════════════════════════════════════════════════════════
#  STEP 1  Preflight
# ═════════════════════════════════════════════════════════════════════════════
Write-Step "Preflight checks"

if ($host.Name -eq 'Windows PowerShell ISE Host') {
    Write-Fail "PowerShell ISE is not supported. Open Windows PowerShell or pwsh as Administrator."
    exit 1
}
Write-OK "Not running in PowerShell ISE"

if (-not [Environment]::Is64BitOperatingSystem) {
    Write-Fail "Claude Code requires 64-bit Windows."
    exit 1
}
Write-OK "64-bit Windows"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
               [Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-OK "Running as Administrator"
} else {
    Write-Warn "Not running as Administrator. winget installs may fail."
    Write-Info "Re-run from an elevated PowerShell for a fully automated install."
}

# ═════════════════════════════════════════════════════════════════════════════
#  STEP 2  ExecutionPolicy
# ═════════════════════════════════════════════════════════════════════════════
Write-Step "ExecutionPolicy"
# Process-scope bypass is already active (applied at script start).
# Here we also set CurrentUser to RemoteSigned so future sessions work normally.
try {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    Write-OK "ExecutionPolicy = RemoteSigned (CurrentUser) — persisted for future sessions"
} catch {
    Write-OK "ExecutionPolicy = Bypass (Process scope, active) — Group Policy blocked CurrentUser change"
    Write-Info "This session will work fine. Future sessions may need: Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass"
}

# ═════════════════════════════════════════════════════════════════════════════
#  STEP 3  Node.js LTS
# ═════════════════════════════════════════════════════════════════════════════
Write-Step "Node.js LTS"
Refresh-Path

if ((Test-Cmd 'node') -and -not $Force) {
    $ver   = (node --version 2>&1).ToString().Trim()
    $major = [int]($ver -replace '^v(\d+)\..*','$1')
    if ($major % 2 -ne 0) {
        Write-Warn "Node.js $ver is not an LTS build (odd major). Claude Code may crash."
        Write-Info "Install LTS: winget install OpenJS.NodeJS.LTS"
    } else {
        Write-Skip "Node.js $ver already installed"
    }
} else {
    if (-not (Test-Cmd 'winget')) {
        Write-Fail "winget not found. Install Node.js LTS from https://nodejs.org then re-run."
        exit 1
    }
    Write-Info "Installing Node.js LTS via winget (BeyondTrust prompt: 'Claude Code setup')..."
    try {
        winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
        Refresh-Path
        if (-not (Test-Cmd 'node')) { throw "node not found after install" }
        Write-OK "Node.js installed: $(node --version)"
    } catch {
        Write-Fail "Node.js install failed: $_"
        Write-Info "Install manually from https://nodejs.org/en/download then re-run."
        exit 1
    }
}

# ═════════════════════════════════════════════════════════════════════════════
#  STEP 4  npm registry
# ═════════════════════════════════════════════════════════════════════════════
Write-Step "npm registry"

$globalReg = (npm config get registry 2>&1).ToString().Trim()
if ($globalReg -like '*capitecbank*') {
    npm config set registry https://registry.npmjs.org/
    Write-OK "Global registry reset to https://registry.npmjs.org/"
} else {
    Write-Skip "Global registry OK: $globalReg"
}

npm config set "@capitec:registry=https://artifacts.capitecbank.co.za/artifactory/api/npm/engineering-acceleration-npm-local/"
Write-OK "@capitec scope -> Capitec Artifactory"

$cfg = (npm config list 2>&1) -join "`n"
if ($cfg -match 'capitecbank.*_authToken') {
    npm config delete "//artifacts.capitecbank.co.za/artifactory/api/npm/engineering-acceleration-npm-local/:_authToken" 2>$null
    Write-OK "Stale Artifactory _authToken removed"
}

# ═════════════════════════════════════════════════════════════════════════════
#  STEP 5  CA certificate bundle
# ═════════════════════════════════════════════════════════════════════════════
Write-Step "CA certificate bundle (Zscaler + Asgard)"

$certDir  = Join-Path $env:USERPROFILE '.claude\certs'
$certFile = Join-Path $certDir 'node-extra-ca-certs.pem'

if ((Test-Path $certFile) -and -not $Force) {
    Write-Skip "Bundle already present: $certFile"
} else {
    New-Item -ItemType Directory -Force -Path $certDir | Out-Null
    $bundle = ""
    $count  = 0
    foreach ($cn in @("Zscaler Root CA","asgard.capi RootCA-euw1")) {
        foreach ($store in @('LocalMachine','CurrentUser')) {
            $hits = Get-ChildItem "Cert:\$store\Root" -EA SilentlyContinue |
                    Where-Object { $_.Subject -like "*$cn*" }
            foreach ($c in $hits) {
                $pem    = [Convert]::ToBase64String($c.RawData,'InsertLineBreaks')
                $bundle += "# $($c.Subject)`n-----BEGIN CERTIFICATE-----`n$pem`n-----END CERTIFICATE-----`n`n"
                $count++
                Write-Info "Extracted: $($c.Subject)"
            }
        }
    }
    if ($count -gt 0) {
        Set-Content -Path $certFile -Value $bundle
        Write-OK "Bundle written ($count cert(s)): $certFile"
    } else {
        Write-Warn "No matching certs in trust store — kickstart will attempt its own deployment."
    }
    [Environment]::SetEnvironmentVariable('NODE_EXTRA_CA_CERTS', $certFile, 'User')
    $env:NODE_EXTRA_CA_CERTS = $certFile
    Write-OK "NODE_EXTRA_CA_CERTS set (User env var)"
}

# ═════════════════════════════════════════════════════════════════════════════
#  STEP 6  Git for Windows
# ═════════════════════════════════════════════════════════════════════════════
Write-Step "Git for Windows"
Refresh-Path

$gitBash = "C:\Program Files\Git\bin\bash.exe"

if (Test-Path $gitBash) {
    Write-Skip "Git Bash already present: $gitBash"
} elseif (Test-Cmd 'git') {
    $alt = Join-Path (Split-Path (Split-Path (Get-Command git).Source)) 'bin\bash.exe'
    if (Test-Path $alt) { $gitBash = $alt; Write-Skip "Git Bash found: $alt" }
    else { Write-Warn "git.exe found but bash.exe not located at expected path." }
} else {
    if (Test-Cmd 'winget') {
        try {
            winget install --id Git.Git --silent --accept-source-agreements --accept-package-agreements
            Refresh-Path
            if (Test-Path $gitBash) { Write-OK "Git for Windows installed: $gitBash" }
            else { Write-Warn "winget finished but bash.exe not at default path — Claude Code shell ops may fail." }
        } catch { Write-Warn "Git install failed: $_. Download from https://git-scm.com/download/win" }
    } else {
        Write-Warn "winget not available. Install Git for Windows from https://git-scm.com/download/win"
    }
}

# ═════════════════════════════════════════════════════════════════════════════
#  STEP 7  roocode-kickstart --claude-code-setup
# ═════════════════════════════════════════════════════════════════════════════
Write-Step "roocode-kickstart: Claude Code setup"
Write-Info "Installs Claude Code, writes settings.json, validates certificates."
Write-Info "BeyondTrust prompt may appear — reason: 'Claude Code setup'."

$sslDisabled = $false
if (-not (Test-Path $certFile)) {
    Write-Warn "Cert bundle missing. Temporarily disabling strict-ssl."
    npm config set strict-ssl false
    $sslDisabled = $true
}
try {
    npx --yes @capitec/roocode-kickstart@latest --claude-code-setup --skip-health-check
    Write-OK "roocode-kickstart setup complete"
} catch {
    Write-Warn "roocode-kickstart error: $_"
    Write-Info "Retry: npx --yes @capitec/roocode-kickstart@latest --claude-code-setup"
} finally {
    if ($sslDisabled) { npm config set strict-ssl true; Write-OK "strict-ssl re-enabled" }
}
Refresh-Path

# ═════════════════════════════════════════════════════════════════════════════
#  STEP 8  Patch settings.json
# ═════════════════════════════════════════════════════════════════════════════
Write-Step "Patch settings.json (Git Bash path + NODE_EXTRA_CA_CERTS)"

$settingsFile = Join-Path $env:USERPROFILE '.claude\settings.json'
if (Test-Path $settingsFile) {
    try {
        $s     = Get-Content $settingsFile -Raw | ConvertFrom-Json
        $dirty = $false
        if (-not $s.PSObject.Properties['env']) {
            $s | Add-Member -NotePropertyName 'env' -NotePropertyValue ([PSCustomObject]@{})
        }
        if (-not $s.env.PSObject.Properties['CLAUDE_CODE_GIT_BASH_PATH']) {
            $s.env | Add-Member -NotePropertyName 'CLAUDE_CODE_GIT_BASH_PATH' `
                                 -NotePropertyValue ($gitBash.Replace('\','\\'))
            Write-OK "Added CLAUDE_CODE_GIT_BASH_PATH: $gitBash"
            $dirty = $true
        } else { Write-Skip "CLAUDE_CODE_GIT_BASH_PATH already set" }
        if (-not $s.env.PSObject.Properties['NODE_EXTRA_CA_CERTS']) {
            $s.env | Add-Member -NotePropertyName 'NODE_EXTRA_CA_CERTS' -NotePropertyValue $certFile
            Write-OK "Added NODE_EXTRA_CA_CERTS to settings.json"
            $dirty = $true
        } else { Write-Skip "NODE_EXTRA_CA_CERTS already in settings.json" }
        if ($dirty) { $s | ConvertTo-Json -Depth 10 | Set-Content $settingsFile }
    } catch {
        Write-Warn "Could not patch settings.json: $_"
        Write-Info "Manually add to `"env`" block in: $settingsFile"
        Write-Info '  "CLAUDE_CODE_GIT_BASH_PATH": "C:\\Program Files\\Git\\bin\\bash.exe"'
    }
} else {
    Write-Warn "settings.json not found — run roocode-kickstart first, then re-run this script."
}

# ═════════════════════════════════════════════════════════════════════════════
#  STEP 9  PowerShell profile
# ═════════════════════════════════════════════════════════════════════════════
Write-Step "PowerShell profile (token-update alias)"

$prof = $PROFILE.CurrentUserAllHosts
$profDir = Split-Path $prof
if (-not (Test-Path $profDir))  { New-Item -ItemType Directory -Force -Path $profDir | Out-Null }
if (-not (Test-Path $prof))     { New-Item -ItemType File      -Force -Path $prof    | Out-Null }

$existing = Get-Content $prof -Raw -EA SilentlyContinue
$marker   = '# [claude-code-setup]'

$block = @"

# [claude-code-setup] Bedrock EU Configuration
# Managed by Install-ClaudeCode.ps1. Add customisations outside these markers.
`$env:NODE_EXTRA_CA_CERTS = "`$env:USERPROFILE\.claude\certs\node-extra-ca-certs.pem"
function token-update { npx @capitec/roocode-kickstart@latest --token-setup }
# [/claude-code-setup]
"@

if ($existing -and ($existing -match [regex]::Escape($marker))) {
    Write-Skip "claude-code-setup block already in profile"
} else {
    Add-Content -Path $prof -Value $block
    Write-OK "Profile updated: $prof"
}

# ═════════════════════════════════════════════════════════════════════════════
#  STEP 10  Bedrock token
# ═════════════════════════════════════════════════════════════════════════════
if (-not $SkipTokenSetup -and -not $AutoContinue) {
    Write-Step "Bedrock token (Azure AD login)"
    Write-Info "A browser window will open. Click 'Login with Azure AD'."
    Write-Info "The terminal shows 'Waiting for token...' — switch to the browser."
    Write-Host ""
    try {
        npx @capitec/roocode-kickstart@latest --token-setup
        Write-OK "Bedrock credentials saved (~/.aws/credentials [bedrock])"
    } catch {
        Write-Warn "Token setup failed or timed out: $_"
        Write-Info "Retry in a normal terminal: token-update"
    }
} else {
    Write-Skip "Token setup skipped (-SkipTokenSetup)"
}

# ═════════════════════════════════════════════════════════════════════════════
#  STEP 11  VS Code extension
# ═════════════════════════════════════════════════════════════════════════════
if (-not $SkipVSCode) {
    Write-Step "VS Code extension"
    if (Test-Cmd 'code') {
        try {
            npx @capitec/roocode-kickstart@latest --setup-vscode
            Write-OK "VS Code extension configured"
            Write-Info "Reload: Ctrl+Shift+P -> Developer: Reload Window"
        } catch {
            Write-Warn "VS Code setup failed: $_"
            Write-Info "Retry: npx @capitec/roocode-kickstart@latest --setup-vscode"
        }
    } else {
        Write-Skip "VS Code not found on PATH"
    }
} else {
    Write-Skip "VS Code setup skipped (-SkipVSCode)"
}

# ═════════════════════════════════════════════════════════════════════════════
#  STEP 12  Health check
# ═════════════════════════════════════════════════════════════════════════════
if (-not $SkipHealthCheck -and -not $AutoContinue) {
    Write-Step "Health check"
    Refresh-Path
    if (Test-Cmd 'claude') {
        Write-Info "Running: claude -p 'Say hello in one sentence'"
        Write-Host ""
        try {
            $r = claude -p "Say hello in one sentence" 2>&1
            Write-Host "    $r" -ForegroundColor Cyan
            Write-Host ""
            Write-OK "Claude Code is responding via Bedrock"
        } catch {
            Write-Warn "Health check failed: $_"
            Write-Info "Check credentials (token-update) and confirm SA network connection."
            Write-Info "Offshore connections return 403 regardless of credentials."
        }
    } else {
        Write-Warn "'claude' not found in this session."
        Write-Info "Close this window, open a new terminal, then: claude --version"
    }
} else {
    Write-Skip "Health check skipped (-SkipHealthCheck)"
}

# ═════════════════════════════════════════════════════════════════════════════
#  Done
# ═════════════════════════════════════════════════════════════════════════════
Write-Header "Setup Complete"
Write-Host ""
Write-Host "  !! CLOSE this Administrator window now. !!" -ForegroundColor Red
Write-Host "  Running 'claude' as Administrator triggers UAC for every subprocess." -ForegroundColor Red
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "    1. Open a normal (non-elevated) PowerShell or terminal" -ForegroundColor White
Write-Host "    2. Navigate to your project:   cd C:\path\to\project" -ForegroundColor White
Write-Host "    3. Launch Claude Code:          claude" -ForegroundColor White
Write-Host ""
Write-Host "  Refresh Bedrock token (every 7 days):  token-update"     -ForegroundColor DarkGray
Write-Host "  Support Slack:                          #ai-engineering"  -ForegroundColor DarkGray
Write-Host "  Usage dashboard:                        ODIN -> Bedrock Usage" -ForegroundColor DarkGray
Write-Host ""
