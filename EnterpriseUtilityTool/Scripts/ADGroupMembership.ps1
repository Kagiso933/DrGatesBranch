Write-Output "Running AD Group Membership Check..."
try {
    # Get the user's logon name and domain
    $UserPrincipalName = $(whoami -upn)
    $SearchRoot = $env:USERDNSDOMAIN

    # Create a DirectorySearcher object to query Active Directory
    $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
    $searcher.Filter = "(&(userprincipalname=$UserPrincipalName))"
    $searcher.SearchRoot = "LDAP://$SearchRoot"
    
    # Find the user and get their directory entry
    $ADUserPath = $searcher.FindOne()
    
    # Check if the search returned a result
    if ($ADUserPath -eq $null) {
        Write-Output "ERROR: Could not find user account '$UserPrincipalName' in Active Directory."
        Write-Output "Ensure the PC is connected to the domain."
        return
    }

    $ADUser = $ADUserPath.GetDirectoryEntry()
    
    # Extract and clean user's group memberships
    Write-Output "--- User Group Membership ---"
    $UserGroups = $ADUser.memberof
    foreach ($group in $UserGroups) {
        Write-Output ($group -replace '^CN=|,.*$')
    }

    # Now get the Computer's group membership
    $ComputerName = $env:COMPUTERNAME
    $computerSearcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
    $computerSearcher.Filter = "(&(objectClass=computer)(name=$ComputerName))"
    $computerSearcher.SearchRoot = "LDAP://$SearchRoot"
    
    # Find the computer and get its directory entry
    $ADComputerPath = $computerSearcher.FindOne()

    # Check if the computer search returned a result
    #if ($ADComputerPath -eq $null) {
    #    Write-Output "`nERROR: Could not find computer account '$ComputerName' in Active Directory."
    #    Write-Output "Ensure the PC is connected to the domain."
    #   return
    #}

    #$ADComputer = $ADComputerPath.GetDirectoryEntry()

    # Extract and clean computer's group memberships
    #Write-Output "`n--- Computer Group Membership ---"
    # $ComputerGroups = $ADComputer.memberof
    #foreach ($group in $ComputerGroups) {
    #    Write-Output ($group -replace '^CN=|,.*$')
    #}

} catch {
    Write-Output "ERROR: An unhandled error occurred while retrieving Active Directory information."
    Write-Output "Ensure the PC is connected to the domain."
    Write-Output "Exception: $($_.Exception.Message)"
}