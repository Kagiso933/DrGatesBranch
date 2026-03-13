# Get-BatteryStatus.ps1
# Comprehensive battery health and usage diagnostics

Write-Host "=== BATTERY STATUS REPORT ===" -ForegroundColor Cyan
Write-Host ""

try {
    # Check if system has a battery
    $Battery = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
    
    if (-not $Battery) {
        Write-Host "No battery detected - This appears to be a desktop system" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "This diagnostic is designed for laptops and portable devices." -ForegroundColor Gray
        exit 0
    }

    # Battery Information
    Write-Host "[Battery Information]" -ForegroundColor Yellow
    Write-Host "  Manufacturer: $($Battery.Name)"
    Write-Host "  Chemistry: $($Battery.Chemistry)"
    
    # Battery Status
    $BatteryStatus = switch ($Battery.BatteryStatus) {
        1 { "Discharging" }
        2 { "On AC Power" }
        3 { "Fully Charged" }
        4 { "Low" }
        5 { "Critical" }
        6 { "Charging" }
        7 { "Charging and High" }
        8 { "Charging and Low" }
        9 { "Charging and Critical" }
        10 { "Undefined" }
        11 { "Partially Charged" }
        default { "Unknown" }
    }
    
    Write-Host "  Status: $BatteryStatus" -ForegroundColor $(
        if ($BatteryStatus -match "Critical|Low") { "Red" }
        elseif ($BatteryStatus -match "Charging") { "Green" }
        else { "White" }
    )
    
    Write-Host ""
    
    # Charge Level
    Write-Host "[Current Charge]" -ForegroundColor Yellow
    $ChargeLevel = $Battery.EstimatedChargeRemaining
    Write-Host "  Battery Level: $ChargeLevel%" -ForegroundColor $(
        if ($ChargeLevel -lt 20) { "Red" }
        elseif ($ChargeLevel -lt 50) { "Yellow" }
        else { "Green" }
    )
    
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    # Visual battery indicator
    $MaxBars = 20
    $PercentPerBar = 100 / $MaxBars
    $FilledCount = [math]::Floor($ChargeLevel / $PercentPerBar)
    $EmptyCount = $MaxBars - $FilledCount
    
    # Use characters that are more "terminal-friendly"
    $FullChar = "█"  # Solid block
    $EmptyChar = "░" # Light shade
    
    $Color = if ($ChargeLevel -lt 20) { "Red" } elseif ($ChargeLevel -lt 50) { "Yellow" } else { "Green" }

    Write-Host "  Indicator: [" -NoNewline
    Write-Host ($FullChar * $FilledCount) -ForegroundColor $Color -NoNewline
    Write-Host ($EmptyChar * $EmptyCount) -ForegroundColor Gray -NoNewline
    Write-Host "] $ChargeLevel%"
    
    # Time Remaining
    Write-Host "[Time Estimates]" -ForegroundColor Yellow
    $TimeRemaining = $Battery.EstimatedRunTime
    
    if ($TimeRemaining -and $TimeRemaining -ne 71582788) {  # Magic number = "calculating"
        $Hours = [math]::Floor($TimeRemaining / 60)
        $Minutes = $TimeRemaining % 60
        
        if ($BatteryStatus -match "Charging") {
            Write-Host "  Time to Full Charge: $Hours hours $Minutes minutes"
        }
        else {
            Write-Host "  Time Remaining: $Hours hours $Minutes minutes" -ForegroundColor $(
                if ($TimeRemaining -lt 30) { "Red" }
                elseif ($TimeRemaining -lt 60) { "Yellow" }
                else { "Green" }
            )
        }
    }
    else {
        Write-Host "  Time Remaining: Calculating..."
    }
    
    Write-Host ""
    
    # Power Status
    Write-Host "[Power Status]" -ForegroundColor Yellow
    $PowerStatus = Get-WmiObject -Class Win32_PowerManagementEvent -ErrorAction SilentlyContinue
    
    if ($Battery.BatteryStatus -eq 2 -or $Battery.BatteryStatus -in 6..9) {
        Write-Host "  AC Power:  Connected" -ForegroundColor Green
    }
    else {
        Write-Host "  AC Power:  Running on Battery" -ForegroundColor Yellow
    }
    
    Write-Host ""
    
    # Battery Health (Design vs Full Charge Capacity)
    Write-Host "[Battery Health]" -ForegroundColor Yellow
    
    try {
        # Generate battery report
        $ReportPath = "$env:TEMP\battery-report.html"
        powercfg /batteryreport /output $ReportPath /duration 1 | Out-Null
        
        # Parse the battery report for health info
        if (Test-Path $ReportPath) {
            $ReportContent = Get-Content $ReportPath -Raw
            
            # Extract design capacity and full charge capacity
            if ($ReportContent -match 'DESIGN CAPACITY[\s\S]*?(\d+,?\d*)\s*mWh') {
                $DesignCapacity = $matches[1] -replace ',', ''
            }
            if ($ReportContent -match 'FULL CHARGE CAPACITY[\s\S]*?(\d+,?\d*)\s*mWh') {
                $FullChargeCapacity = $matches[1] -replace ',', ''
            }
            
            if ($DesignCapacity -and $FullChargeCapacity) {
                $HealthPercent = [math]::Round(($FullChargeCapacity / $DesignCapacity) * 100, 1)
                
                Write-Host "  Design Capacity: $DesignCapacity mWh"
                Write-Host "  Current Capacity: $FullChargeCapacity mWh"
                Write-Host "  Battery Health: $HealthPercent%" -ForegroundColor $(
                    if ($HealthPercent -gt 80) { "Green" }
                    elseif ($HealthPercent -gt 60) { "Yellow" }
                    else { "Red" }
                )
                
                if ($HealthPercent -lt 80) {
                    Write-Host "   Battery capacity has degraded" -ForegroundColor Yellow
                }
                if ($HealthPercent -lt 60) {
                    Write-Host "   Consider replacing battery soon" -ForegroundColor Red
                }
            }
            
            Write-Host "  Full Report: $ReportPath" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  Unable to generate detailed health report"
    }
    
    Write-Host ""
    
    # Power Plan
    Write-Host "[Power Plan]" -ForegroundColor Yellow
    try {
        $ActivePlan = powercfg /getactivescheme
        if ($ActivePlan -match '\(([^)]+)\)') {
            Write-Host "  Active Plan: $($matches[1])"
        }
    }
    catch {
        Write-Host "  Unable to detect active power plan"
    }
    
    Write-Host ""
    
    # Recommendations
    Write-Host "[Recommendations]" -ForegroundColor Cyan
    
    $Recommendations = @()
    
    if ($ChargeLevel -lt 20 -and $Battery.BatteryStatus -ne 2) {
        $Recommendations += "Connect to AC power soon - battery is low"
    }
    
    if ($ChargeLevel -lt 10) {
        $Recommendations += "Save your work immediately - battery is critical"
    }
    
    if ($HealthPercent -and $HealthPercent -lt 70) {
        $Recommendations += "Battery health is degraded - consider replacement"
    }
    
    if ($BatteryStatus -eq "Fully Charged" -and $Battery.BatteryStatus -eq 2) {
        $Recommendations += "Battery is fully charged - you can disconnect AC power"
    }
    
    if ($Recommendations.Count -eq 0) {
        Write-Host "  Battery status is good - no actions needed" -ForegroundColor Green
    }
    else {
        foreach ($Rec in $Recommendations) {
            Write-Host "  â†’ $Rec" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "Report generated at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
}
catch {
    Write-Host " Error checking battery status: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "This may occur if:" -ForegroundColor Yellow
    Write-Host "  - System does not have a battery" -ForegroundColor Yellow
    Write-Host "  - Battery drivers are not installed" -ForegroundColor Yellow
    Write-Host "  - WMI service is not running" -ForegroundColor Yellow
}
