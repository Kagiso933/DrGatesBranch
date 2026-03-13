# Robust-Install.ps1
$InstallDir   = "C:\Program Files\WindowPaneUtility"
$SourceDir    = $PSScriptRoot
$ExeName      = "WindowPaneUtility.exe"
$ShortcutName = "WindowPane Utility"
$TargetExePath = Join-Path $InstallDir $ExeName

function Write-Log { param([string]$Message) Write-Host "[$Message]" }

try {
    Write-Log "Installing $ExeName..."

    # Create install dir and copy files
    New-Item -Path $InstallDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
    Copy-Item -Path "$SourceDir\*" -Destination $InstallDir -Recurse -Force -ErrorAction Stop
    Write-Log "Files copied."

    if (-not (Test-Path $TargetExePath)) {
        Write-Log "ERROR: Exe not found after copy."
        Exit 1
    }

    # Shortcuts
    $WshShell = New-Object -ComObject WScript.Shell

    $StartMenuPath = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\$ShortcutName"
    New-Item -Path $StartMenuPath -ItemType Directory -Force | Out-Null
    $s = $WshShell.CreateShortcut((Join-Path $StartMenuPath "$ShortcutName.lnk"))
    $s.TargetPath = $TargetExePath; $s.IconLocation = "$TargetExePath,0"; $s.Save()

    $s = $WshShell.CreateShortcut((Join-Path $env:PUBLIC "Desktop\$ShortcutName.lnk"))
    $s.TargetPath = $TargetExePath; $s.IconLocation = "$TargetExePath,0"; $s.Save()

    # Registry detection key
    $regPath = "HKLM:\SOFTWARE\WindowPaneUtility"
    New-Item -Path $regPath -Force | Out-Null
    Set-ItemProperty -Path $regPath -Name "InstalledVersion" -Value "1.0.0.0" -Type String -Force

    Write-Log "Installation complete."
    Exit 0
}
catch {
    Write-Host "FATAL: $($_.Exception.Message)"
    Exit 1
}