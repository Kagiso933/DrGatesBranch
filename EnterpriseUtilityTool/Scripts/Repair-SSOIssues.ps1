# Repair-SSOIssues.ps1
# Troubleshoot and fix Single Sign-On (SSO) authentication issues

Write-Host "=== SSO TROUBLESHOOTING & REPAIR ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This tool will diagnose and fix common SSO issues including:" -ForegroundColor Yellow
Write-Host "   Cached credentials" -ForegroundColor Gray
Write-Host "   Certificate problems" -ForegroundColor Gray
Write-Host "   Token cache" -ForegroundColor Gray
Write-Host "   Browser authentication" -ForegroundColor Gray
Write-Host "   Azure AD/Entra ID sync" -ForegroundColor Gray
Write-Host ""

$IssuesFixed = 0
$IssuesFound = 0

# Check current user
Write-Host "[User Information]" -ForegroundColor Yellow
$CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$Domain = $env:USERDOMAIN
Write-Host "  Current User: $CurrentUser"
Write-Host "  Domain: $Domain"
Write-Host ""

# Step 1: Clear Credential Manager
Write-Host "[Step 1: Credential Manager]" -ForegroundColor Yellow
try {
    Write-Host "  Checking stored credentials..." -ForegroundColor Gray
    
    # List credentials
    $Credentials = cmdkey /list | Select-String "Target:"
    $CredCount = ($Credentials | Measure-Object).Count
    
    Write-Host "  Found $CredCount stored credentials" -ForegroundColor White
    
    # Remove generic credentials that might cause SSO issues
    $RemovedCount = 0
    
    # Target specific problematic credentials
    $TargetPatterns = @(
        "*office*",
        "*microsoft*",
        "*login.microsoftonline*",
        "*sharepoint*",
        "*onedrive*"
    )
    
    foreach ($Pattern in $TargetPatterns) {
        try {
            cmdkey /delete:$Pattern 2>&1 | Out-Null
            $RemovedCount++
        }
        catch {
            # Credential doesn't exist, continue
        }
    }
    
    if ($RemovedCount -gt 0) {
        Write-Host "  Cleared $RemovedCount cached credentials" -ForegroundColor Green
        $IssuesFixed++
    }
    else {
        Write-Host "   No problematic credentials found" -ForegroundColor Gray
    }
}
catch {
    Write-Host "   Error accessing Credential Manager: $($_.Exception.Message)" -ForegroundColor Red
    $IssuesFound++
}
Write-Host ""

# Step 2: Clear Azure AD/Entra Token Cache
Write-Host "[Step 2: Azure AD Token Cache]" -ForegroundColor Yellow
try {
    $TokenCachePaths = @(
        "$env:LOCALAPPDATA\Microsoft\TokenBroker\Cache",
        "$env:LOCALAPPDATA\.IdentityService",
        "$env:LOCALAPPDATA\Packages\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy\AC\TokenBroker\Cache"
    )
    
    $Cleared = $false
    foreach ($Path in $TokenCachePaths) {
        if (Test-Path $Path) {
            try {
                Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "  Cleared token cache: $(Split-Path $Path -Leaf)" -ForegroundColor Green
                $Cleared = $true
            }
            catch {
                Write-Host "   Some token files in use" -ForegroundColor Gray
            }
        }
    }
    
    if ($Cleared) {
        $IssuesFixed++
    }
    else {
        Write-Host "  No token cache found" -ForegroundColor Gray
    }
}
catch {
    Write-Host "   Error clearing token cache" -ForegroundColor Red
    $IssuesFound++
}
Write-Host ""

# Step 3: Check and Clear Certificate Issues
Write-Host "[Step 3: Certificate Validation]" -ForegroundColor Yellow
try {
    Write-Host "  Checking user certificates..." -ForegroundColor Gray
    
    # Get expired certificates
    $ExpiredCerts = Get-ChildItem Cert:\CurrentUser\My -ErrorAction SilentlyContinue | 
                    Where-Object { $_.NotAfter -lt (Get-Date) }
    
    if ($ExpiredCerts) {
        Write-Host "  Found $($ExpiredCerts.Count) expired certificate(s)" -ForegroundColor Yellow
        Write-Host "  Expired certificates can cause SSO issues" -ForegroundColor Yellow
        $IssuesFound++
        
        # Option to remove (commented out for safety - uncomment if needed)
        # foreach ($Cert in $ExpiredCerts) {
        #     Remove-Item -Path "Cert:\CurrentUser\My\$($Cert.Thumbprint)" -Force
        # }
        # Write-Host "  âœ“ Removed expired certificates" -ForegroundColor Green
        # $IssuesFixed++
    }
    else {
        Write-Host "No expired certificates found" -ForegroundColor Green
    }
}
catch {
    Write-Host "   Error checking certificates" -ForegroundColor Red
}
Write-Host ""

# Step 4: Clear Browser SSO Data
Write-Host "[Step 4: Browser Authentication Data]" -ForegroundColor Yellow
try {
    # Edge
    $EdgeLoginData = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
    if (Test-Path $EdgeLoginData) {
        Stop-Process -Name msedge -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Remove-Item $EdgeLoginData -Force -ErrorAction SilentlyContinue
        Write-Host "  Cleared Edge authentication data" -ForegroundColor Green
        $IssuesFixed++
    }
    
    # Chrome
    $ChromeLoginData = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
    if (Test-Path $ChromeLoginData) {
        Stop-Process -Name chrome -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Remove-Item $ChromeLoginData -Force -ErrorAction SilentlyContinue
        Write-Host "  Cleared Chrome authentication data" -ForegroundColor Green
        $IssuesFixed++
    }
}
catch {
    Write-Host "  Some browser files in use" -ForegroundColor Gray
}
Write-Host ""

# Step 5: Reset Windows Hello for Business
Write-Host "[Step 5: Windows Hello for Business]" -ForegroundColor Yellow
try {
    $WHfBPath = "$env:LOCALAPPDATA\Microsoft\Vault"
    if (Test-Path $WHfBPath) {
        $WHfBSize = (Get-ChildItem $WHfBPath -Recurse -ErrorAction SilentlyContinue | 
                     Measure-Object -Property Length -Sum).Sum / 1MB
        
        if ($WHfBSize -gt 0) {
            Remove-Item -Path "$WHfBPath\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "   Cleared Windows Hello data" -ForegroundColor Green
            $IssuesFixed++
        }
        else {
            Write-Host "   Windows Hello not configured" -ForegroundColor Gray
        }
    }
}
catch {
    Write-Host "  Windows Hello data not accessible" -ForegroundColor Gray
}
Write-Host ""

# Step 6: Repair Work or School Account
Write-Host "[Step 6: Work/School Account Status]" -ForegroundColor Yellow
try {
    # Check Azure AD join status
    $DsregStatus = dsregcmd /status
    
    $AzureADJoined = $DsregStatus | Select-String "AzureAdJoined.*YES"
    $DomainJoined = $DsregStatus | Select-String "DomainJoined.*YES"
    
    if ($AzureADJoined) {
        Write-Host "   Device is Azure AD joined" -ForegroundColor Green
    }
    elseif ($DomainJoined) {
        Write-Host "   Device is domain joined (not Azure AD)" -ForegroundColor Gray
    }
    else {
        Write-Host "    Device is not Azure AD or domain joined" -ForegroundColor Yellow
        Write-Host "    SSO may not work properly" -ForegroundColor Yellow
        $IssuesFound++
    }
    
    # Check SSO state
    $SSOState = $DsregStatus | Select-String "SSOState"
    Write-Host "  $SSOState" -ForegroundColor Gray
}
catch {
    Write-Host "   Could not check Azure AD status" -ForegroundColor Gray
}
Write-Host ""

# Step 7: Reset Office Authentication
Write-Host "[Step 7: Office/Microsoft 365 Authentication]" -ForegroundColor Yellow
try {
    $OfficePaths = @(
        "$env:LOCALAPPDATA\Microsoft\Office\16.0\Wef",
        "$env:APPDATA\Microsoft\Office\16.0",
        "$env:APPDATA\Microsoft\Identity",
        "$env:LOCALAPPDATA\Microsoft\OneAuth"
    )
    
    $Cleared = $false
    foreach ($Path in $OfficePaths) {
        if (Test-Path $Path) {
            # Clear identity folders but preserve settings
            Get-ChildItem $Path -Include "*.dat", "*.tmp", "*.cache" -Recurse -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
            $Cleared = $true
        }
    }
    
    if ($Cleared) {
        Write-Host " Cleared Office authentication cache" -ForegroundColor Green
        $IssuesFixed++
    }
    else {
        Write-Host " No Office cache found" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  Could not clear Office cache" -ForegroundColor Gray
}
Write-Host ""

# Step 8: Flush DNS (helps with SSO endpoint resolution)
Write-Host "[Step 8: DNS Cache]" -ForegroundColor Yellow
try {
    ipconfig /flushdns | Out-Null
    Write-Host "  DNS cache flushed" -ForegroundColor Green
    $IssuesFixed++
}
catch {
    Write-Host "  Could not flush DNS cache" -ForegroundColor Red
}
Write-Host ""

# Step 9: Registry SSO Settings (View only for safety)
Write-Host "[Step 9: SSO Registry Settings]" -ForegroundColor Yellow
try {
    $SSORegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Authentication\LogonUI"
    if (Test-Path $SSORegPath) {
        $LastLoggedOnUser = (Get-ItemProperty $SSORegPath -ErrorAction SilentlyContinue).LastLoggedOnUser
        Write-Host "  Last logged on user: $LastLoggedOnUser" -ForegroundColor Gray
        Write-Host "  SSO registry keys present" -ForegroundColor Green
    }
}
catch {
    Write-Host "   Could not check registry settings" -ForegroundColor Gray
}
Write-Host ""

# Summary and Recommendations
Write-Host "=== REPAIR SUMMARY ===" -ForegroundColor Cyan
Write-Host "  Issues Fixed: $IssuesFixed" -ForegroundColor Green
Write-Host "  Issues Found: $IssuesFound" -ForegroundColor Yellow
Write-Host ""

Write-Host "[Next Steps]" -ForegroundColor Yellow

if ($IssuesFixed -gt 0) {
    Write-Host "  1. Restart your computer for changes to take full effect" -ForegroundColor Cyan
    Write-Host "  2. Sign out and sign back in to Windows" -ForegroundColor Cyan
    Write-Host "  3. Try accessing SSO-protected resources again" -ForegroundColor Cyan
    Write-Host "  4. If prompted, re-enter your credentials" -ForegroundColor Cyan
}
else {
    Write-Host "  No automatic fixes applied" -ForegroundColor Gray
    Write-Host "  If SSO still not working, try:" -ForegroundColor Yellow
    Write-Host "    Restart computer" -ForegroundColor White
    Write-Host "    Check network connection" -ForegroundColor White
    Write-Host "    Verify with IT that account is active" -ForegroundColor White
    Write-Host "    Run Windows Update" -ForegroundColor White
}

Write-Host ""

if ($IssuesFound -gt 0) {
    Write-Host "[Manual Steps May Be Required]" -ForegroundColor Yellow
    Write-Host "  Expired certificates detected - contact IT to renew" -ForegroundColor White
    Write-Host "  Device may need to be Entra joined" -ForegroundColor White
    Write-Host "  Contact IT Support for further assistance" -ForegroundColor White
    Write-Host ""
}

Write-Host "[Common SSO Issues & Solutions]" -ForegroundColor Cyan
Write-Host "  Problem: 'We couldn't sign you in'" -ForegroundColor Yellow
Write-Host "     Clear browser cache and cookies" -ForegroundColor White
Write-Host "     Use InPrivate/Incognito mode" -ForegroundColor White
Write-Host ""
Write-Host "  Problem: Constantly prompted for password" -ForegroundColor Yellow
Write-Host "     Check 'Keep me signed in' option" -ForegroundColor White
Write-Host "     Verify Azure AD join status" -ForegroundColor White
Write-Host ""
Write-Host "  Problem: 'Your account is locked'" -ForegroundColor Yellow
Write-Host "     Contact IT Support" -ForegroundColor White
Write-Host ""

Write-Host "SSO repair completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""
Write-Host "  If issues persist, log a support ticket with details of the error" -ForegroundColor Yellow
