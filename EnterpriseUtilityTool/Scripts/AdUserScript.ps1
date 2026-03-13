# This script checks Active Directory connectivity and provides user information.
# It is called by the C# host and writes output for the GUI.

function Write-Log {
    param(
        [string]$Message
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Output "[$timestamp] $Message"
}

try {
    Write-Log -Message "--- AD & User Information ---"

    $searchRoot = $env:USERDNSDOMAIN
    $UserPrincipalName = $(whoami -upn)
    
    try {
        $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
        $searcher.Filter = "(&(userprincipalname=$UserPrincipalName))"
        $searcher.SearchRoot = "LDAP://$searchRoot"
        $ADUserPath = $Searcher.FindOne()
    } catch {
        Write-Log -Message "Error: Could not connect to Active Directory."
        Write-Log -Message "Exception: $($_.Exception.Message)"
    }

    if ($ADUserPath) {
        Write-Log -Message "Status: Connected to Active Directory."
        
        $ADUser = $ADUserPath.GetDirectoryEntry()
        Write-Log -Message "Username: $($ADUser.SamAccountName)"
        Write-Log -Message "Display Name: $($ADUser.DisplayName)"
        Write-Log -Message "Job Title: $($ADUser.title)"
        Write-Log -Message "Department: $($ADUser.department)"
        Write-Log -Message "Business Unit: $($ADUser.extensionAttribute6)"
        Write-Log -Message "Division: $($ADUser.company)"
        Write-Log -Message "Manager: $($ADUser.Manager -replace'^CN=|,.*$')"
        Write-Log -Message "Mobile Number: $($ADUser.Mobile)"
        Write-Log -Message "eMail Address: $($ADUser.mail)"
    } else {
        Write-Log -Message "Status: Not connected to Active Directory or user not found."
    }
    
    Write-Log -Message "--- Check Complete ---"

} catch {
    Write-Log -Message "An unhandled error occurred during the user info check."
    Write-Log -Message "Exception: $($_.Exception.Message)"
}