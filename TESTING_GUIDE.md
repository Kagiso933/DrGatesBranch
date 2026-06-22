# Dr Gates Application - Testing Guide

**Version:** 1.0  
**Date:** June 15, 2026

---

## Quick Start Testing (5 Minutes)

### Prerequisites
- .NET 6.0 SDK or later installed
- Visual Studio or VS Code
- Windows 10/11

### Step 1: Verify Prerequisites

**Check .NET SDK:**
```powershell
dotnet --version
# Should return something like: 6.0.x or higher
```

If not installed, download from: https://dotnet.microsoft.com/download

**Check you're in correct directory:**
```powershell
cd C:\Users\CP376328\DrGatesBranch
dir  # Should see EnterpriseUtilityTool folder
```

---

## Step 2: Build the Application

### Option A: Command Line (Fastest)

```powershell
# Navigate to repo
cd C:\Users\CP376328\DrGatesBranch

# Build in Release mode (optimized)
dotnet build EnterpriseUtilityTool -c Release

# Or Debug mode (faster build, more debugging info)
dotnet build EnterpriseUtilityTool -c Debug
```

**Expected output:**
```
Build started...
... building ...
EnterpriseUtilityTool -> bin\Release\net6.0-windows\DrGates.exe
Build succeeded.
```

### Option B: Visual Studio

1. Open Visual Studio
2. File → Open → Project/Solution
3. Navigate to: `C:\Users\CP376328\DrGatesBranch\EnterpriseUtilityTool\`
4. Select `.csproj` file
5. Right-click Solution → Build Solution (or Ctrl+Shift+B)

### Option C: VS Code

1. Open folder: `C:\Users\CP376328\DrGatesBranch`
2. Press `Ctrl+Shift+B` (Run Build Task)
3. Select `.NET: build` from menu

---

## Step 3: Locate the Built Application

After successful build, find the executable at:

**Debug build:**
```
C:\Users\CP376328\DrGatesBranch\EnterpriseUtilityTool\bin\Debug\net6.0-windows\DrGates.exe
```

**Release build:**
```
C:\Users\CP376328\DrGatesBranch\EnterpriseUtilityTool\bin\Release\net6.0-windows\DrGates.exe
```

---

## Step 4: Test Admin Mode (Default)

### Config Setup

Edit the config file:
```
C:\Users\CP376328\DrGatesBranch\EnterpriseUtilityTool\Config\appsettings.json
```

**Ensure it looks like this (Admin Mode):**
```json
"FeatureFlags": {
  "BranchUsersMode": false,
  "HideDiskCleanup": false,
  "HideTempCleanup": false,
  "HideResetNetwork": false,
  "HideDeployClaudeCode": false,
  "HideGPUpdate": false,
  "HideDNSFlush": false,
  "ShowSCCMSync": true,
  "ShowIntuneSyncForAll": true
}
```

### Run the Application

**Option 1: Double-click the EXE**
```
C:\Users\CP376328\DrGatesBranch\EnterpriseUtilityTool\bin\Release\net6.0-windows\DrGates.exe
```

**Option 2: PowerShell**
```powershell
& "C:\Users\CP376328\DrGatesBranch\EnterpriseUtilityTool\bin\Release\net6.0-windows\DrGates.exe"
```

**Option 3: From VS Code Terminal**
```powershell
cd EnterpriseUtilityTool
dotnet run --configuration Release
```

### What You Should See

1. **Window opens** with Dr Gates UI
2. **Blue/cyan gradient background** with modern design
3. **Multiple tabs** at top: Dashboard, System Health, IT Services, Network, Support
4. **Cards with buttons** in each section

### Admin Mode: Verify All Buttons Are Visible

**Expected buttons visible:**

✅ **System Updates Tab:**
- Group Policy Update (with "Admin" badge)
- Intune Sync (with "Admin" badge)
- SCCM Sync (with "Admin" badge) ← **NEW BUTTON**

✅ **Clean & Optimize Tab:**
- Disk Cleanup (with "Admin" badge)
- Temp Files Cleanup (with "Admin" badge)
- Network Reset (with "Admin" badge)
- Deploy Claude Code (with "Admin" badge)

✅ **Network Tab:**
- DNS Flush (with "Admin" badge)
- Various diagnostic buttons

**If any button is missing:** ❌ Check build output, rebuild the project

### Admin Mode: Test a Button Click

1. Click **"Check System Connectivity"** button (non-admin, safe)
2. You should see output in the log area at bottom
3. Button works → Application is functioning

**If it doesn't work:**
- Check if output appears in log area
- Check Windows Event Viewer for errors
- Check logs at: `%LOCALAPPDATA%\Capitec\DrGates\Logs\`

---

## Step 5: Test Branch User Mode

### Config Setup

Edit `appsettings.json` to enable Branch User Mode:

```json
"FeatureFlags": {
  "BranchUsersMode": true,
  "HideDiskCleanup": true,
  "HideTempCleanup": true,
  "HideResetNetwork": true,
  "HideDeployClaudeCode": true,
  "HideGPUpdate": true,
  "HideDNSFlush": true,
  "ShowSCCMSync": true,
  "ShowIntuneSyncForAll": true
}
```

**Save the file** (Ctrl+S if in editor)

### Close and Reopen Application

The app needs to restart to reload the configuration:

1. Close Dr Gates window (Alt+F4)
2. Wait 2 seconds
3. Run the app again:
   ```powershell
   & "C:\Users\CP376328\DrGatesBranch\EnterpriseUtilityTool\bin\Release\net6.0-windows\DrGates.exe"
   ```

### Branch User Mode: Verify Buttons Are Hidden

**Expected buttons HIDDEN (not visible):**
- ❌ Group Policy Update
- ❌ Disk Cleanup
- ❌ Temp Files Cleanup
- ❌ Network Reset
- ❌ Deploy Claude Code
- ❌ DNS Flush

**Expected buttons VISIBLE:**
- ✅ Intune Sync (under Device Management)
- ✅ SCCM Sync (under Device Management) ← **NEW**
- ✅ All diagnostic/troubleshooting buttons
- ✅ Printer mapping
- ✅ SSO fixes

**If buttons are still showing:** ❌ Check console logs (see next section)

---

## Step 6: Check Console Logs

### Open Browser Developer Tools

While app is running:

1. **Press F12** (opens Developer Tools)
2. Click **Console** tab
3. Look for these messages:

**Admin Mode:**
```
App initialized with config: {isAdmin: true, branchUsersMode: false, ...}
Admin mode - showing all buttons
```

**Branch User Mode:**
```
App initialized with config: {isAdmin: true, branchUsersMode: true, ...}
Branch user mode - applying visibility rules
Button btn-disk-cleanup: hidden
Button btn-temp-cleanup: hidden
Button btn-gpupdate: hidden
Button btn-sccm-sync: shown
Button btn-intune-sync: shown
```

### If You See Errors

**Error: "Cannot read property 'BranchUsersMode' of undefined"**
- Solution: Config not loading properly
- Check: Is appsettings.json in correct location?
- Fix: Rebuild project and try again

**Error: "SyntaxError: Unexpected token in JSON"**
- Solution: JSON syntax error in appsettings.json
- Fix: Use online JSON validator to check syntax
- Or: Restore from backup and re-edit

---

## Step 7: Full Testing Checklist

### Admin Mode Tests

Run with `"BranchUsersMode": false`:

- [ ] Application starts without errors
- [ ] All buttons visible
- [ ] F12 console shows "Admin mode - showing all buttons"
- [ ] Click "Check System Connectivity" → see output
- [ ] Click "System Info" → see output
- [ ] Buttons don't show errors when clicked
- [ ] No errors in F12 console

### Branch User Mode Tests

Run with `"BranchUsersMode": true`:

- [ ] Application starts without errors
- [ ] Disk Cleanup button NOT visible
- [ ] Temp Files Cleanup button NOT visible
- [ ] Network Reset button NOT visible
- [ ] Claude Code button NOT visible
- [ ] Group Policy Update button NOT visible
- [ ] DNS Flush button NOT visible
- [ ] Intune Sync button IS visible
- [ ] SCCM Sync button IS visible
- [ ] System diagnostic buttons visible
- [ ] F12 console shows "Branch user mode" message
- [ ] F12 console shows individual button visibility (shown/hidden)
- [ ] Click "Check System Connectivity" → see output
- [ ] No errors in F12 console

### UI Appearance Tests

- [ ] Dr Gates window opens and resizes properly
- [ ] Buttons have proper styling (gradient, shadows, hover effects)
- [ ] Icons display correctly (from Lucide library)
- [ ] "Admin" badges show on admin-required buttons
- [ ] Color scheme is modern (blue/cyan gradients)
- [ ] No layout broken elements
- [ ] Tabs (Dashboard, System Health, IT Services, Network, Support) clickable

---

## Step 8: Advanced Testing (Co-Managed Device)

If testing on a **co-managed device** (SCCM + Intune):

### Test SCCM Sync Button

1. Run app in Branch User Mode
2. Navigate to **System Health** tab
3. Click **"SCCM Sync"** button
4. Watch for output in log area

**Expected output:**
```
===========================================
SCCM CLIENT SYNCHRONIZATION
===========================================

Initiating SCCM client actions...

Triggering: Machine Policy Retrieval...
✓ Machine Policy Retrieval triggered successfully

Triggering: Machine Policy Evaluation...
✓ Machine Policy Evaluation triggered successfully

Triggering: Software Updates Scan...
✓ Software Updates Scan triggered successfully

Triggering: Software Updates Deployment...
✓ Software Updates Deployment triggered successfully

===========================================
✓ SCCM sync completed!
===========================================
```

**If it fails:**
- Device may not be SCCM-enrolled
- Or running as non-admin (SCCM requires admin)
- Check logs at: `%LOCALAPPDATA%\Capitec\DrGates\Logs\`

### Test Intune Sync Button

1. Click **"Intune Sync"** button
2. Company Portal app should appear/activate
3. You should see sync activity in Company Portal

**Expected:** Company Portal runs in background and syncs policies

---

## Step 9: Testing Workflow (Complete Scenario)

### Scenario 1: Admin Testing Workflow

```powershell
# 1. Build
cd C:\Users\CP376328\DrGatesBranch
dotnet build EnterpriseUtilityTool -c Release

# 2. Verify config is in Admin mode
# Edit: EnterpriseUtilityTool\Config\appsettings.json
# Set: "BranchUsersMode": false

# 3. Run app
& "EnterpriseUtilityTool\bin\Release\net6.0-windows\DrGates.exe"

# 4. Verify all buttons visible
# Press F12 to check console

# 5. Test a few buttons
# Click "Check System Connectivity"
# Click "System Info"

# 6. Verify console shows "Admin mode - showing all buttons"
```

### Scenario 2: Branch User Testing Workflow

```powershell
# 1. Close app (from scenario 1)

# 2. Edit config to Branch mode
# File: EnterpriseUtilityTool\Config\appsettings.json
# Change: "BranchUsersMode": true
# Change other Hide flags to: true

# 3. Run app again
& "EnterpriseUtilityTool\bin\Release\net6.0-windows\DrGates.exe"

# 4. Verify ONLY safe buttons visible
# Verify admin buttons hidden

# 5. Press F12 and check console
# Should show: "Branch user mode - applying visibility rules"
# Should show each button as "shown" or "hidden"

# 6. Test clicking Intune Sync button
# Should work without admin prompts (or with graceful failure)

# 7. Close app
```

---

## Troubleshooting Common Issues

### Issue 1: Build Fails

**Error:** "CS0117: 'Window' does not contain a definition for 'webView'"

**Solution:**
```powershell
# Clean build
dotnet clean EnterpriseUtilityTool
dotnet build EnterpriseUtilityTool
```

**Or:** Verify WebView2 NuGet package installed
```powershell
dotnet add EnterpriseUtilityTool package Microsoft.Web.WebView2
```

---

### Issue 2: App Crashes on Startup

**Error:** Application closes immediately or shows error dialog

**Check:**
1. Look for error message in dialog
2. Check Event Viewer (Windows Logs → Application)
3. Check logs at: `%LOCALAPPDATA%\Capitec\DrGates\Logs\`

**Common causes:**
- WebView2 Runtime not installed
- appsettings.json has syntax error
- Missing Config folder

**Solution:**
```powershell
# Install/Update WebView2 Runtime
# Download from: https://developer.microsoft.com/en-us/microsoft-edge/webview2/

# Or rebuild and try again
dotnet clean
dotnet build
```

---

### Issue 3: Buttons Not Hiding in Branch Mode

**Problem:** Set `BranchUsersMode: true` but buttons still visible

**Check:**
1. Did you save appsettings.json? (Ctrl+S)
2. Did you close and reopen the app?
3. Check F12 console - what does it say?

**Solution:**
```powershell
# Force close all instances
taskkill /F /IM DrGates.exe

# Verify config is correct
notepad "C:\Users\CP376328\DrGatesBranch\EnterpriseUtilityTool\Config\appsettings.json"
# Look for: "BranchUsersMode": true

# Rebuild and run
dotnet build EnterpriseUtilityTool -c Release
& "EnterpriseUtilityTool\bin\Release\net6.0-windows\DrGates.exe"
```

---

### Issue 4: F12 Developer Tools Not Opening

**Problem:** F12 key doesn't open console

**Solution:**
1. Make sure app window is focused (click on it)
2. Try: Ctrl+Shift+I (alternative shortcut)
3. If still not working, the WebView2 version may be old
   - Update WebView2 Runtime
   - Rebuild app

---

### Issue 5: "WebView2 Runtime not found"

**Error Message:** "WebView2 Runtime is required"

**Solution:**
1. Download WebView2 Runtime Installer
   - URL: https://developer.microsoft.com/en-us/microsoft-edge/webview2/
2. Run installer
3. Restart computer
4. Run Dr Gates again

---

## Logging & Debugging

### View Application Logs

Logs are stored at:
```
C:\Users\[YourUsername]\AppData\Local\Capitec\DrGates\Logs\
```

**Real-time log viewing:**
```powershell
# PowerShell command to watch logs live
Get-Content -Path "$env:LOCALAPPDATA\Capitec\DrGates\Logs\latest.log" -Wait
```

### Log Levels

- **INFO** - Normal operation messages
- **WARNING** - Potential issues but app continues
- **ERROR** - Error occurred but app may continue

### What to Look For

**Success indicators:**
```
INFO: Configuration loaded from C:\...\appsettings.json
INFO: Web interface initialized with feature flags
INFO: Admin privileges: true/false
INFO: Executing script: check_system_connectivity
```

**Error indicators:**
```
ERROR: Error loading configuration
ERROR: Error initializing WebView2
ERROR: Error checking admin privileges
ERROR: Exception: [details]
```

---

## Performance Testing

### Expected Performance

**App startup time:** 2-3 seconds  
**Button click response:** Immediate  
**Script execution:** 5-30 seconds depending on script

### If Slow

1. Check logs for warnings
2. Verify not running low on system resources
3. Try Release build instead of Debug
4. Check antivirus isn't blocking

---

## Final Verification Checklist

After completing all tests above:

- [ ] **Admin Mode:**
  - [x] Builds successfully
  - [x] All buttons visible
  - [x] Sample button click works
  - [x] Console shows "Admin mode" message

- [ ] **Branch User Mode:**
  - [x] Config loads correctly
  - [x] Hidden buttons actually hidden
  - [x] Visible buttons still clickable
  - [x] Console shows "Branch user mode" message

- [ ] **No Errors:**
  - [x] No build warnings
  - [x] No console errors in F12
  - [x] No Windows error events
  - [x] Application closes cleanly

- [ ] **UI Proper:**
  - [x] All buttons styled correctly
  - [x] Icons display properly
  - [x] Tabs work
  - [x] Modern design looks good

---

## Next: Commit to Git

When all tests pass:

```powershell
cd C:\Users\CP376328\DrGatesBranch

# Stage changes
git add -A

# Commit with detailed message
git commit -m "feat: implement branch user mode with feature flags

- Add FeatureFlags configuration to appsettings.json
- Add ConfigurationManager support for feature flags
- Add dynamic button visibility in MainWindow.xaml.cs
- Add SCCM sync button to Device Management section
- Add JavaScript logic to hide/show buttons based on config
- Tested in both Admin and Branch user modes
- All buttons hidden/shown as expected"

# Push to GitHub
git push origin main
```

---

## Summary

✅ **Build** - `dotnet build`  
✅ **Test Admin Mode** - Set `BranchUsersMode: false`, run app, verify all buttons visible  
✅ **Test Branch Mode** - Set `BranchUsersMode: true`, run app, verify admin buttons hidden  
✅ **Check Logs** - Press F12, verify console messages  
✅ **Commit** - `git add -A && git commit -m "..."` && `git push`  

You're ready to test! 🎉

