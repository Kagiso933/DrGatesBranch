# This script checks Zscaler connectivity.
# It is called by the C# host and writes output for the GUI.

function Write-Log {
    param(
        [string]$Message
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Output "[$timestamp] $Message"
}

try {
    Write-Log -Message "--- Zscaler Connectivity Status ---"
    
    # Check if Internet is connected
    $InternetOn = $null
    $ZIAOn = $null
    $ZPAOn = $null
    $NetworkConnection = Get-WmiObject win32_networkadapter | Where-Object {($_.netconnectionstatus -eq "2") -and ($_.name -notlike "*Virtual*" -and $_.name -notlike "*Fortinet*" -and $_.name -notlike "*Cisco*" -and $_.name -notlike "*PPPoP*")}
    
    if ($NetworkConnection) {
        try {
            $zscaler = Invoke-RestMethod -Uri ('https://ipinfo.io/') -TimeoutSec 5
        } catch {
            Write-Log -Message "Internet Connected: NO - Test failed."
        }
    } else {
        Write-Log -Message "Internet Connected: NO - No network connection."
    }

    if ($zscaler) {
        Write-Log -Message "Internet Connected: YES"
        # Check ZIA status
        if ($zscaler.org -match "Zscaler|CAPITEC") {
            Write-Log -Message "Internet Security (ZIA): ON"
        } else {
            Write-Log -Message "Internet Security (ZIA): OFF"
        }
    }
    
    # Check ZPA status
    try {
        $ZPAState = (Get-ItemProperty -Path HKCU:\Software\Zscaler\App -Name "ZPA_State" -ErrorAction SilentlyContinue).ZPA_State
        if ($ZPAState -eq "TUNNEL_FORWARDING") {
            Write-Log -Message "Private Access (ZPA): ON"
        } else {
            Write-Log -Message "Private Access (ZPA): OFF"
        }
    } catch {
        Write-Log -Message "Could not retrieve ZPA status from registry."
    }

    Write-Log -Message "--- Check Complete ---"

} catch {
    Write-Log -Message "An unhandled error occurred during the Zscaler check."
    Write-Log -Message "Exception: $($_.Exception.Message)"
}