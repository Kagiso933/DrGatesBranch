# EnterpriseUtilityTool - Git Setup Script
# Run this from: C:\Users\CP376328\Downloads\EnterpriseUtilityTool

$projectDir = "C:\Users\CP376328\Downloads\EnterpriseUtilityTool"
$remoteUrl  = "https://github.com/Kagiso933/DrGates.git"

Write-Host "=== Step 1: Initialising git ===" -ForegroundColor Cyan
Set-Location $projectDir
git init
git checkout -b main

Write-Host "`n=== Step 1b: Removing nested .git folders ===" -ForegroundColor Cyan
Get-ChildItem -Path $projectDir -Recurse -Force -Filter ".git" |
    Where-Object { $_.FullName -ne "$projectDir\.git" } |
    ForEach-Object { Remove-Item -Recurse -Force $_.FullName; Write-Host "Removed: $($_.FullName)" }

Write-Host "`n=== Step 2: Staging files ===" -ForegroundColor Cyan
git add .
git status

Write-Host "`n=== Step 3: Initial commit ===" -ForegroundColor Cyan
git commit -m "Initial commit"

Write-Host "`n=== Step 4: Connecting to remote ===" -ForegroundColor Cyan
git remote add origin $remoteUrl
git remote -v

Write-Host "`n=== Step 5: Pushing to GitHub ===" -ForegroundColor Cyan
git push -u origin main

Write-Host "`nDone! Project is now connected to $remoteUrl" -ForegroundColor Green
