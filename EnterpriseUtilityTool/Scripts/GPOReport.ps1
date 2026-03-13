Write-Output "Running Group Policy Report..."
try {
    # Get the user's GPO results
    Write-Output "--- User GPO Report ---"
    $userGPOReport = gpresult.exe /r /scope user
    $userGPOReport | Out-String | Write-Output

    # Get the computer's GPO results
    Write-Output "`n--- Computer GPO Report ---"
    $computerGPOReport = gpresult.exe /r /scope computer
    $computerGPOReport | Out-String | Write-Output
}
catch {
    Write-Output "ERROR: An error occurred while running gpresult."
    Write-Output $_.Exception.Message
}