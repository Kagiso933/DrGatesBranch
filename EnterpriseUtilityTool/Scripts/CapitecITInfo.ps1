#=====================================================================================================
#
# NAME: 	CapitecITInfo.ps1
# AUTHOR: 	Nicol Hanekom
#
# Change Log:
#	22/06/2023 	Nicol Hanekom		Initial version for general release
#   26/10/2023  Nicol Hanekom       Updated to cater for ZIA onprem proxy
#   12/06/2023  Nicol Hanekom       Updated account lockout detection and zscaler status reporting
#
#======================================================================================================

$iconsource = "C:\Program Files\CapitecITInfo\"

$logo = $iconsource + "logo.png"
$loading = $iconsource + "loading.gif"
$icon_Computerlarge = $iconsource + "computer_large.png"
$icon_Computersmall = $iconsource + "computer_small.png"
$icon_userlarge = $iconsource + "user_large.png"
$icon_usersmall = $iconsource + "user_small.png"
$icon_apps = $iconsource + "apps.png"
$icon_ad = $iconsource + "ad.png"
$icon_mappings = $iconsource + "mappings.png"
$icon_services = $iconsource + "services.png"
$icon_health = $iconsource + "health.png"
$icon_sync = $iconsource + "sync.png"
$icon_wifi = $iconsource + "wifi.png"
$icon_ethernet = $iconsource + "ethernet.png"
$icon_cellular = $iconsource + "cellular.png"
$icon_nonetwork = $iconsource + "nonetwork.png"
$icon_connection = $iconsource + "connection.png"






# Create Loading screen...........................................

$html = ""

# Create HTML report
$html = @"

<!DOCTYPE html>
<html>

<head>
<style>
* {box-sizing: border-box}
body {font-family: "Segoe UI", Segoe UI;}

/* Style the tab */
.Loading {
  font: 16px Segoe UI, Segoe UI;
}

</style>
</head>
<body bgcolor="#F3F3F3" >
    <table class="Loading"  border="0" style="width:100%">
        <tr>
            <br><br><br>
            <td style="text-align: center; vertical-align: middle;">
			    <img src="$logo">
                <br><br><br>
			</td>
        </tr>
        <tr>
            <br><br><br><br><br><br><br><br><br><br><br>
            <td style="text-align: center; vertical-align: middle;">
			    <img src="$loading">
                <br><br><br>
			</td>
        </tr>
        <tr>
            <td style="text-align: center; vertical-align: middle;">
			    IT Info loading...
                <br><br><br>
			</td>
        </tr>
    </table>   
</body>
</html> 

"@

$ITInfoFile = $env:Temp + "\CapitecITInfo.html"
$html | Out-File -FilePath $ITInfoFile
$arguments = "--new-window --force-app-mode " + $ITInfoFile
$AskITProcess = Start-Process -FilePath msedge -ArgumentList $arguments









#Get Network info AND Check for Internet and Zscaler connectivity

$InternetOn = $null
$ZIAOn = $null
$ZPAOn = $null
$html_network = $null
$html_Internet = $null 
$html_ZIA = $null 
$html_ZPA = $null 
$zscaler = $null
$html_ZScaler = $null
$SSIDName = $null
$AccountLocked = $null


$NetworkConnection = get-wmiobject win32_networkadapter | Where-Object {($_.netconnectionstatus -eq "2") -and ($_.name -notlike "*Virtual*" -and $_.name -notlike "*Fortinet*" -and $_.name -notlike "*Cisco*" -and $_.name -notlike "*PPPoP*")} | select netconnectionid, name, InterfaceIndex, netconnectionstatus, AdapterType

$IPAddress = get-wmiobject Win32_NetworkAdapterConfiguration | Where-Object {($_.IPEnabled -eq 'TRUE')}

Switch -wildcard ($NetworkConnection.netconnectionid){
    'Wi-Fi' {
        #Get Wifi SSID
        $SSIDName = $null
        $ConnectedNetwork = netsh wlan show interfaces | select-string ' SSID' | ConvertFrom-String -Delimiter ": "
        foreach($arg in $ConnectedNetwork){
            $SSIDName = $arg.p2
        }
        $html_NetworkConnection = "<td valign=middle style='width:0%'><img src='$icon_wifi' class='iconpadding'></td><td valign=middle style='width:20%'><h2>Wi-Fi</h2><h3>($SSIDName)</h3></td>"
    }

    '*Ethernet*' {
        $SSIDName = "capitecbank.fin.sky"
        $html_NetworkConnection = "<td valign=middle style='width:0%'><img src='$icon_ethernet' class='iconpadding'></td><td valign=middle style='width:20%'><h2>Ethernet</h2><h3>($SSIDName)</h3></td>"
    }

    'Cellular' {
        $html_NetworkConnection = "<td valign=middle style='width:0%'><img src='$icon_cellular' class='iconpadding'></td><td valign=middle style='width:20%'><h2>Cellular</h2></td>"
    }

    default {
        $SSIDName = "No Network detected!"
        $html_NetworkConnection = "<td valign=middle style='width:0%'><img src='$icon_nonetwork' class='iconpadding'></td><td valign=middle style='width:20%'><h3><span style='color:Red'>No Network detected!</span></h3>"

        $html_ZScaler = "<td valign=middle style='width:0%'><img src='$icon_connection' class='iconpadding'></td><td valign=middle style='width:20%'><h3>Internet Connected: <span style='color:Green'></span></h3>"
        $html_ZScaler += "<H3>Internet Security: <span style='color:Green'></span></h3>"
        $html_ZScaler += "<H3>Private Access: <span style='color:Green'></span></h3></td>"
    }

}



# Check if Internet Connected
If($NetworkConnection){
    $html_network = "$($NetworkConnection.netconnectionid) ($($IPAddress.IPAddress[0]))"
    $zscaler = Invoke-RestMethod -Uri ('https://ipinfo.io/')
    IF($zscaler){
        $InternetOn = "YES"        
        $html_Internet = "<span style='color:green'>YES</span>"
    }
    else{
        $html_Internet = "<span style='color:red'>NO - Check your internet connection!</span>"
    }
}


# Check if ZIA is on
If($NetworkConnection -and $InternetOn){
    Switch -wildcard ($zscaler.org){
        '*Zscaler*'{
                $html_ZIA = "<span style='color:green'>ON (Cloud Proxy)</span>"
                $ZIAOn = $true
            }
        '*CAPITEC*'{
                $html_ZIA = "<span style='color:green'>ON (On-Prem Proxy)</span>"
                $ZIAOn = $true
            }
        default {
                $html_ZIA = "<span style='color:red'>OFF - Switch on Internet Security, restart Zscaler service or restart device</span>"
            }
    }
}


# Check if ZPA is on
If($NetworkConnection -and $InternetOn){
    If ((Get-ItemProperty -Path HKCU:\Software\Zscaler\App -Name "ZPA_State").ZPA_State -eq "TUNNEL_FORWARDING"){
        $html_ZPA = "<span style='color:green'>ON</span>"
        $ZPAOn = $true
    }
    else{
        $html_ZPA = "<span style='color:red'>OFF - Switch on Private Access, restart Zscaler service or restart device</span>"
        $ZPAOn = $false
    }
}


#Check connection to Active Directory. This indicates if ZPA is on and if the user account may be locked
$DCHostname = $null
If($NetworkConnection -and $InternetOn){

    try{
        $searchRoot = $env:USERDNSDOMAIN
        $UserPrincipalName = $(whoami -upn)
	    $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher
	    $searcher.Filter = "(&(userprincipalname=$UserPrincipalName))"
	    $searcher.SearchRoot = "LDAP://$searchRoot"
        $ADUserPath = $Searcher.FindOne()
    }
    catch{
        $catcherror = $_
    }

    #Cannot contact AD
    if($catcherror -match "The server is not operational"){
        $html_ZPA = "<span style='color:red'>OFF - Switch on Private Access, restart Zscaler service or restart device</span>"
        $ZPAOn = $false
    }

    #Account is locked
    if($catcherror -match "The user name or password is incorrect"){        
        $html_ADLocked = "<h2><span style='color:red'>Account Locked out!</span></h2><h3><span style='color:red'>Click <a href='https://passwordreset.microsoftonline.com/'>here</a> to unlock</span></h3>"
        $html_AccountStatus = "<div><span>Account Status: </span><span style='color:red'>Account Locked out! ($Lockouttime). Visit <a href='https://passwordreset.microsoftonline.com/'>https://passwordreset.microsoftonline.com</a> to unlock</span></div>"
            
        $html_ZPA = "<span style='color:green'>ON</span>"

        $ZPAOn = $true
        $AccountLocked = $true
    }
}


#Build the Zscaler connectivity html table
IF($InternetOn){ 
    $html_ZScaler = "<td valign=middle style='width:0%'><img src='$icon_connection' class='iconpadding'></td><td valign=middle style='width:20%'><h3>Internet Connected: <span style='color:Green'>YES</span></h3>"
}
else{
    $html_ZScaler = "<td valign=middle style='width:0%'><img src='$icon_connection' class='iconpadding'></td><td valign=middle style='width:20%'><h3>Internet Connected: <span style='color:red'>NO</span></h3>"
}
IF($ZIAOn){ 
    $html_ZScaler += "<H3>Internet Security: <span style='color:Green'>ON</span></h3>"
}
else{
    $html_ZScaler += "<H3>Internet Security: <span style='color:red'>OFF</span></h3>"
}
IF($ZPAOn){ 
    $html_ZScaler += "<H3>Private Access: <span style='color:Green'>ON</span></h3></td>"
}
else{
    $html_ZScaler += "<H3>Private Access: <span style='color:Red'>OFF</span></h3></td>"
}


# Get User Info
If($NetworkConnection -and $InternetOn -and ($ZPAOn -or $ADUserPath)){
    
    If($ADUserPath){
    
        $ADUser = $ADUserPath.GetDirectoryEntry()
        $Username = $ADUser.SamAccountName
        $DisplayName = $ADUser.DisplayName
        $FirstName = $ADUser.givenName
        $LastName = $ADUser.sn
        $UPN = $ADUser.userPrincipalName
        $Manager = $aduser.Manager -replace '^CN=|,.*$'
        $DirectReports = $aduser.directReports
        $DirectReports = $DirectReports | where{($_ -like "*OU=Campus*") -or ($_ -like "*OU=NonBranches*")}
        $DirectReports = $DirectReports -replace '^CN=|,.*$'
		$ProxyAddresses = $null
		$ProxyAddresses = $ADUser.proxyAddresses
		$ProxyAddresses = $ProxyAddresses | ?{$_ -ne $('SMTP:'+$mail)}
		$ProxyAddresses = $ProxyAddresses | ?{$_ -like $('SMTP*')}
		$ProxyAddresses = $ProxyAddresses | ?{$_ -ne $('SMTP:'+$mail)}
		$ProxyAddresses = foreach($obj in $ProxyAddresses){ $obj.replace('smtp:','')}
		$ProxyAddresses = foreach($obj in $ProxyAddresses){ $obj.replace('SMTP:','')}
        $DisplayName = $DisplayName.ToString().split("(")[0]
        $JobTitle = $ADUser.title
        $Department = $ADUser.department
        $Division = $ADUser.company
        $BusinessUnit = $ADUser.extensionAttribute6
        $TelePhoneNumber = $ADUser.TelephoneNumber
        $MobilePhoneNumber = $ADUser.Mobile
        $mail = $ADUser.mail
        $mailNickname = $ADUser.mailNickname
        $Office = $ADUser.physicalDeliveryOfficeName
        $Description = $ADUser.Description
        $distinguishedName = $ADUser.distinguishedName

        $pwdLastSet = [datetime]::fromfiletime(($Searcher.findone().properties.pwdlastset)[0])
        $pwdLastSet = $pwdLastSet.ToString("dd/MM/yyyy HH:mm:ss")


        $dn = [ADSI]"LDAP://$distinguishedName"
        $Lockouttime = $null
        $Lockouttime = [datetime]::fromfiletime($dn.ConvertLargeIntegerToInt64($dn.lockoutTime[0]))
        $Lockouttime = [datetime]$Lockouttime.ToString("dd/MM/yyyy HH:mm:ss")
        If ($AccountLocked -eq $false -or $Lockouttime.Year -eq '1601' -or $Lockouttime -eq $null){
            $html_ADLocked = "<h2>$DisplayName</h2><h3>$upn</h3><h3>$username</h3>"
            $html_AccountStatus = "<div><span>Account Status: </span><span style='color:green'>Unlocked</span></div>"
        }else{
            $html_ADLocked = "<h2>$DisplayName</h2><h3>$upn</h3><h3>$username <span style='color:red'>(Account Locked out!)</span></h3>"
            $html_AccountStatus = "<div><span>Account Status: </span><span style='color:red'>Account Locked out! ($Lockouttime). Visit <a href='https://passwordreset.microsoftonline.com/'>https://passwordreset.microsoftonline.com</a> to unlock</span></div>"
        }

        $accountExpires = $null
        $accountExpires = [datetime]::fromfiletime($dn.ConvertLargeIntegerToInt64($dn.accountExpires[0]))
        $accountExpires = [datetime]$accountExpires.ToString("dd/MM/yyyy")
        If ($accountExpires.Year -eq '1601' -or $accountExpires -eq $null){
            $accountExpires = "Never"
        }
    
        
        


        #Get Active Directory groups
        #====================================================================================================================================
        $ADUserGroups = @()
        $UserGroups = $ADUser.memberof
        foreach($group in $UserGroups){
            If ($($group -replace '^CN=|,.*$') -notlike 'Group_*'){
                $ADUserGroups += $group -replace '^CN=|,.*$'
            }
        }
        $ADUserGroups = $ADUserGroups | sort-object


    }
}
else{
    $html_ADLocked = "<h3><span style='color:red'>ERROR: Could not read User Info</span></h3>"
}



#Get Computer Info
#====================================================================================================================================

$ComputerName = $env:COMPUTERNAME

$compinfo = get-computerinfo 

$DiskInfo = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3"
$DiskSize = "$([math]::ceiling($DiskInfo.Size / 1024 / 1024 /1024)) GB"
$DiskFree = "$([math]::ceiling($DiskInfo.FreeSpace / 1024 / 1024 /1024)) GB"

# Get Hotfixes
$InstalledHotfixes = @()
foreach($fix in $($compinfo.OsHotFixes)) {$Hotfix = New-Object PSObject
    $Hotfix | Add-Member -type NoteProperty -Name 'HotFixID' -Value $fix.HotFixID
    $Hotfix | Add-Member -type NoteProperty -Name 'Description' -Value $fix.Description
    $Hotfix | Add-Member -type NoteProperty -Name 'InstalledOn' -Value $fix.InstalledOn
    $InstalledHotfixes += $Hotfix
}
$InstalledHotfixes = $InstalledHotfixes | Sort-Object -Property InstalledOn -Descending






# Get Drive mappings
$DriveMappings = Get-PSDrive | Where-Object { $_.Provider.Name -eq "FileSystem" -and $_.Root -notin @("$env:SystemDrive\", "D:\") } | Select-Object Name,DisplayRoot




# Get Printer mappings
$PrinterMappings = get-printer




#Get Apps
#====================================================================================================================================

#Get Computer Apps
$InstalledComputerApps = Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
#foreach($obj in $InstalledSoftware){write-host $obj.GetValue('DisplayName') -NoNewline; write-host " - " -NoNewline; write-host $obj.GetValue('DisplayVersion') -NoNewline; write-host " - " -NoNewline; write-host $obj.GetValue('InstallDate')}

#User apps
$InstalledUserApps = Get-ChildItem "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
#foreach($obj in $InstalledSoftware){write-host $obj.GetValue('DisplayName') -NoNewline; write-host " - " -NoNewline; write-host $obj.GetValue('DisplayVersion') -NoNewline; write-host " - " -NoNewline; write-host $obj.GetValue('InstallDate')}

$InstalledApps = @()
foreach($obj in $InstalledComputerApps) {$App = New-Object PSObject
    $App | Add-Member -type NoteProperty -Name 'DisplayName' -Value $obj.GetValue('DisplayName')
    $App | Add-Member -type NoteProperty -Name 'DisplayVersion' -Value $obj.GetValue('DisplayVersion')
    $App | Add-Member -type NoteProperty -Name 'InstallDate' -Value $obj.GetValue('InstallDate')
    $InstalledApps += $App
}

foreach($obj in $InstalledUserApps) {$App = New-Object PSObject
    $App | Add-Member -type NoteProperty -Name 'DisplayName' -Value $obj.GetValue('DisplayName')
    $App | Add-Member -type NoteProperty -Name 'DisplayVersion' -Value $obj.GetValue('DisplayVersion')
    $App | Add-Member -type NoteProperty -Name 'InstallDate' -Value $obj.GetValue('InstallDate')
    $InstalledApps += $App
}
$InstalledApps = $InstalledApps | Sort-Object -Property DisplayName





# Get Windows Services
$WindowsServices = Get-Service


#Intune
$AutopilotCache = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Provisioning\AutopilotPolicyCache" -Name "PolicyJsonCache"
$AutopilotCache = $AutopilotCache | ConvertFrom-Json
$APProfileName = $AutopilotCache.DeploymentProfileName




$html = ""

# Create HTML report
$html = @"

<!DOCTYPE html>
<html>

<head>

<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
* {box-sizing: border-box}
body {font-family: "Segoe UI", Segoe UI;}

/* Style the tab */
.tab {
  float: left;
  border: 2px solid #F3F3F3;
  border-radius: 10px;
  background-color: #F3F3F3;
  width: 30%;
  height: 300px;
  font: 14px Segoe UI, Segoe UI;
}

/* Style the space */
.space {
  float: left;
  border: 2px solid #F3F3F3;
  border-radius: 10px;
  background-color: #F3F3F3;
  width: 2%;
  height: 300px;
}

/* Style the buttons inside the tab */
.tab button {
  display: block;
  background-color: inherit;
  border: 2px solid #F3F3F3;
  border-radius: 10px;
  color: black;
  padding: 22px 16px;
  width: 100%;
  outline: none;
  text-align: left;
  vertical-align: middle;
  cursor: pointer;
  transition: 0.3s;
  font: 14px Segoe UI, Segoe UI;
    display: flex;
    align-items:center;
}


/* Change background color of buttons on hover */
.tab button:hover {
  background-color: #EAEAEA;
}

/* Create an active/current "tab button" class */
.tab button.active {
  background-color: #EAEAEA;
}

/* Style the tab content */
.tabcontent {
  float: left;
  padding: 0px 12px;
  border: 2px solid #EAEAEA;
  border-radius: 10px;
  width: 68%;
  height: 100%;
  background-color: #FBFBFB;
  text-align: left;
  font: 14px Segoe UI, Segoe UI;
  padding: 10px 10px 10px 10px;
}

.iconpadding{
padding: 0px 20px 0px 0px;
}

/* Style the table */
.tablemain {
  border: 0px solid #FFFFFF;
  padding: 20px 0px 0px 0px;
  font: 14px Segoe UI, Segoe UI;
}

/* Style the table */
.tabletop {
  border: 0px solid #FFFFFF;
  padding: 0px 70px 0px 70px;
  font: 12px Segoe UI, Segoe UI;
}

.Apps-list {
    margin-top: 40px;
  font: 14px Segoe UI, Segoe UI;
}

h2 {margin:0px 0px 0px 0px}
h3 {margin:0px 0px 0px 0px}

</style>
</head>
<body bgcolor="#F3F3F3" >
<table class="tablemain" style="width:100%">
	<div style="position:absolute;top:0px">
		<table class="tabletop" style="width:100%">
				<td valign=middle style="width:0%">
					<img src="$icon_Computerlarge" class="iconpadding">
				</td>
				<td valign=middle style="width:20%">
					<h2>$ComputerName</h2>
				</td>
				<td valign=middle style="width:0%">
					<img src="$icon_userlarge" class="iconpadding">
				</td>
				<td valign=middle style="width:20%">

                $html_ADLocked

				</td>
                $html_NetworkConnection
                $html_ZScaler

				<td valign=middle align=right style="width:20%">
					<img src="$logo">
				</td>
		</table>
	
		<table style="width:100%" cellpadding="50">
			<td align=middle>

				<div class="tab">
					<button class="tablinks" onclick="openGroup(event, 'ComputerInfo')" id="defaultOpen"><img src="$icon_Computersmall" class="iconpadding">Computer Info</button>
					<button class="tablinks" onclick="openGroup(event, 'UserInfo')"><img src="$icon_usersmall" class="iconpadding">User Info</button>
					<button class="tablinks" onclick="openGroup(event, 'Apps')"><img src="$icon_apps" class="iconpadding">Apps</button>
					<button class="tablinks" onclick="openGroup(event, 'ActiveDirectory')"><img src="$icon_ad" class="iconpadding">Active Directory</button>
					<button class="tablinks" onclick="openGroup(event, 'DrivesPrinters')"><img src="$icon_mappings" class="iconpadding">Drive & Printer Mappings</button>
					<button class="tablinks" onclick="openGroup(event, 'WindowsServices')"><img src="$icon_services" class="iconpadding">Windows Services</button>
				</div>

				<div class="space">

				</div>




				<div id="ComputerInfo" class="tabcontent">
				  <h3>Computer Info</h3><br><br>

				  <div><b>Connectivity:</b></div>
				  <div>Connection: $html_network</div>
				  <div>Network: $SSIDName</div>
				  <div>Internet Connected: $html_Internet</div>
				  <div>Zscaler Internet Security: $html_ZIA</div>
				  <div>ZScaler Private Access: $html_ZPA</div>

                  <br>  

				  <div><b>Operating System:</b></div>
				  <div>Computer Name: $($compinfo.CsName)</div>
				  <div>Version: $($compinfo.OSName) $($compinfo.OSDisplayVersion) ($($compinfo.OsVersion))</div>
				  <div>Install Date: $($($compinfo.OsInstallDate).ToString("dd/MM/yyyy HH:mm:ss"))</div>
				  <div>Last Boot Time: $($($compinfo.OsLastBootUpTime).ToString("dd/MM/yyyy HH:mm:ss"))</div>
				  <div>Uptime: $($($compinfo.OsUptime).days) Days $($($compinfo.OsUptime).Hours) Hours $($($compinfo.OsUptime).Minutes) Minutes</div>
				  <div>Timezone: $($compinfo.TimeZone)</div>
				  <div>Encryption: $($compinfo.OsEncryptionLevel) bit</div>
                    
                  <br>

				  <div><b>Hardware:</b></div>
				  <div>Make: $($compinfo.CsManufacturer)</div>
				  <div>Model: $($compinfo.CsModel)</div>
				  <div>Serial #: $($compinfo.BiosSeralNumber)</div>
				  <div>Processor: $($($compinfo.CsProcessors).Name)</div>
				  <div>Memory: $([math]::ceiling($compinfo.OsTotalVisibleMemorySize / 1024 / 1024)) GB</div>
				  <div>Disk: $DiskFree free of $DiskSize</div>
				  <pdivNetwork Adapters: $($compinfo.CsNetworkAdapters)</div>
				  <div>BIOS Version: $($compinfo.BiosSMBIOSBIOSVersion)</div>
				  <div>BIOS Release Date: $($($compinfo.BiosReleaseDate).ToString("dd/MM/yyyy HH:mm:ss"))</div>

                 

				  <div class="Apps-list"><b>Windows Updates:</b></div>
                        <table>
                            <thead>
                                <tr>
                                    <th>HotFixID</th>
                                    <th>Description</th>
                                    <th>Install Date</th>
                                </tr>
                            </thead>
                            <tbody>
"@
                                foreach($fix in $($InstalledHotfixes)) {
                                    $html += "<tr><td>$($fix.HotFixID)&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp</td><td>$($fix.Description)&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp</td><td>$($fix.InstalledOn)</td></tr>"
                                }

                                $html += @"
                            </tbody>
                        </table>


				</div>




				<div id="UserInfo" class="tabcontent">
				  <h3>User Info</h3><br><br>

				  <div><b>Account Details:</b></div>
				  <div>User Name: $Username</div>
				  <div>Logon Name: $UPN</div>
				  $($html_AccountStatus)
				  <div>Account Expires: $accountExpires</div>
				  <div>Password Last Set: $pwdLastSet</div>
				  <div>Description: $Description</div>
				  <div>DistinguishedName: $distinguishedName</div>

                    <br>

				  <div><b>Personal Details:</b></div>
				  <div>Display Name: $DisplayName</div>
				  <div>First Name: $FirstNAme</div>
				  <div>Last Name: $LastName</div>

                    <br>

				  <div><b>Contact Details:</b></div>
				  <div>Telephone Number: $TelePhoneNumber</div>
				  <div>Mobile Number: $MobilePhoneNumber</div>
				  <div>Office: $office</div>
				  <div>eMail Address: $mail</div>
				  <div>eMail Nickname: $mailNickname</div>
				  <div>eMail Aliases:</div>


"@
                                foreach($obj in $ProxyAddresses) {
                                       $html += "<div>$($obj)</div>"
                                }

                                $html += @"


                    <br>
				  <div><b>Org Details:</b></div>
				  <div>Job Title: $JobTitle</div>
				  <div>Department: $Department</div>
				  <div>Division: $Division</div>
				  <div>Business Unit: $BusinessUnit</div>
				  <div>Manager: $Manager</div>
                  <div>Direct Reports:</div>


"@
                                foreach($obj in $DirectReports) {
                                       $html += "<div>$($obj)</div>"
                                }

                                $html += @"
				  

                  <br>  
				</div>



				<div id="Apps" class="tabcontent">
				  <h3>Apps</h3>

                    <div class="Apps-list">
                        <table>
                            <thead>
                                <tr>
                                    <th>Name</th>
                                    <th>Version</th>
                                    <th>Install Date</th>
                                </tr>
                            </thead>
                            <tbody>
"@
                                foreach($obj in $InstalledApps) {
                                    If($($obj.DisplayName).Length -gt 1){
                                       $html += "<tr><td>$($obj.DisplayName)&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp</td><td>$($obj.DisplayVersion)&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp</td><td>$($obj.InstallDate)</td></tr>"
                                    }
                                }

                                $html += @"
                            </tbody>
                        </table>
    				</div>
                </div>



				<div id="ActiveDirectory" class="tabcontent">
				  <h3>Active Directory</h3>

                    <div class="Apps-list">
                        <table>
                            <thead>
                                <tr>
                                    <th>User Group Membership</th>
                                </tr>
                            </thead>
                            <tbody>
"@
                                foreach($obj in $ADUserGroups) {
                                    $html += "<tr><td>$($obj)</td></tr>"
                                }

                                $html += @"
                            </tbody>
                        </table>
    				</div>
                </div>



				<div id="DrivesPrinters" class="tabcontent">
				  <h3>Drive Mappings</h3>

                    <div class="Apps-list">
                        <table>
                            <thead>
                                <tr>
                                    <th>Letter</th>
                                    <th>Drive</th>
                                </tr>
                            </thead>
                            <tbody>
"@
                                foreach($obj in $DriveMappings) {
                                    $html += "<tr><td>$($obj.Name)&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp</td><td>$($obj.DisplayRoot)</td></tr>"
                                }

                                $html += @"
                            </tbody>
                        </table>
    				</div><br><br>

				  <h3>Printer Mappings</h3>

                    <div class="Apps-list">
                        <table>
                            <thead>
                                <tr>
                                    <th>Name</th>
                                    <th>Model</th>
                                </tr>
                            </thead>
                            <tbody>
"@
                                foreach($obj in $PrinterMappings) {
                                    $html += "<tr><td>$($obj.Name)&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp</td><td>$($obj.DriverName)</td></tr>"
                                }

                                $html += @"
                            </tbody>
                        </table>
    				</div>
                </div>




				<div id="WindowsServices" class="tabcontent">
				  <h3>Windows Services</h3>

                    <div class="Apps-list">
                        <table>
                            <thead>
                                <tr>
                                    <th>Status</th>
                                    <th>Name</th>
                                    <th>DisplayName</th>
                                </tr>
                            </thead>
                            <tbody>
"@
                                foreach($obj in $WindowsServices) {
                                    $html += "<tr><td>$($obj.Status)&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp</td><td>$($obj.Name)&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp</td><td>$($obj.DisplayName)</td></tr>"
                                }

                                $html += @"
                            </tbody>
                        </table>
    				</div>
                </div>



				<div id="365ServiceHealth" class="tabcontent">
                    <object type="text/html" data="https://portal.office.com/servicestatus" width="100%" height="1000px" style="overflow:auto;border:0px ridge blue"></object>
                </div>


    	    </td>
		</table>
	</div>
</table>

<script>
function openGroup(evt, GroupName) {
  var i, tabcontent, tablinks;
  tabcontent = document.getElementsByClassName("tabcontent");
  for (i = 0; i < tabcontent.length; i++) {
    tabcontent[i].style.display = "none";
  }
  tablinks = document.getElementsByClassName("tablinks");
  for (i = 0; i < tablinks.length; i++) {
    tablinks[i].className = tablinks[i].className.replace(" active", "");
  }
  document.getElementById(GroupName).style.display = "block";
  evt.currentTarget.className += " active";
}

// Get the element with id="defaultOpen" and click on it
document.getElementById("defaultOpen").click();


</script>
   
</body>
</html> 

"@


$html | Out-File -FilePath $ITInfoFile
$wshell=New-Object -ComObject wscript.shell;
$wshell.SendKeys('{F5}')