<# ClaudeCode_Detect.ps1 - quick compliance check (WindowPane-friendly) #>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log([string]$m){ Write-Output "[ClaudeDetect] $m" }
function Has([string]$n){ return [bool](Get-Command $n -ErrorAction SilentlyContinue) }

try {
  $issues = @()

  if (-not (Has "git"))   { $issues += "Missing Git (prereq)" }         # [2](https://capitecbank.atlassian.net/wiki/spaces/BIAM/pages/3482126194/.Net+Migration)
  if (-not (Has "node"))  { $issues += "Missing Node.js (prereq)" }     # [2](https://capitecbank.atlassian.net/wiki/spaces/BIAM/pages/3482126194/.Net+Migration)
  if (-not (Has "claude")){ $issues += "Claude Code not installed/on PATH" } # [2](https://capitecbank.atlassian.net/wiki/spaces/BIAM/pages/3482126194/.Net+Migration)

  if ($issues.Count -eq 0) {
    Write-Log "STATUS=OK"
    exit 0
  } else {
    Write-Log "STATUS=NEEDS_HEAL"
    $issues | ForEach-Object { Write-Log "ISSUE=$_"}
    exit 1
  }
} catch {
  Write-Log "STATUS=ERROR MSG=$($_.Exception.Message)"
  exit 1
}