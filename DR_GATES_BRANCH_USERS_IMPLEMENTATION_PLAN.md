# Dr Gates Application - Branch Users Implementation Plan

**Document Date:** June 15, 2026  
**Version:** 1.0  
**For:** Capitec Bank - Co-Managed Device Branch User Configuration

---

## Executive Summary

This document outlines the technical modifications required to customize the Dr Gates Enterprise Utility Tool for **Branch Users** operating on **co-managed devices** (SCCM + Intune hybrid management). The changes focus on removing admin-restricted operations while adding co-managed device management features.

---

## Current System Analysis

### Application Architecture
- **Framework:** WPF (Windows Presentation Foundation) with C# backend
- **UI Engine:** WebView2 (HTML/CSS/JavaScript frontend)
- **Script Execution:** PowerShell-based command runner
- **Administration:** Role-based access control

### Admin-Required Commands (Current)

| Command | Script File | Function | Admin Elevation |
|---------|------------|----------|-----------------|
| `disk_cleanup` | DiskCleanupScript.ps1 | Disk space recovery | Required |
| `temp_files_cleanup` | TempFilesCleanup.ps1 | Temporary file cleanup | Required |
| `gpupdate` | GPUpdateScript.ps1 | Group Policy refresh | Required |
| `intune_sync` | IntuneSyncScript.ps1 | Intune/Company Portal sync | Required |
| `dns_flush` | DNSFlush.ps1 | DNS cache clear | Required |
| `reset_network` | ResetNetwork.ps1 | Network stack reset | Required |
| `deploy-claudecode` | Deploy-ClaudeCode-Enhanced.ps1 | Claude Code deployment | Required |

### Non-Admin Commands (Available to All)
- System diagnostics (info, connectivity, performance)
- Cache clearing (Teams, browsers)
- Network diagnostics
- User account status
- Printer mapping/viewing
- SSO troubleshooting
- OneDrive backup checks

---

## Branch User Requirements & Constraints

### Co-Managed Environment Context
- **Devices:** Hybrid management (SCCM for on-premises + Intune for cloud)
- **User Type:** Regular employees (non-IT staff)
- **Access Level:** Standard user privileges (no admin elevation)
- **Primary Need:** Self-service device management without admin intervention

### Feature Decisions

#### 🔴 REMOVE (Admin-Restricted for Branch Users)
These tasks require admin elevation and should be **removed from branch user UI**:

1. **Disk Cleanup** (`disk_cleanup`)
   - Reason: Requires admin to modify file system
   - Action: Hide/Remove button
   - Risk: Could corrupt system if misused

2. **Temporary Files Cleanup** (`temp_files_cleanup`)
   - Reason: Targets system directories
   - Action: Hide/Remove button
   - Alternative: User can use Windows Disk Cleanup utility

3. **Network Stack Reset** (`reset_network`)
   - Reason: Modifies network adapter settings
   - Action: Hide/Remove button
   - Impact: Could disconnect user from network

4. **Claude Code Deployment** (`deploy-claudecode`)
   - Reason: System-wide application installation
   - Action: Hide/Remove button
   - Alternative: IT team distributes via SCCM

#### 🟡 HIDE/GATE (Available Only with Admin Approval)
These commands exist but should be conditional:

1. **Group Policy Update** (`gpupdate`)
   - Status: KEEP but gate behind configuration
   - Decision: Show button only if device is NOT domain-joined to branch domain
   - Reason: Co-managed devices pull GPOs from AD + Intune
   - Recommendation: HIDE for standard branch users; only IT support staff access

2. **DNS Flush** (`dns_flush`)
   - Status: KEEP but conditional
   - Decision: HIDE from standard branch users; keep for troubleshooting tier
   - Reason: Could affect user connectivity if misconfigured

#### 🟢 KEEP (Essential for Co-Managed Users)

1. **Intune Sync** (`intune_sync`) - CRITICAL
   - Status: ✅ SHOW & ENABLE
   - Reason: Branch users need ability to sync Intune policies
   - Script: IntuneSyncScript.ps1 (launches Company Portal sync)
   - Access: Allow for all branch users
   - Note: This also triggers Company Portal sync

2. **Company Portal Sync** - IMPLICIT
   - Status: ✅ INCLUDED in Intune Sync
   - Reason: IntuneSyncScript.ps1 calls `Start-Process "intunemanagementextension://syncapp"`
   - Decision: NO separate button needed (already part of Intune Sync)

#### 🟢 ADD (NEW for Co-Managed Environment)

1. **SCCM Sync** (`sccm_sync`) - HIGH PRIORITY
   - Status: ✅ MUST ADD
   - Current State: Script exists (SccmScript.ps1) but NO UI button
   - Why Needed: Co-managed devices need on-premises policy/software updates
   - Script Location: `EnterpriseUtilityTool\Scripts\SccmScript.ps1`
   - Admin Required: Technically requires admin (invokes WMI methods)
   - Recommendation: 
     - Option A: Add as admin-required button (users request IT if needed)
     - Option B: Pre-elevate on co-managed devices (IT configures AppLocker exemptions)
   - UI Location: Add to "Device Management" section near Intune Sync
   - Button Design: Match existing button styling, use cloud/sync icon

2. **Windows Updates Status** - KEEP (Already Available)
   - Current: Already exposed as `windows_update_status` (non-admin)
   - This provides visibility into SCCM software deployments

---

## Implementation Roadmap

### Phase 1: Configuration Flags (appsettings.json)
Add new feature toggles:

```json
{
  "FeatureFlags": {
    "BranchUsersMode": true,
    "HideDiskCleanup": true,
    "HideTempCleanup": true,
    "HideResetNetwork": true,
    "HideDeployClaudeCode": true,
    "HideGPUpdate": true,
    "HideDNSFlush": true,
    "ShowSCCMSync": true,
    "ShowIntuneSyncForAll": true,
    "CompanyPortalSyncMethod": "Intune"
  }
}
```

### Phase 2: C# Backend Changes (MainWindow.xaml.cs)

**Update Admin Commands Array:**
```csharp
// For Branch Users Only
private readonly string[] _adminCommands = new[]
{
    "gpupdate",        // Keep but conditionally show
    "intune_sync",     // Keep - essential for co-managed
    "sccm_sync",       // Add - new for SCCM sync
    "dns_flush"        // Keep but conditionally show
};

// Removed for branch users:
// "disk_cleanup",
// "temp_files_cleanup",
// "reset_network",
// "deploy-claudecode"
```

**Add Feature Flag Logic:**
```csharp
private bool ShouldShowButton(string commandName)
{
    if (ConfigurationManager.Config.FeatureFlags.BranchUsersMode)
    {
        return commandName switch
        {
            "disk_cleanup" => !ConfigurationManager.Config.FeatureFlags.HideDiskCleanup,
            "temp_files_cleanup" => !ConfigurationManager.Config.FeatureFlags.HideTempCleanup,
            "gpupdate" => !ConfigurationManager.Config.FeatureFlags.HideGPUpdate,
            "intune_sync" => true, // Always show for co-managed
            "sccm_sync" => ConfigurationManager.Config.FeatureFlags.ShowSCCMSync,
            _ => true
        };
    }
    return true; // Show all for admin mode
}
```

### Phase 3: UI Updates (WebAssets/index.html)

**3.1 Remove/Hide Buttons:**
- Remove `<button onclick="runCommand('disk_cleanup')">` section
- Remove `<button onclick="runCommand('temp_files_cleanup')">` section  
- Hide `<button onclick="runCommand('reset_network')">` section
- Hide `<button onclick="runCommand('deploy-claudecode')">` section
- Conditionally hide `<button onclick="runCommand('gpupdate')">` (default hidden for branch users)
- Conditionally hide `<button onclick="runCommand('dns_flush')">` (default hidden for branch users)

**3.2 Add SCCM Sync Button:**

Insert new button in "Device Management" section (around line 1250):

```html
<button onclick="runCommand('sccm_sync')" class="admin-required">
    <i data-lucide="hard-drive"></i>
    <span>SCCM Sync</span>
    <span class="button-admin-badge">
        <i data-lucide="lock"></i>
        Admin
    </span>
</button>
```

**3.3 Update Section Header:**

Change from just "System Updates" to "Device Management":
```html
<div class="card-header">
    <div class="card-icon">
        <i data-lucide="server"></i>
    </div>
    <div class="card-title">Device Management</div>
</div>
```

**3.4 Add Conditional Rendering in JavaScript:**

```javascript
function renderDeviceManagementSection() {
    const container = document.getElementById('device-management');
    const buttons = [];
    
    if (window.config.branchUsersMode) {
        // Show only co-managed relevant buttons
        if (!window.config.hideGPUpdate) {
            buttons.push(createButton('gpupdate', 'Group Policy Update'));
        }
        buttons.push(createButton('intune_sync', 'Intune Sync'));
        
        if (window.config.showSCCMSync) {
            buttons.push(createButton('sccm_sync', 'SCCM Sync'));
        }
    } else {
        // Show all (admin mode)
        // ... existing logic
    }
    
    container.innerHTML = buttons.join('');
}
```

### Phase 4: Script Updates

**4.1 Verify SCCM Script** (Scripts/SccmScript.ps1)
- ✅ Script exists and functional
- Action: Test on co-managed device
- No changes needed

**4.2 Verify Intune Script** (Scripts/IntuneSyncScript.ps1)
- ✅ Script exists and calls Company Portal
- Action: Confirm works for all users
- No changes needed

**4.3 Add Documentation:**
- Update START_HERE.txt with branch user setup
- Document feature flags

---

## Detailed Feature Specifications

### SCCM Sync Implementation

**File:** `EnterpriseUtilityTool\Scripts\SccmScript.ps1`  
**Status:** ✅ Exists, ready to use  
**Function:** Triggers SCCM client actions

**Actions Performed:**
1. Machine Policy Retrieval
2. Machine Policy Evaluation
3. Software Updates Scan
4. Software Updates Deployment

**Expected Output:**
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

**Requirements:**
- Device must be SCCM-enrolled
- User executing must have admin elevation (or script runs as admin)
- PowerShell execution policy allows running .ps1 files

### Intune Sync Implementation

**File:** `EnterpriseUtilityTool\Scripts\IntuneSyncScript.ps1`  
**Status:** ✅ Exists, ready to use  
**Function:** Triggers Intune policy sync + Company Portal sync

**Process:**
1. Calls Company Portal via URI: `intunemanagementextension://syncapp`
2. Triggers background Intune policy evaluation
3. Applies any pending Intune policies

**Why This Replaces Separate Company Portal Button:**
- IntuneSyncScript already calls Company Portal sync
- No need for redundant button
- One click = full Intune + Company Portal sync

**Recommendation:** 
- Rename button to "Intune & Company Portal Sync" or keep as "Intune Sync"
- Update tooltip: "Syncs Intune policies and Company Portal apps"

---

## Security & Access Control

### Role-Based Access

#### Standard Branch User
- ✅ Can use: System diagnostics, cache clearing, printer mapping, troubleshooting tools
- ✅ Can trigger: Intune Sync, SCCM Sync (if admin-elevated by IT)
- ❌ Cannot use: Disk cleanup, temp cleanup, network reset, system deployment

#### IT Support / Help Desk
- ✅ All standard user features
- ✅ Can use: GPUpdate, DNS Flush (conditional)
- ✅ Can deploy Claude Code (admin elevation required)

#### Admin / System Admin
- ✅ Full access to all commands
- ✅ Can modify configuration flags
- ✅ Can enable/disable features per user group

### Admin Elevation Best Practices

For SCCM & GPUpdate elevation on co-managed devices, recommend one of:

**Option A: AppLocker Exemption** (Recommended)
- IT creates AppLocker rule
- Exempts `DrGates.exe` from elevation requirement
- Users can run SCCM/GPUpdate without prompting

**Option B: Run-As Service**
- Run Dr Gates as low-privilege service on device
- Use scheduled task elevation for admin commands
- More complex, requires SYSTEM account trust

**Option C: Self-Service Portal**
- Users request SCCM/GPUpdate via ticketing system
- IT runs on behalf of user
- Least technical for users, more workload for IT

---

## Configuration File Changes

### Update appsettings.json

**Before (Current):**
```json
{
  "Scripts": {
    "AllowGPUpdate": true,
    "AllowSCCMSync": true,
    "AllowDiskCleanup": true,
    "AllowCacheClear": true,
    "AllowServiceRestart": true,
    "AllowRegistryModification": false
  }
}
```

**After (Branch Users):**
```json
{
  "FeatureFlags": {
    "BranchUsersMode": true
  },
  "Scripts": {
    "AllowGPUpdate": false,
    "AllowSCCMSync": true,
    "AllowDiskCleanup": false,
    "AllowCacheClear": true,
    "AllowServiceRestart": false,
    "AllowRegistryModification": false,
    "AllowIntuneSyncForAll": true
  }
}
```

---

## Testing Checklist

- [ ] SCCM button appears in UI
- [ ] SCCM button hidden/disabled for non-admin users
- [ ] SCCM sync script executes on co-managed device
- [ ] Intune sync button available to all branch users
- [ ] Group Policy Update button hidden for branch users
- [ ] Disk cleanup button removed/hidden
- [ ] Temp cleanup button removed/hidden
- [ ] Network reset button removed/hidden
- [ ] Claude Code deployment button removed/hidden
- [ ] Admin users can see all buttons (via config toggle)
- [ ] Feature flags properly read from appsettings.json
- [ ] Error handling works if SCCM not installed
- [ ] Logging captures all sync attempts
- [ ] UI renders properly with buttons hidden/shown

---

## Rollout Plan

### Week 1: Development
- [ ] Update MainWindow.xaml.cs with feature flags
- [ ] Update index.html with new SCCM button
- [ ] Update appsettings.json
- [ ] Add configuration logic in ConfigurationManager.cs

### Week 2: Testing
- [ ] Test in branch user mode (non-admin)
- [ ] Test in admin mode (full access)
- [ ] Test SCCM sync on co-managed device
- [ ] Test Intune sync on co-managed device
- [ ] Verify disabled buttons don't break UI

### Week 3: Deployment
- [ ] Build release version
- [ ] Deploy to pilot branch users
- [ ] Gather feedback
- [ ] Deploy to remaining branches

### Week 4: Support & Documentation
- [ ] Train IT support team on new features
- [ ] Create user documentation
- [ ] Monitor logs for issues

---

## Support & Documentation

### User Help Text (Tooltips)

**Intune Sync:**
> "Syncs your device with Intune policies and triggers Company Portal app updates. Use this if you've installed new apps via Company Portal or need to receive new policies."

**SCCM Sync:**
> "Triggers SCCM client to check for new software deployments and policies from your IT department. May require administrator approval."

**Group Policy Update (Hidden):**
> "Updates Group Policy settings from Active Directory. Available to IT staff only."

### IT Documentation

- Deployment guide
- Feature flag reference
- SCCM prerequisites
- Intune prerequisites
- Troubleshooting guide
- Log file locations

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|-----------|
| SCCM sync fails on non-SCCM devices | Low | Error handling in script, clear error message |
| Users repeatedly click sync buttons | Low | Add cooldown timer, show success notification |
| Admin buttons visible to standard users | Medium | Test feature flags thoroughly, code review |
| Intune + SCCM conflict | Medium | Device already managed - no conflict expected |
| Unintended elevation for standard users | High | Never auto-elevate, require explicit admin action |

---

## Summary of Changes

### Remove from Branch User UI
- ❌ Disk Cleanup
- ❌ Temporary Files Cleanup
- ❌ Network Stack Reset
- ❌ Claude Code Deployment

### Hide from Branch User UI (Conditional)
- 🔒 Group Policy Update (show only on request)
- 🔒 DNS Flush (show only for IT support tier)

### Keep for Branch Users
- ✅ Intune Sync (CRITICAL for co-managed)
- ✅ System diagnostics
- ✅ Cache clearing
- ✅ Troubleshooting tools

### Add for Branch Users
- ➕ SCCM Sync (NEW button, essential for co-managed)

### No Change Needed
- ✅ Company Portal sync (implicit in Intune Sync)
- ✅ Windows Updates visibility (already available)

---

## Approval & Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| IT Manager | | | |
| Security | | | |
| Branch Manager | | | |
| Development Lead | | | |

---

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-06-15 | Claude | Initial plan for branch user configuration |
| | | | |

---

## Appendix A: File Modification Summary

```
Files to Modify:
├── EnterpriseUtilityTool/
│   ├── MainWindow.xaml.cs (update admin commands array, add feature flag logic)
│   ├── Config/appsettings.json (add BranchUsersMode flag)
│   ├── Core/ConfigurationManager.cs (add FeatureFlags section parsing)
│   └── WebAssets/index.html (add SCCM button, hide/remove buttons, add rendering logic)
└── Documentation/
    └── CREATE: BRANCH_USER_SETUP.md (user guide)
```

## Appendix B: Command Mapping

```
UI Button → Script File → PowerShell Execution

Group Policy Update (gpupdate) → GPUpdateScript.ps1
Intune Sync (intune_sync) → IntuneSyncScript.ps1
SCCM Sync (sccm_sync) → SccmScript.ps1
Disk Cleanup (disk_cleanup) → DiskCleanupScript.ps1 [HIDE]
Temp Files Cleanup (temp_files_cleanup) → TempFilesCleanup.ps1 [HIDE]
DNS Flush (dns_flush) → DNSFlush.ps1 [HIDE]
Network Reset (reset_network) → ResetNetwork.ps1 [HIDE]
Claude Code Deployment (deploy-claudecode) → Deploy-ClaudeCode-Enhanced.ps1 [HIDE]
```

---

**Document Status:** Ready for Development  
**Next Step:** Assign to development team for Phase 1 implementation
