# ============================================================================
# Dell Command Update - Check & Install Updates
# ============================================================================
# Description: Checks for available Dell updates and optionally installs them
# Requires: Dell Command Update CLI installed
# Usage: Called by Dr Gates with command name in arguments
# ============================================================================

param(
    [string]$Mode = "check"  # "check" or "install"
)

# Auto-detect mode from Dr Gates command if not specified
if ($args.Count -gt 0) {
    if ($args[0] -match "install") {
        $Mode = "install"
    }
}

$InstallUpdates = ($Mode -eq "install")
$ErrorActionPreference = "Continue"

# Dell Command Update CLI path
$dcuCliPath = "C:\Program Files\Dell\CommandUpdate\dcu-cli.exe"
$dcuCliPathX86 = "C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe"

# Find DCU CLI
if (Test-Path $dcuCliPath) {
    $dcu = $dcuCliPath
} elseif (Test-Path $dcuCliPathX86) {
    $dcu = $dcuCliPathX86
} else {
    Write-Host "❌ ERROR: Dell Command Update is not installed!"
    Write-Host ""
    Write-Host "To install Dell Command Update:"
    Write-Host "1. Download from: https://www.dell.com/support/command-update"
    Write-Host "2. Install the application"
    Write-Host "3. Run this check again"
    exit 1
}

Write-Host "---------------------------------------------------------------"
Write-Host "  DELL COMMAND UPDATE - SYSTEM UPDATE CHECK"
Write-Host "---------------------------------------------------------------"
Write-Host ""

# Get Dell system information
Write-Host "🖥️  SYSTEM INFORMATION" -ForegroundColor Cyan
Write-Host "-------------------------------------------------------------"

try {
    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
    $bios = Get-CimInstance -ClassName Win32_BIOS
    
    Write-Host "Manufacturer: $($computerSystem.Manufacturer)"
    Write-Host "Model: $($computerSystem.Model)"
    Write-Host "BIOS Version: $($bios.SMBIOSBIOSVersion)"
    Write-Host "Service Tag: $($bios.SerialNumber)"
} catch {
    Write-Host "Could not retrieve system information"
}

Write-Host ""
Write-Host "🔍 CHECKING FOR UPDATES..." -ForegroundColor Yellow
Write-Host "-------------------------------------------------------------"

# Check for updates using DCU CLI
$checkStartTime = Get-Date

# Check for updates using DCU CLI
$checkStartTime = Get-Date

if ($InstallUpdates) {
    Write-Host "Mode: Install Updates (download and install)"
    Write-Host ""
    Write-Host "⚠️  This may take several minutes depending on update size..."
    Write-Host ""
    
    # Apply updates with real-time progress tracking
    Write-Host "📦 STARTING UPDATE INSTALLATION" -ForegroundColor Green
    Write-Host "---------------------------------------------------------------"
    Write-Host ""
    Write-Host "Phase 1: Downloading updates..." -ForegroundColor Cyan
    Write-Host "Phase 2: Installing updates..." -ForegroundColor Cyan
    Write-Host "Phase 3: Finalizing..." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Progress:" -ForegroundColor Yellow
    Write-Host "-------------------------------------------------------------"
    
    # Create a process to capture real-time output
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $dcu
    $psi.Arguments = "/applyUpdates -silent"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    
    # Event handlers for real-time output
    $outputBuilder = New-Object System.Text.StringBuilder
    $errorBuilder = New-Object System.Text.StringBuilder
    
    $outputHandler = {
        if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
            $line = $EventArgs.Data
            [void]$Event.MessageData.AppendLine($line)
            
            # Parse and display progress
            if ($line -match "Downloading|Download") {
                Write-Host "⬇️  $line" -ForegroundColor Cyan
            } elseif ($line -match "Installing|Install") {
                Write-Host "⚙️  $line" -ForegroundColor Yellow
            } elseif ($line -match "Completed|Complete|Success") {
                Write-Host "✅ $line" -ForegroundColor Green
            } elseif ($line -match "Failed|Error|Fail") {
                Write-Host "❌ $line" -ForegroundColor Red
            } elseif ($line -match "(\d+)%") {
                Write-Host "📊 Progress: $($matches[1])%" -ForegroundColor Cyan
            } elseif ($line.Trim().Length -gt 0) {
                Write-Host "   $line" -ForegroundColor Gray
            }
        }
    }
    
    $errorHandler = {
        if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
            [void]$Event.MessageData.AppendLine($EventArgs.Data)
            Write-Host "⚠️  $($EventArgs.Data)" -ForegroundColor Yellow
        }
    }
    
    $process.EnableRaisingEvents = $true
    Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action $outputHandler -MessageData $outputBuilder | Out-Null
    Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action $errorHandler -MessageData $errorBuilder | Out-Null
    
    # Start the process
    [void]$process.Start()
    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()
    
    # Wait for completion
    $process.WaitForExit()
    
    # Cleanup event handlers
    Get-EventSubscriber | Where-Object { $_.SourceObject -eq $process } | Unregister-Event
    
    # Capture full output
    $dcuOutput = $outputBuilder.ToString() + $errorBuilder.ToString()
    
} else {
    Write-Host "Mode: Check Only (scan for available updates)"
    Write-Host ""
    
    # Scan for updates and capture console output
    $dcuOutput = & $dcu /scan 2>&1 | Out-String
}

$checkDuration = ((Get-Date) - $checkStartTime).TotalSeconds

Write-Host ""
if ($InstallUpdates) {
    Write-Host "⏱️  Installation completed in $([math]::Round($checkDuration, 2)) seconds" -ForegroundColor Green
} else {
    Write-Host "⏱️  Scan completed in $([math]::Round($checkDuration, 2)) seconds"
}
Write-Host ""

# Parse the console output
if (-not $InstallUpdates) {
    # Look for update information in the output
    $lines = $dcuOutput -split "`n"
    
    # Check for update count line: "Number of applicable updates for the current system configuration: X"
    if ($dcuOutput -match "Number of applicable updates for the current system configuration:\s*(\d+)") {
        $updateCount = [int]$matches[1]
        
        if ($updateCount -eq 0) {
            Write-Host "✅ NO UPDATES AVAILABLE" -ForegroundColor Green
            Write-Host "Your Dell system is up to date!"
        } else {
            Write-Host "📦 AVAILABLE UPDATES: $updateCount" -ForegroundColor Green
            Write-Host "---------------------------------------------------------------"
            Write-Host ""
            
            # Parse individual updates
            # Format: CODE: Name - Category -- Severity -- Additional
            $updateNumber = 1
            foreach ($line in $lines) {
                # Match DCU update format: "JVGMF: Dell Precision... - BIOS -- Urgent -- BI"
                if ($line -match "^([A-Z0-9]+):\s*(.+?)\s*--\s*(.+?)\s*--\s*(.+)$") {
                    $updateCode = $matches[1].Trim()
                    $updateNameAndCategory = $matches[2].Trim()
                    $severity = $matches[3].Trim()
                    $additional = $matches[4].Trim()
                    
                    # Split name and category (format: "Name - Category")
                    if ($updateNameAndCategory -match "^(.+?)\s*-\s*([A-Z][A-Za-z]+)$") {
                        $updateName = $matches[1].Trim()
                        $category = $matches[2].Trim()
                    } else {
                        $updateName = $updateNameAndCategory
                        $category = "Unknown"
                    }
                    
                    Write-Host "[$updateNumber] $updateName" -ForegroundColor Cyan
                    Write-Host "    Code: $updateCode" -ForegroundColor Gray
                    Write-Host "    Category: $category"
                    Write-Host "    Severity: $severity" -ForegroundColor $(
                        if ($severity -match "Urgent|Critical") { "Red" }
                        elseif ($severity -match "Recommended|Important") { "Yellow" }
                        else { "White" }
                    )
                    Write-Host ""
                    $updateNumber++
                }
            }
            
            if ($updateNumber -eq 1) {
                # Didn't parse individual updates, show raw lines
                Write-Host "Updates found but couldn't parse details. Raw output:"
                Write-Host ""
                foreach ($line in $lines) {
                    if ($line -match "^[A-Z0-9]+:\s*") {
                        Write-Host "  • $($line.Trim())" -ForegroundColor Cyan
                    }
                }
                Write-Host ""
            }
            
            Write-Host "-------------------------------------------------------------"
            Write-Host "💡 To install these updates, use the 'Install Dell Updates' button"
        }
    } elseif ($dcuOutput -match "No applicable updates available" -or 
              $dcuOutput -match "0 updates available" -or
              $dcuOutput -match "System is up to date") {
        
        Write-Host "✅ NO UPDATES AVAILABLE" -ForegroundColor Green
        Write-Host "Your Dell system is up to date!"
        
    } else {
        # Couldn't parse output clearly
        Write-Host "⚠️  Scan completed, parsing results..." -ForegroundColor Yellow
        Write-Host ""
        
        # Show raw output for debugging
        if ($dcuOutput.Trim().Length -gt 0) {
            Write-Host "Dell Command Update Output:"
            Write-Host "-------------------------------------------------------------"
            Write-Host $dcuOutput
            Write-Host "-------------------------------------------------------------"
        } else {
            Write-Host "⚠️  No output received from Dell Command Update"
            Write-Host "The scan may have completed successfully, but couldn't retrieve results."
            Write-Host ""
            Write-Host "Try running Dell Command Update manually:"
            Write-Host "  1. Open Dell Command Update from Start Menu"
            Write-Host "  2. Click 'Check for Updates'"
        }
    }
}

# Show installation results if installing
if ($InstallUpdates) {
    Write-Host ""
    Write-Host "---------------------------------------------------------------"
    Write-Host "📦 INSTALLATION SUMMARY" -ForegroundColor Green
    Write-Host "---------------------------------------------------------------"
    Write-Host ""
    
    # Parse installation results
    $installed = 0
    $failed = 0
    $rebootRequired = $false
    
    $lines = $dcuOutput -split "`n"
    foreach ($line in $lines) {
        if ($line -match "successfully installed|installation completed|installed successfully") {
            $installed++
        }
        if ($line -match "failed|error|unsuccessful") {
            $failed++
        }
        if ($line -match "reboot|restart|restart required") {
            $rebootRequired = $true
        }
    }
    
    # Show summary
    if ($installed -gt 0) {
        Write-Host "✅ Successfully installed: $installed update(s)" -ForegroundColor Green
    }
    if ($failed -gt 0) {
        Write-Host "❌ Failed: $failed update(s)" -ForegroundColor Red
    }
    if ($installed -eq 0 -and $failed -eq 0) {
        Write-Host "✅ Installation process completed" -ForegroundColor Green
    }
    
    Write-Host ""
    
    # Reboot warning
    if ($rebootRequired) {
        Write-Host "🔄 RESTART REQUIRED" -ForegroundColor Yellow
        Write-Host "---------------------------------------------------------------"
        Write-Host ""
        Write-Host "⚠️  IMPORTANT: A system restart is required to complete installation!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Please:" -ForegroundColor Yellow
        Write-Host "  1. Save all your work"
        Write-Host "  2. Close all applications"
        Write-Host "  3. Restart your computer"
        Write-Host ""
    } else {
        Write-Host "ℹ️  Check if a restart is recommended:" -ForegroundColor Cyan
        Write-Host "  - Some updates may require a restart even if not explicitly stated"
        Write-Host "  - Dell Command Update GUI may show restart status"
        Write-Host ""
    }
    
    Write-Host "For detailed logs, check Dell Command Update application"
}

Write-Host ""
Write-Host "---------------------------------------------------------------"
Write-Host "  Dell Command Update Check Complete"
Write-Host "---------------------------------------------------------------"

# Send status update to Dr Gates
$statusMessage = if ($dcuOutput -match "Number of applicable updates for the current system configuration:\s*0" -or
                     $dcuOutput -match "No applicable updates|System is up to date") {
    "UP_TO_DATE"
} elseif ($dcuOutput -match "Number of applicable updates for the current system configuration:\s*(\d+)") {
    "UPDATES_AVAILABLE"
} elseif ($InstallUpdates) {
    "INSTALLED"
} else {
    "CHECKED"
}

$updateInfo = @{
    section = "dell"
    status = $statusMessage
    details = if ($statusMessage -eq "UP_TO_DATE") { "System up to date" } else { "See output for details" }
}

Write-Host "STATUS_UPDATE:$($updateInfo | ConvertTo-Json -Compress)"
