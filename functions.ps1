import-module activedirectory

Write-host "oops, this should be in dev"

Write-host "ping-computer:" -nonewline; write-host " ping specified computer and email when status changes" -foregroundcolor darkgray
Write-host "get-computerforuser:" -nonewline; write-host " finds user and gets their computer from managed objects" -foregroundcolor darkgray
Write-host "query-computer:" -nonewline; write-host " returns basic computer object info" -foregroundcolor darkgray
Write-host "get-servicetag:" -nonewline; write-host " attemps to return service tag for supplied computername" -foregroundcolor darkgray
Write-host "get-SQLSvrVer:" -nonewline; write-host " attemps to retrive SQL version from server, run as admin" -foregroundcolor darkgray
Write-host "get-DellWarranty:" -nonewline; write-host " gets dell warranty from service tag. function accepts pipeline input" -foregroundcolor darkgray
Write-host "set-FileTimeStamps:" -nonewline; write-host " sets file timestamp metadata.  ex. Set-FileTimeStamps -path c:\folder -date 7/1/11" -foregroundcolor darkgray
Write-host "get-mappeddrives:" -nonewline; write-host " gets mapped networkdrives for specified computer, need to run as p-account" -foregroundcolor darkgray
Write-host "ping-list:" -nonewline; write-host "  pings list of computers, need to specify path to text file" -foregroundcolor darkgray




Write-host ""
Write-host ""

function get-computerforuser { 

[CmdletBinding()]
param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string[]]$users
)


    $users = @() + $users
    foreach ($user in $users) {
        $search = "*$user*".Replace(' ','*').Replace('.','*')
        $adusers = $null
        $adusers = Get-ADUser -LDAPFilter "(samAccountName=$user)" -Properties managedObjects
        if (!$adusers) {
            $adusers = get-aduser -filter {name -like $search -or samAccountName -like $search } -Properties managedObjects
        }

        $adusers = $() + $adusers

        foreach ($aduser in $adusers) {
            #$return = @()
            $aduser.managedObjects | Get-ADObject -Properties memberof | where {$_.ObjectClass -eq 'computer'} | foreach {New-Object –TypeName PSObject –Prop @{'user'=$aduser.name;'computer'=$_.name;'samaccountname'=$aduser.samaccountname}}
        }
    }
}




function Ping-List{

  Param (

   [parameter(Mandatory=$true,ValueFromPipeline=$true)]

  [string[]]$list

  )


Clear
$PingMachines = Gc $list
$alive = 0
$dead = 0
$allalive = @()
$alldead = @()
ForEach($MachineName In $PingMachines)
{$PingStatus = Gwmi Win32_PingStatus -Filter "Address = '$MachineName'" |
Select-Object StatusCode
If ($PingStatus.StatusCode -eq 0)
{Write-Host $MachineName -Fore "Green"
$alive += 1
$allalive += "$MachineName"
}
Else
{Write-Host $MachineName -Fore "Red"
$dead += 1
$alldead += "$MachineName"
}}

write-host "Alive Hosts: "$alive
write-host "Dead Hosts: "$dead
write-host "Alive"
write-host "-----------"
$allalive
write-host ""
write-host "Dead"
write-host "-----------"
$alldead
}


Function Set-FileTimeStamps

{

 Param (

    [Parameter(mandatory=$true)]

    [string[]]$path,

    [datetime]$date = (Get-Date))

    Get-ChildItem -Path $path |

    ForEach-Object {

     $_.CreationTime = $date

     $_.LastAccessTime = $date

     $_.LastWriteTime = $date }

} #end function Set-FileTimeStamps


function Ping-Computer {

param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string[]]$servername
#[string]$to,
#[string]$subject,
#[string]$body
)

# get input from host

#$smtpTo = read-host "Enter Email Address"
$smtpTo = "matt.kuba@cardno.com"
#$servername = read-host "Enter Computer Name"

# set baseline to determine current status

$baseline = test-connection $servername -count 1 -quiet 

# compare baseline to current status

Do 

{$check = Test-Connection -Computername $servername -count 1 -quiet

# this was needed to slow the output of the the UP result

#if ($check -eq $true)

#    {start-sleep -s 60}   

if ($baseline -eq $true)

    {write-host "$servername is UP" -foregroundcolor "green"
	start-sleep -s 60}
    
   else {write-host "$servername is DOWN" -foregroundcolor "red"
	start-sleep -s 60}

}
	While ($baseline -eq $check)

# this is used in the email to reflect new status of host

if ($baseline -eq $true)

        {$status = "DOWN"}
        
    else {$status = "UP"}

# play the file once

$sound = new-Object System.Media.SoundPlayer;
$sound.SoundLocation="c:\WINDOWS\Media\chimes.wav";
$sound.Play();

# sets var back to $null

$baseline = $null
$check = $null

# send email

$smtpServer = "mail.entrix.com"
$smtpFrom = "IPcheck@entrix.com"
$messageSubject = "$servername is $status"
$messageBody = "The status of $servername has changed.  The system is $status."
$smtp = New-Object Net.Mail.SmtpClient($smtpServer)
$smtp.Send($smtpFrom,$smtpTo,$messagesubject,$messagebody)


}

<#
function get-computerfromlastname {
[CmdletBinding()]
param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string[]]$str

)


#$comps = Read-host 'enter last name'
$out=@()
$comps = '*'+ $str + '*'
$out = get-adcomputer -SearchBase "OU=North,OU=AME,OU=Cardno,DC=Cardno,DC=corp" -filter 'CN -like $comps' -properties CN, Description | select-object CN, Description
$out += get-adcomputer -SearchBase "OU=North,OU=AME,OU=Cardno,DC=Cardno,DC=corp" -filter 'Description -like $comps' -properties CN, Description | select-object CN, Description
$out


}

#>

Function query-computer {
<#
.SYNOPSIS

.DESCRIPTION

.PARAMETER

.EXAMPLE

query-computer computer1,computer2 -cred "domain\username"
This command returns properties for systems named computer1 and computer2 using the supplied credentials for WMI calls.


#>
	[CmdletBinding()]
	param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string[]]$computers,
        [System.Management.Automation.CredentialAttribute()]
        $cred
         )

	BEGIN{}
	PROCESS{

    Foreach ($computer in $computers) {
       
            
        $AD = get-adcomputer "$computer" -Properties *
        $ComputerSystem = Get-WmiObject win32_computersystem -ComputerName $computer -Credential $cred
        $SystemEnclosure = Get-WmiObject win32_systemenclosure -Computername $computer -Credential $cred
        $disks = Get-WmiObject win32_logicaldisk -computername $computer -Credential $cred -Filter {DriveType = 3}
        $diskresults = @()
        $service = New-WebServiceProxy -Uri http://xserv.dell.com/services/assetservice.asmx?WSDL
        $guid = [Guid]::NewGuid()
        $info = $service.GetAssetInformation($guid,'warrantycheck',$systemenclosure.serialnumber)
        


        foreach ($disk in $disks){
               
                   

                $props = @{
       
                ($disk.deviceid + "TotalSpace(GB)") = [math]::truncate($disk.size/1gb);                      
                ($disk.deviceid + "FreeSpace(GB)") = [math]::truncate($disk.freespace/1gb);
                ($disk.deviceid + "FreeSpace%") = "{0,0:P0}" -f(($disk.freespace/1gb) / ($disk.size/1gb));
                            } 

               $diskresults += new-object -TypeName PSobject -Property $props
                                                            
                                }

                $props = [ordered]@{

                    'Server' = $computer;
                    'Memory' = [decimal]::round($computersystem.totalphysicalmemory/1GB);
                    'LogonTimeStamp' =  [DateTime]::FromFileTime($AD.lastLogonTimestamp);
                    'OperatingSystem' = $AD.operatingsystem;
                    'IPv4' = $AD.IPv4Address; 
                    'Domain' = $ComputerSystem.domain;
                    'Manufacturer' = $ComputerSystem.manufacturer;
                    'SerialNumber' = $systemenclosure.serialnumber;

                    'Disks' = $diskresults

                    'Model' = $computersystem.model;
                    'ServiceLevel'=$info[0].Entitlements[0].ServiceLevelDescription.ToString() 
                    'EndDate'=$info[0].Entitlements[0].EndDate.ToShortDateString() 
                    'StartDate'=$info[0].Entitlements[0].StartDate.ToShortDateString() 
                    'DaysLeft'=$info[0].Entitlements[0].DaysLeft 
                    'ServiceTag'=$info[0].AssetHeaderData.ServiceTag 
                    'Type'=$info[0].AssetHeaderData.SystemType 
                    'ShipDate'=$info[0].AssetHeaderData.SystemShipDate.ToShortDateString()

                        }   
           

                new-object -TypeName PSobject -Property $props

                   

            }

            }
	END{}

}


Function get-servicetag {
<#
.SYNOPSIS

.DESCRIPTION

.PARAMETER

.EXAMPLE


#>
	[CmdletBinding()]
	param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string[]]$computers
         )

	BEGIN{}
	PROCESS{
    
    $cred = Get-Credential

    Foreach ($computer in $computers) {
        
       $temp = Get-WmiObject win32_systemenclosure -ComputerName $computer -Credential $cred

       $props = @{
        'Server' = $computer;
        'Manfacture' = $temp.manufacturer;
        'ServiceTag' = $temp.serialnumber;
        }

    new-object -TypeName PSobject -Property $props


                                }

            }
	END{}

}

Function Get-SQLSvrVer {
<#
    .SYNOPSIS
        Checks remote registry for SQL Server Edition and Version.

    .DESCRIPTION
        Checks remote registry for SQL Server Edition and Version.

    .PARAMETER  ComputerName
        The remote computer your boss is asking about.

    .EXAMPLE
        PS C:\> Get-SQLSvrVer -ComputerName mymssqlsvr 

    .EXAMPLE
        PS C:\> $list = cat .\sqlsvrs.txt
        PS C:\> $list | % { Get-SQLSvrVer $_ | select ServerName,Edition }

    .INPUTS
        System.String,System.Int32

    .OUTPUTS
        System.Management.Automation.PSCustomObject

    .NOTES
        Only sissies need notes...

    .LINK
        about_functions_advanced

#>
[CmdletBinding()]
param(
    # a computer name
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $ComputerName
)

# Test to see if the remote is up
if (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet) {
    # create an empty psobject (hashtable)
    $SqlVer = New-Object PSObject
    # add the remote server name to the psobj
    $SqlVer | Add-Member -MemberType NoteProperty -Name ServerName -Value $ComputerName
    # set key path for reg data
    $key = "SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL"
    # i have no idea what this does, honestly, i stole it...
    $type = [Microsoft.Win32.RegistryHive]::LocalMachine
    # set up a .net call, uses the .net thingy above as a reference, could have just put 
    # 'LocalMachine' here instead of the $type var (but this looks fancier :D )
    $regKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($type, $ComputerName)

    # make the call 
    $SqlKey = $regKey.OpenSubKey($key)
        # parse each value in the reg_multi InstalledInstances 
        Foreach($instance in $SqlKey.GetValueNames()){
        $instName = $SqlKey.GetValue("$instance") # read the instance name
        $instKey = $regKey.OpenSubkey("SOFTWARE\Microsoft\Microsoft SQL Server\$instName\Setup") # sub in instance name
        # add stuff to the psobj
        $SqlVer | Add-Member -MemberType NoteProperty -Name Edition -Value $instKey.GetValue("Edition") -Force # read Ed value
        $SqlVer | Add-Member -MemberType NoteProperty -Name Version -Value $instKey.GetValue("Version") -Force # read Ver value
        # return an object, useful for many things
        $SqlVer
    }
} else { Write-Host "Server $ComputerName unavailable..." } # if the connection test fails
}


function Get-DellWarranty { 


[CmdletBinding()]


param(

     [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]

      [string[]]$serviceTags

  
    )
    process {

    foreach ($servicetag in $servicetags){

    #$serviceTags = @() + $serviceTags
    $APIKey = "ea2fbfca0aa64228000000006a426f1d"
    $Url = "https://api.dell.com/support/assetinfo/v4/getassetwarranty"
    $groupSize = 50
    $numGroups = [math]::ceiling($serviceTags.Count / $groupSize)
    
    $group = 1
    foreach ($group in 1..$numGroups) {
        $start = $groupSize*$group - $groupSize
        $end = $groupSize*$group - 1
        $temp = $serviceTags[$start..$end]
        $serials = $temp  -join ','
        $getData = @{apikey=$APIKey;ID = $serials}

        try {
            $warrantyInfo = invoke-webrequest $url -UseBasicParsing -Method get -Body $getData | ConvertFrom-Json
        } catch {
            $warrantyInfo = $null          
            Write-Host "Fatal Warranty lookup failure" $($_.Exception.Message)
           
        }
  
        if ($warrantyInfo) {
            $inventoryItem = $temp[0]      
            foreach ($inventoryItem in $temp) {
                $warranty = $warrantyInfo.AssetWarrantyResponse | where {$_.AssetHeaderData.ServiceTag -eq $inventoryItem}
                if ($warranty -eq $null) {
                    "No result for service tag $($warranty.Serial)"
                } else {                
                    $latestWarranty = $warranty.AssetEntitlementData | sort startdate

                    if ($latestWarranty.GetType().BaseType.name -like 'Array') {
                        $latestWarranty = $latestWarranty[-1]
                    } else {
                        $latestWarranty = $latestWarranty
                    }

                    $fromdate = [DateTime] $warranty.AssetHeaderData.ShipDate
                    $todate = get-date
                    $totalyears = ($todate - $fromdate).totaldays/365

                    New-Object PSObject -Propert @{ 
                        'Serial' = $warranty.AssetHeaderData.ServiceTag;
                        'Vendor' = 'Dell';
                        'WarrantyVendor' = 'Dell';
                        'SLA' = $latestWarranty.ServiceLevelDescription;
                        'Model' = $warranty.AssetHeaderData.MachineDescription;
                        'ShipDate' = get-date -Format d $warranty.AssetHeaderData.ShipDate;
                        'EndDate' = get-date -Format d $latestWarranty.EndDate ; #$dateDellTS = get-date (get-date $dateDell -Format d) -Format yyyy-MM-dd
                        'Age' = [math]::Round($totalyears,2)
                    }
                                                           
                }
            }
        }
    }
}

}}


function Get-MappedDrives{

  Param (

   [parameter(Mandatory=$true,ValueFromPipeline=$true)]

  [string[]]$ComputerName

  )

  #Ping remote machine, continue if available
  if(Test-Connection -ComputerName $ComputerName -Count 1 -Quiet){
    #Get remote explorer session to identify current user
    $explorer = Get-WmiObject -ComputerName $ComputerName -Class win32_process | ?{$_.name -eq "explorer.exe"}
    
    #If a session was returned check HKEY_USERS for Network drives under their SID
    if($explorer){
      $Hive = [long]$HIVE_HKU = 2147483651
      $sid = ($explorer.GetOwnerSid()).sid
      $owner  = $explorer.GetOwner()
      $RegProv = get-WmiObject -List -Namespace "root\default" -ComputerName $ComputerName | Where-Object {$_.Name -eq "StdRegProv"}
      $DriveList = $RegProv.EnumKey($Hive, "$($sid)\Network")
      
      #If the SID network has mapped drives iterate and report on said drives
      if($DriveList.sNames.count -gt 0){
       
         $results = @()

        foreach($drive in $DriveList.sNames){

          $props = @{

	'user' = $owner.user;
	'computer' = $($computername);
    'drive' = $drive;
    'path' = $(($RegProv.GetStringValue($Hive, "$($sid)\Network\$($drive)", "RemotePath")).sValue);


		}
    $obj = New-Object -TypeName PSObject -Property $props
    $results += $obj
        }

$results

      
}}}}



