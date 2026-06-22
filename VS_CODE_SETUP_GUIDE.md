# VS Code Setup Guide for Dr Gates Development

**Version:** 1.0  
**Last Updated:** June 15, 2026

---

## Table of Contents
1. [VS Code Installation](#vs-code-installation)
2. [Essential Extensions](#essential-extensions)
3. [Repository Setup](#repository-setup)
4. [Git Branch Management](#git-branch-management)
5. [Project Navigation](#project-navigation)
6. [Building & Running](#building--running)
7. [Debugging](#debugging)
8. [Tips & Tricks](#tips--tricks)

---

## VS Code Installation

### Download & Install

1. **Download VS Code:**
   - Go to https://code.visualstudio.com/
   - Download for Windows
   - Run installer (VSCodeSetup-x64.exe)

2. **Installation Options:**
   - ✅ Add to PATH (recommended)
   - ✅ Create desktop shortcut
   - ✅ Open with Code (context menu)

3. **Verify Installation:**
   ```powershell
   code --version
   # Should return: 1.XX.X (latest version)
   ```

### First Launch

1. Open VS Code
2. Go to Settings (Ctrl+,)
3. Configure:
   - **Theme:** Dark Modern (or your preference)
   - **Font:** Cascadia Code or Consolas
   - **Font Size:** 12-14px
   - **Auto Save:** Off (for Git awareness)

---

## Essential Extensions

### Install Extensions

Press `Ctrl+Shift+X` to open Extensions Marketplace. Search and install:

#### **Tier 1: Must-Have**

| Extension | Publisher | Purpose | Command |
|-----------|-----------|---------|---------|
| C# | Microsoft | C# support, IntelliSense | ms-dotnettools.csharp |
| PowerShell | Microsoft | PowerShell syntax & debugging | ms-vscode.PowerShell |
| XML Tools | Josh Johnson | XAML/XML support | DotJoseph.xml |
| Git Graph | mhutchie | Visual Git history | mhutchie.git-graph |
| GitLens | Eric Amodio | Git blame, history | eamodio.gitlens |

#### **Tier 2: Highly Recommended**

| Extension | Publisher | Purpose |
|-----------|-----------|---------|
| REST Client | Huachao Mao | Test API calls |
| Markdown Preview Enhanced | Yiyi Wang | Better markdown rendering |
| Code Spell Checker | Street Side Software | Spell checking |
| Todo Tree | Gruntfuggly | Highlight TODO/FIXME |
| Thunder Client | Thunder Client | API testing alternative |

#### **Tier 3: Optional But Useful**

| Extension | Publisher | Purpose |
|-----------|-----------|---------|
| Peacock | John Papa | Color-code workspaces |
| Better Comments | Aaron Bond | Highlight comment types |
| Error Lens | Alexander | Show errors inline |
| JSON to CSV | Khaled Jemai | Data conversion |

### Quick Install Command

Open terminal in VS Code and run:

```powershell
code --install-extension ms-dotnettools.csharp
code --install-extension ms-vscode.PowerShell
code --install-extension DotJoseph.xml
code --install-extension mhutchie.git-graph
code --install-extension eamodio.gitlens
```

---

## Repository Setup

### Clone the Repository (First Time)

```powershell
# Create workspace folder
mkdir C:\Dev
cd C:\Dev

# Clone the repo
git clone https://github.com/Kagiso933/DrGatesBranch.git
cd DrGatesBranch

# Open in VS Code
code .
```

### Git Configuration (First Time Only)

```powershell
# Set global Git user (if not already set)
git config --global user.name "Your Name"
git config --global user.email "your.email@capitecbank.co.za"

# Verify configuration
git config --global --list
```

### Trust the Workspace

When opening for the first time:
1. VS Code may ask: "Do you trust the authors of the files in this folder?"
2. Click **Yes, I trust the authors**

---

## Git Branch Management

### Understanding Branch Structure

```
main (production/default branch)
└── feature branches (for development)
    ├── feature/sccm-sync-ui
    ├── feature/branch-user-mode
    ├── bugfix/intune-sync-issue
    └── etc.
```

### Common Git Commands in VS Code

#### View All Branches
1. Click **Source Control** icon (Ctrl+Shift+G)
2. Look at "Branches" section
3. Or use terminal:
   ```powershell
   git branch -a
   ```

#### Create New Branch

**Method 1: Command Palette**
1. Press `Ctrl+Shift+P`
2. Type: "Git: Create Branch"
3. Enter branch name: `feature/branch-user-implementation`
4. Select base branch: `main`

**Method 2: Terminal**
```powershell
# Create and switch to new branch
git checkout -b feature/branch-user-implementation main

# Or create without switching
git branch feature/branch-user-implementation
```

#### Switch Between Branches

**Method 1: Click Branch Name (Bottom Left)**
- Look at bottom-left corner: shows current branch
- Click branch name
- Select different branch from list

**Method 2: Command Palette**
1. Press `Ctrl+Shift+P`
2. Type: "Git: Checkout to"
3. Select branch

**Method 3: Terminal**
```powershell
git checkout feature/branch-user-implementation
```

### Workflow Example: Implementing Branch User Mode

```powershell
# Start from main
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/branch-user-mode

# Make changes...
# (Edit files as needed)

# Stage changes
git add .

# Commit with meaningful message
git commit -m "feat: add branch user mode configuration

- Add BranchUsersMode feature flag to appsettings.json
- Update MainWindow.xaml.cs with conditional button display
- Hide admin-required commands for standard users
- Add SCCM sync button to UI"

# Push to remote
git push -u origin feature/branch-user-mode

# Create Pull Request on GitHub
# (Or let GitHub prompt you via CLI)
```

### Viewing Commit History

#### Method 1: Git Graph Extension (Visual)
1. Open left sidebar
2. Click "Git Graph" icon
3. See visual tree of commits and branches
4. Right-click commits for options (revert, cherry-pick, etc.)

#### Method 2: GitLens (Inline)
1. Open a file
2. Look at line numbers → hover to see commit info
3. Click to view full commit details
4. Or use `Ctrl+Shift+P` → "GitLens: Show Commit Details"

#### Method 3: Terminal
```powershell
# Last 10 commits
git log --oneline -10

# All commits on current branch
git log --oneline --graph

# Commits by specific author
git log --author="Your Name" --oneline
```

### Merging Your Changes

When your feature is ready:

**Via GitHub (Recommended)**
1. Push branch: `git push origin feature/branch-user-mode`
2. Go to https://github.com/Kagiso933/DrGatesBranch
3. GitHub shows "Compare & pull request" button
4. Create Pull Request (PR)
5. Describe changes
6. Request review from team
7. After approval, click "Merge pull request"

**Via Terminal**
```powershell
# Switch to main
git checkout main

# Merge feature branch
git merge feature/branch-user-mode

# Push to remote
git push origin main

# Delete local branch
git branch -d feature/branch-user-mode

# Delete remote branch
git push origin --delete feature/branch-user-mode
```

---

## Project Navigation

### Understanding Project Structure

```
DrGatesBranch/
├── .git/                          # Git repository data
├── .gitignore                     # Files Git should ignore
├── setup-git.ps1                  # Initial Git setup script
├── EnterpriseUtilityTool/         # Main application folder
│   ├── App.xaml                   # WPF application configuration
│   ├── App.xaml.cs                # Application code-behind
│   ├── MainWindow.xaml            # Main UI definition
│   ├── MainWindow.xaml.cs         # Main UI logic [MODIFY FOR BRANCH MODE]
│   ├── AssemblyInfo.cs            # Version & assembly info
│   ├── DrGates.csproj             # C# project file
│   ├── EnterpriseUtilityTool.csproj
│   ├── UtilityTool.csproj
│   ├── Assets/                    # Application icons & images
│   │   ├── UTLogo.ico
│   │   └── icons/                 # Icon assets
│   ├── Config/                    # Configuration files
│   │   └── appsettings.json       # App settings [MODIFY FOR BRANCH MODE]
│   ├── Core/                      # Core application logic
│   │   ├── ConfigurationManager.cs  # Config loading
│   │   ├── Logger.cs              # Logging system
│   │   └── ScriptExecutor.cs      # PowerShell script execution
│   ├── Scripts/                   # PowerShell scripts
│   │   ├── SccmScript.ps1         # SCCM sync [NEW BUTTON]
│   │   ├── IntuneSyncScript.ps1   # Intune sync [KEEP]
│   │   ├── GPUpdateScript.ps1     # Group Policy update [HIDE]
│   │   ├── DiskCleanupScript.ps1  # Disk cleanup [HIDE]
│   │   ├── TempFilesCleanup.ps1   # Temp cleanup [HIDE]
│   │   └── [40+ other scripts]    # Various utilities
│   ├── START_HERE.txt             # Getting started guide
│   └── WebAssets/                 # Web UI (HTML/CSS/JS)
│       ├── index.html             # Main UI [MODIFY FOR BRANCH MODE]
│       ├── lucide.min.js          # Icon library
│       └── [styles in HTML]       # CSS included in HTML
└── README.md / Docs               # Documentation (if any)
```

### Quick Navigation Tips

#### Jump to File
```
Ctrl+P  → Open quick file picker
Type filename or partial path
```

**Examples:**
- `main` → MainWindow.xaml.cs
- `appsettings` → Config/appsettings.json
- `sccm` → Scripts/SccmScript.ps1
- `index` → WebAssets/index.html

#### Go to Line
```
Ctrl+G  → Jump to specific line
Type line number
```

#### Find Across Project
```
Ctrl+Shift+F  → Find in all files
Type search term
```

**Useful searches:**
- `runCommand` → Find all UI button calls
- `_adminCommands` → Find admin elevation checks
- `BranchUsersMode` → Find all branch mode references
- `intune_sync` → Find all Intune sync code

#### Find & Replace
```
Ctrl+H  → Open Find & Replace
```

**Safe replacements:**
- Replace `"disk_cleanup"` in UI buttons with hidden version
- Replace admin command list
- Add new SCCM button

---

## Building & Running

### Prerequisites

Install required software:

1. **.NET SDK** (includes C# compiler)
   - Download: https://dotnet.microsoft.com/download
   - Verify: `dotnet --version`

2. **Visual Studio Build Tools** (optional but recommended)
   - Includes WPF/XAML support
   - Download: https://visualstudio.microsoft.com/downloads/
   - Select "Desktop development with C++"

### Build the Project

**Method 1: VS Code Terminal**

```powershell
# Open terminal: Ctrl+`

# Build project
dotnet build EnterpriseUtilityTool/EnterpriseUtilityTool.csproj

# Or build with Release configuration (optimized)
dotnet build EnterpriseUtilityTool/EnterpriseUtilityTool.csproj -c Release
```

**Method 2: VS Code Command Palette**
```
Ctrl+Shift+P → "Tasks: Run Build Task"
```

### Run the Application

**Method 1: Run with Debugging**
```
F5  → Start debugging
```

**Method 2: Run without Debugging**
```
Ctrl+F5  → Run without debugging
```

**Method 3: Terminal**
```powershell
dotnet run --project EnterpriseUtilityTool/EnterpriseUtilityTool.csproj
```

### Build Output

After successful build:
```
✓ EnterpriseUtilityTool → bin/Debug/net6.0-windows/
  - DrGates.exe (executable)
  - DrGates.dll (library)
  - Supporting files
```

---

## Debugging

### Attach Debugger

When app is running:

1. **Set Breakpoints**
   - Click line number margin in editor
   - Red dot appears → breakpoint set

2. **Debug Toolbar**
   - Continue (F5)
   - Step Over (F10)
   - Step Into (F11)
   - Step Out (Shift+F11)
   - Stop (Shift+F5)

3. **Inspect Variables**
   - Hover over variable → tooltip shows value
   - Or use Debug Console at bottom

### Debug PowerShell Scripts

Edit script for debugging:

```powershell
# Add at top of PowerShell script:
Set-PSDebug -Trace 2

# Or use Write-Output for logging:
Write-Output "DEBUG: Variable value: $variableValue"
Write-Output "DEBUG: Script reached line X"
```

Then check output in application log window.

### View Application Logs

Logs are written to:
```
%LOCALAPPDATA%\Capitec\DrGates\Logs\
```

**Tail logs in VS Code:**
```powershell
# Terminal: watch log file in real-time
Get-Content -Path "$env:LOCALAPPDATA\Capitec\DrGates\Logs\latest.log" -Wait
```

---

## Tips & Tricks

### Code Snippets

Create reusable code blocks. Press `Ctrl+Shift+P` → "Snippets: Configure User Snippets"

**Example: Add PS1 snippet**
```json
"PowerShell Log Output": {
  "prefix": "pslog",
  "body": [
    "Write-Output \"INFO: $1\"",
    "$2"
  ]
}
```

### Git Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open Source Control | Ctrl+Shift+G |
| Commit | Ctrl+Enter (in Source Control) |
| Push | Ctrl+Shift+P → Git Push |
| Pull | Ctrl+Shift+P → Git Pull |
| Stage All Changes | Click checkbox in Source Control |

### Multi-Cursor Editing

```
Ctrl+D       → Select word
Ctrl+Shift+L → Select all occurrences
Ctrl+Alt+↑/↓ → Add cursor above/below
```

Great for:
- Renaming variables across file
- Adding buttons to UI
- Bulk editing

### Split Editor

- Drag file tab to split
- Or `Ctrl+\` to split active editor
- Great for comparing files side-by-side

### Integrated Terminal

- Ctrl+` → Toggle terminal
- Multiple terminals: `+` button or `Ctrl+Shift+\`
- Change shell: `Ctrl+Shift+P` → "Terminal: Select Default Shell"

### Extensions Keyboard Shortcuts

**GitLens:**
- `Ctrl+Shift+P` → "GitLens: Show Blame"
- `Ctrl+Shift+P` → "GitLens: Show Commit Details"

**Git Graph:**
- View Git history visually
- Click "Git Graph" in left sidebar

---

## Workflow for Branch User Implementation

### Day 1: Setup & Understand

```powershell
# Clone repo
git clone https://github.com/Kagiso933/DrGatesBranch.git
cd DrGatesBranch

# Create feature branch
git checkout -b feature/branch-user-mode

# Explore project structure
code .

# Open files and understand:
# 1. MainWindow.xaml.cs (admin commands array)
# 2. appsettings.json (configuration)
# 3. WebAssets/index.html (UI buttons)
```

### Day 2: Implement Configuration

```powershell
# Edit appsettings.json
# Add FeatureFlags section with BranchUsersMode

# Edit ConfigurationManager.cs
# Add parsing for new feature flags

# Stage changes
git add Config/ Core/

# Commit
git commit -m "config: add branch user feature flags"
```

### Day 3: Modify C# Code

```powershell
# Edit MainWindow.xaml.cs
# - Update _adminCommands array
# - Add ShouldShowButton() method
# - Add feature flag logic

# Stage & commit
git add EnterpriseUtilityTool/MainWindow.xaml.cs
git commit -m "feat: implement branch user command filtering"
```

### Day 4: Update UI

```powershell
# Edit WebAssets/index.html
# - Add SCCM sync button
# - Remove/hide admin buttons
# - Add rendering logic

# Stage & commit
git add EnterpriseUtilityTool/WebAssets/
git commit -m "ui: hide admin commands, add SCCM sync button for branch users"
```

### Day 5: Test & PR

```powershell
# Build & test locally
dotnet build EnterpriseUtilityTool/
# Test both admin and branch user modes

# Push to remote
git push -u origin feature/branch-user-mode

# Create Pull Request on GitHub
# Add description from implementation plan
# Request review

# After approval & merge
git checkout main
git pull origin main
git branch -d feature/branch-user-mode
```

---

## Troubleshooting

### Build Failures

**Error:** "CS0117: 'Window' does not contain a definition for 'webView'"
- Solution: Rebuild project, ensure WebView2 NuGet package installed

**Error:** ".NET SDK not found"
- Solution: Install .NET SDK from https://dotnet.microsoft.com/download

**Error:** "Project file not found"
- Solution: Ensure terminal is in correct directory with .csproj files

### Git Issues

**Error:** "fatal: not a git repository"
- Solution: Run `git init` or navigate to correct folder

**Error:** "Merge conflict on index.html"
- Solution: Use "Merge Editor" tab in VS Code to resolve conflicts visually

**Can't push to remote:**
- Check GitHub authentication: `git config --global credential.helper`
- Verify permission on repository

### Application Issues

**App won't start:**
- Check logs: `%LOCALAPPDATA%\Capitec\DrGates\Logs\`
- Try running as Administrator

**WebView2 error:**
- Install or update WebView2 Runtime: https://developer.microsoft.com/en-us/microsoft-edge/webview2/

---

## Additional Resources

### Official Documentation
- VS Code Docs: https://code.visualstudio.com/docs
- C# Documentation: https://docs.microsoft.com/dotnet/csharp/
- WPF Guide: https://docs.microsoft.com/en-us/dotnet/desktop/wpf/

### Git Resources
- Git Documentation: https://git-scm.com/doc
- GitHub Docs: https://docs.github.com/en/desktop

### PowerShell Resources
- PowerShell Docs: https://docs.microsoft.com/powershell/

---

## Quick Reference Card

```
COMMON COMMANDS:

Git:
  git status                      # See current status
  git log --oneline              # View recent commits
  git diff                        # See what changed
  git checkout -b feature/name    # Create new branch
  git commit -m "message"         # Commit changes
  git push origin branch-name     # Push to GitHub

VS Code:
  Ctrl+K Ctrl+O   Open folder
  Ctrl+P          Quick file open
  Ctrl+F          Find in file
  Ctrl+H          Find & replace
  Ctrl+/          Toggle comment
  Ctrl+`          Toggle terminal
  F5              Start debugging
  Ctrl+Shift+B    Run build task

C#/PowerShell:
  Ctrl+Space      IntelliSense
  F12             Go to definition
  Shift+F12       Find all references
  Ctrl+K Ctrl+C   Comment selection
```

---

## Support

If you encounter issues:

1. Check project README
2. Review implementation plan document
3. Check VS Code settings and extensions
4. Consult Git documentation
5. Ask team lead for help

---

**Happy Coding!**

