<#
    .SYNOPSIS 
      This module allows access to Ribbon SBC Edge via PowerShell using REST API's
	 
	.DESCRIPTION
	  This module allows access to Ribbon SBC Edge via PowerShell using REST API's
	  For  the module to run correctly following pre-requisites should be met:
	  1) PowerShell v3.0
	  2) Ribbon SBC Edge on R3.0 or higher
	  3) Create REST logon credentials (http://www.allthingsuc.co.uk/accessing-sonus-ux-with-rest-apis/)
	
	 
	.NOTES
		Name: RibbonUX
		Author: Vikas Jaswal (Modality Systems Ltd)
		
		Version History:
		Version 1.0 - 30/11/13 - Module Created - Vikas Jaswal
		Version 1.1 - 03/12/13 - Added new-ux*, restart-ux*, and get-uxresource cmdlets - Vikas Jaswal
        Version 1.2 - 01/11/18 - Match Ribbon rebranding, Update link to Ribbon Docs - Adrien Plessis
		
		Please use the script at your own risk!
	
	.LINK
		http://www.allthingsuc.co.uk
     
  #>

#Ignore SSL, without this GET commands dont work with UX
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

Function global:connect-uxgateway {
	<#
	.SYNOPSIS      
	 This cmdlet connects to the Ribbon SBC and extracts the session token.
	 
	.DESCRIPTION
	This cmdlet connects to the Ribbon SBC and extracts the session token required for subsequent cmdlets.All other cmdlets will fail if this command is not successfully executed.
	
	.PARAMETER uxhostname
	Enter here the hostname or IP address of the Ribbon SBC
	
	.PARAMETER uxusername
	Enter here the REST Username. This is not the same username you use to login via the GUI
	
	.PARAMETER uxpassword
	Enter here the REST Password. This is not the same username you use to login via the GUI
	
	.EXAMPLE
	connect-uxgateway -uxhostname 1.1.1.1 -uxusername restuser -uxpassword Password01
	
	.EXAMPLE
	connect-uxgateway -uxhostname lyncsbc01.allthingsuc.co.uk -uxusername user1 -uxpassword Password02
	
	#>
	[cmdletbinding()]
	Param(
		[Parameter(Mandatory=$true,Position=0)]
     	[string]$uxhostname,
		[Parameter(Mandatory=$true,Position=1)]
		[string]$uxusername,
		[Parameter(Mandatory=$true,Position=2)]
		[string]$uxpassword
	)
	
	#Force TLS1.2
    	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12		


	#Login to UX
	$args1 = "Username=$uxusername&Password=$uxpassword"
	$url = "https://$uxhostname/rest/login"
	
	Try {
		$uxcommand1output = Invoke-RestMethod -Uri $url -Method Post -Body $args1 -SessionVariable global:sessionvar -ErrorAction Stop
	}
	Catch {
		throw "$uxhostname - Unable to connect to $uxhostname. Verify $uxhostname is accessible on the network. The error message returned is $_"
	}
	
	$global:uxhostname = $uxhostname

	#Check if the Login was successfull.HTTP code 200 is returned if login is successful
	If ( $uxcommand1output | select-string "<http_code>200</http_code>"){
		Write-verbose $uxcommand1output
	}
	Else {
		#Unable to Login
		throw "$uxhostname - Login unsuccessful, logon credentials are incorrect OR you may not be using REST Credentials.`
		For further information check `"http://www.allthingsuc.co.uk/accessing-sonus-ux-with-rest-apis`""
	}
}

#Function to grab UX system information
Function global:get-uxsysteminfo {
	<#
	.SYNOPSIS      
	 This cmdlet collects System information from Ribbon SBC.
	
	.EXAMPLE
	get-uxsysteminfo
	
	#>
	
	[cmdletbinding()]
	Param()
	$args1 = ""
	$url = "https://$uxhostname/rest/system"
	
	Try {
		$uxrawdata = Invoke-RestMethod -Uri $url -Method GET -WebSession $sessionvar -ErrorAction Stop
	}
	
	Catch {
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity)."
	}
	
		#Check if connection was successful.HTTP code 200 is returned
		If ( $uxrawdata | select-string "<http_code>200</http_code>"){
		 
		 	Write-Verbose $uxrawdata
		
			#Sanitise data and return as object
			Try {
				$m = $uxrawdata.IndexOf("<system href=")
				$length = ($uxrawdata.length - $m - 8)
				[xml]$uxdataxml =  $uxrawdata.substring($m,$length)
			}
			Catch {
				throw "Unable to convert received data into XML correctly. The error message is $_"
			}
			
		}
		Else {
			#Unable to Login
			throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
		}
		$uxdataxml.system
}

#Function to grab UX Global Call counters
Function global:get-uxsystemcallstats {
	<#
	.SYNOPSIS      
	 This cmdlet reports Call statistics from Ribbon SBC.
	 
	.DESCRIPTION
	 This cmdlet report Call statistics (global level only) from Ribbon SBC eg: Calls failed, Calls Succeeded, Call Currently Up, etc.
	
	.EXAMPLE
	get-uxsystemcallstats
	
	#>
	[cmdletbinding()]
	Param()
	$args1 = ""
	$url = "https://$uxhostname/rest/systemcallstats"
	
	Try {
		$uxrawdata = Invoke-RestMethod -Uri $url -Method GET -WebSession $sessionvar -ErrorAction Stop
	}
	
	Catch {
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
	}
	
		#Check if connection was successful.HTTP code 200 is returned
		If ( $uxrawdata | select-string "<http_code>200</http_code>"){
		
			Write-Verbose $uxrawdata
			
			#Sanitise data and return as object
			Try {
				$m = $uxrawdata.IndexOf("<systemcallstats href=")
				$length = ($uxrawdata.length - $m - 8)
				[xml]$uxdataxml =  $uxrawdata.substring($m,$length)
			}
			Catch {
				throw "Unable to convert received data into XML correctly. The error message is $_"
			}
			
		}
		Else {
			#Unable to Login
			throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
		}
		$uxdataxml.systemcallstats
}

#Function to backup UX. When the backup succeeds there is no acknowledgement from UX.Best way to verify backup was successful is to check the backup file size
Function global:invoke-uxbackup {
	<#
	.SYNOPSIS      
	 This cmdlet performs backup of Ribbon SBC
	 
	.DESCRIPTION
	This cmdlet performs backup of Ribbon SBC.
	Ensure to check the size of the backup file to verify the backup was successful as Ribbon does not acknowledge this.If a backup file is 1KB it means the backup was unsuccessful.
	
	.PARAMETER backupdestination
	Enter here the backup folder where the backup file will be copied. Ensure you have got write permissions on this folder.
	
	.PARAMETER backupfilename
	Enter here the Backup file name. The backup file will automatically be appended with .tar.gz extension.
	
	.EXAMPLE
	invoke-uxbackup -backupdestination c:\backup -backupfilename lyncgw01backup01
	
	#>
	[cmdletbinding()]
	Param(
		[Parameter(Mandatory=$true,Position=0)]
     	[string]$backupdestination,
		[Parameter(Mandatory=$true,Position=1)]
		[string]$backupfilename
	)
	
	#Verify the backup location exists
	If (Test-Path $backupdestination) {}
	Else {
		throw "Backup destination inaccessible. Please ensure backup destination exists and you have write permissions to it"
	}
	
	$args1 = ""
	$url = "https://$uxhostname/rest/system?action=backup"
	
	Try {
		Invoke-RestMethod -Uri $url -Method POST -Body $args1 -WebSession $sessionvar -OutFile $backupdestination\$backupfilename.tar.gz -ErrorAction Stop
	}
	Catch {
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
	}
}

#Function to return any resource (using GET)
Function global:get-uxresource {
	<#
	.SYNOPSIS      
	 This cmdlet makes a GET request to any valid UX resource. For full list of valid resources refer to https://support.sonus.net/display/UXAPIDOC
	 
	.DESCRIPTION      
	 This cmdlet makes a GET request to any valid UX resource. For full list of valid resources refer to https://support.sonus.net/display/UXAPIDOC.
	 The cmdlet is one of the most powerful as you can query pretty much any UX resource which supports GET requests!
	 
	.PARAMETER resource
	Enter a valid resource name here. For valid resource names refer to https://support.sonus.net/display/UXAPIDOC

	.EXAMPLE
	This example queries a "timing" resource 
	
	get-uxresource -resource timing

	.EXAMPLE
	This example queries a "certificate" resource 
	
	get-uxresource -resource certificate

	After you know the certificate id URL using the above cmdlet, you can perform second query to find more details:

	get-uxresource -resource certificate/1
	
	.LINK
	To find all the resources which can be queried, please refer to https://support.sonus.net/display/UXAPIDOC
	
	#>

	[cmdletbinding()]
	Param(
		[Parameter(Mandatory=$true,Position=0)]
		[string]$resource
	)
	
	$args1 = ""
	$url = "https://$uxhostname/rest/$resource"
	
	Try {
		$uxrawdata = Invoke-RestMethod -Uri $url -Method GET -WebSession $sessionvar -ErrorAction Stop
	}
	
	Catch {
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
	}
	
		#Check if connection was successful.HTTP code 200 is returned
	If ( $uxrawdata | select-string "<http_code>200</http_code>"){
	
		Write-Verbose $uxrawdata
		
		#Sanitise data and return as object
		Try {
			#Find any </status> and any whitespace following it
			$regex = [regex]'</status>\s+'

			write-verbose $regex.matches($uxrawdata)

			#Find the index of the point where </status> and whitespace following it ends.
			#To find this add the Index and length properties of the regex object
			$strstart = $regex.Match($uxrawdata).index+$regex.Match($uxrawdata).length

			#Now find </root> and any whitespace preceding it.
			$regex1 = [regex]'\s+</root>'
			$strend = $regex1.Match($uxrawdata).index
			
			#Fully formatted XML object
			[xml]$uxdataformatted = $uxrawdata.substring($strstart,$strend - $strstart)
		}
		Catch {
			throw "Unable to convert received data into XML correctly. The error message is $_.`nDisplaying rawxml $uxrawdata" 
		}
		
	}
	Else {
		#Unable to Login
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
	}
	#Return fully formatted XML object
	$uxdataformatted
}	

#Function to create a new resource on UX
Function global:new-uxresource {
	<#
	.SYNOPSIS      
	 This cmdlet initiates a PUT request to create a new UX resource. For full list of valid resources refer to https://support.sonus.net/display/UXAPIDOC
	 
	.DESCRIPTION      
	 This cmdlet  initiates a a PUT request to create a new UX resource. For full list of valid resources refer to https://support.sonus.net/display/UXAPIDOC.
	 Using this cmdlet you can create any resource on UX which supports PUT request!
	 
	.PARAMETER resource
	Enter a valid resource name here. For valid resource names refer to https://support.sonus.net/display/UXAPIDOC

	.EXAMPLE
	This example creates a new "sipservertable" resource 
	
	Grab the SIP Server table resource and next free available id
	((get-uxresource -resource sipservertable).sipservertable_list).sipservertable_pk
	
	Create new SIP server table and specify a free resource ID (15 here)
	new-uxresource -args "Description=LyncMedServers" -resource sipservertable/15
	
	.LINK
	To find all the resources which can be queried, please refer to https://support.sonus.net/display/UXAPIDOC
	
	#>

	[cmdletbinding()]
	Param(
		[Parameter(Mandatory=$true,Position=0)]
		[AllowEmptyString()]
		[string]$args,
		
		[Parameter(Mandatory=$true,Position=1)]
		[string]$resource
	)
	
	#Create the URL which will be passed to UX
	$url = "https://$uxhostname/rest/$resource"
	
	Try {
		$uxrawdata = Invoke-RestMethod -Uri $url -Method PUT -Body $args -WebSession $sessionvar -ErrorAction Stop
	}
	
	Catch {
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
	}
	
		#Check if connection was successful.HTTP code 200 is returned
	If ( $uxrawdata | select-string "<http_code>200</http_code>"){
	
		Write-Verbose $uxrawdata
		
		#Sanitise data and return as object
		Try {
			#Find any </status> and any whitespace following it
			$regex = [regex]'</status>\s+'

			write-verbose $regex.matches($uxrawdata)

			#Find the index of the point where </status> and whitespace following it ends.
			#To find this add the Index and length properties of the regex object
			$strstart = $regex.Match($uxrawdata).index+$regex.Match($uxrawdata).length

			#Now find </root> and any whitespace preceding it.
			$regex1 = [regex]'\s+</root>'
			$strend = $regex1.Match($uxrawdata).index
			
			#Fully formatted XML object
			[xml]$uxdataformatted = $uxrawdata.substring($strstart,$strend - $strstart)
		}
		Catch {
			throw "Unable to convert received data into XML correctly. The error message is $_.`nDisplaying rawxml $uxrawdata" 
		}
		
	}
	
	#If 500 message is returned
	ElseIf ($uxrawdata | select-string "<http_code>500</http_code>"){
		Write-Verbose -Message $uxrawdata
		throw "Unable to create a new resource. Ensure you have entered a unique resource id.Verify this using `"get-uxresource`" cmdlet"
	}
	
	Else {
		#Unable to Login
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
	}
	#Return fully formatted XML object
	write-verbose $uxdataformatted
}	

#Function to delete a resource on UX. 200OK is returned when a resource is deleted successfully. 500 if resource did not exist or couldn't delete it
Function global:remove-uxresource {
	<#
	.SYNOPSIS      
	 This cmdlet initates a DELETE request to remove a UX resource. For full list of valid resources refer to https://support.sonus.net/display/UXAPIDOC
	 
	.DESCRIPTION      
	 This cmdlet  initates a DELETE request to remove a UX resource. For full list of valid resources refer to https://support.sonus.net/display/UXAPIDOC.
	 You can delete any resource which supports DELETE request.
	 
	.PARAMETER resource
	Enter a valid resource name here. For valid resource names refer to https://support.sonus.net/display/UXAPIDOC

	.EXAMPLE
	Extract the transformation table id of the table you want to delete
	get-uxtransformationtable
	
	Now execute remove-uxresource cmdlet to delete the transformation table
	remove-uxresource -resource transformationtable/13
	
	.EXAMPLE
	 Extract the SIP Server table resource and find the id of the table you want to delete
	((get-uxresource -resource sipservertable).sipservertable_list).sipservertable_pk
	
	Now execute remove-uxresource cmdlet
	remove-uxresource -resource sipservertable/10
	
	.LINK
	To find all the resources which can be queried, please refer to https://support.sonus.net/display/UXAPIDOC
	
	#>

	[cmdletbinding()]
	Param(
		[Parameter(Mandatory=$false,Position=0)]
		[AllowEmptyString()]
		[string]$args,
		
		[Parameter(Mandatory=$true,Position=1)]
		[string]$resource
	)
	
	#The URL  which will be passed to the UX
	$url = "https://$uxhostname/rest/$resource"
	
	Try {
		$uxrawdata = Invoke-RestMethod -Uri $url -Method DELETE -Body $args -WebSession $sessionvar -ErrorAction Stop
	}
	
	Catch {
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
	}
	
		#Check if connection was successful.HTTP code 200 is returned
	If ( $uxrawdata | select-string "<http_code>200</http_code>"){
	
		Write-Verbose $uxrawdata
	}
	
	#If 500 message is returned
	ElseIf ($uxrawdata | select-string "<http_code>500</http_code>"){
		Write-Verbose -Message $uxrawdata
		throw "Unable to delete the resource. Verify using `"get-uxresource`" cmdlet, the resource does exist before deleting"
	}
	
	Else {
		#Unable to Login
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
	}

}	

#Function to create a modify and existing resource on the UX
Function global:set-uxresource {
	<#
	.SYNOPSIS      
	 This cmdlet initates a POST request to modify existing UX resource. For full list of valid resources refer to https://support.sonus.net/display/UXAPIDOC
	 
	.DESCRIPTION      
	 This cmdlet initates a POST request to modify existing UX resource. For full list of valid resources refer to https://support.sonus.net/display/UXAPIDOC.
	 
	.PARAMETER resource
	Enter a valid resource name here. For valid resource names refer to https://support.sonus.net/display/UXAPIDOC

	.EXAMPLE
	Assume you want to change the description of one of the SIPServer table.
	Using Get find the ID of the sip server table
	((get-uxresource -resource sipservertable).sipservertable_list).sipservertable_pk
	
	Once you have found the ID, issue the cmdlet below to modify the description
	set-uxresource -args Description=SBA2 -resource sipservertable/20
	
	.EXAMPLE
	Assume you want to change Description of the transformation table.
	Extract the transformation table id of the table you want to modify
	get-uxtransformationtable
	
	Once you have found the ID, issue the cmdlet below to modify the description
	set-uxresource -args "Description=Test5" -resource "transformationtable/12"
	
	.LINK
	To find all the resources which can be queried, please refer to https://support.sonus.net/display/UXAPIDOC
	
	#>

	[cmdletbinding()]
	Param(
		[Parameter(Mandatory=$true,Position=0)]
		[AllowEmptyString()]
		[string]$args,
		
		[Parameter(Mandatory=$true,Position=1)]
		[string]$resource
	)
	
	#Create the URL which will be passed to UX
	$url = "https://$uxhostname/rest/$resource"
	
	Try {
		$uxrawdata = Invoke-RestMethod -Uri $url -Method POST -Body $args -WebSession $sessionvar -ErrorAction Stop
	}
	
	Catch {
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
	}
	
		#Check if connection was successful.HTTP code 200 is returned
	If ( $uxrawdata | select-string "<http_code>200</http_code>"){
	
		Write-Verbose $uxrawdata
		
		#Sanitise data and return as object
		Try {
			#Find any </status> and any whitespace following it
			$regex = [regex]'</status>\s+'

			write-verbose $regex.matches($uxrawdata)

			#Find the index of the point where </status> and whitespace following it ends.
			#To find this add the Index and length properties of the regex object
			$strstart = $regex.Match($uxrawdata).index+$regex.Match($uxrawdata).length

			#Now find </root> and any whitespace preceding it.
			$regex1 = [regex]'\s+</root>'
			$strend = $regex1.Match($uxrawdata).index
			
			#Fully formatted XML object
			[xml]$uxdataformatted = $uxrawdata.substring($strstart,$strend - $strstart)
		}
		Catch {
			throw "Unable to convert received data into XML correctly. The error message is $_.`nDisplaying rawxml $uxrawdata" 
		}
		
	}
	
	#If 500 message is returned
	ElseIf ($uxrawdata | select-string "<http_code>500</http_code>"){
		Write-Verbose -Message $uxrawdata
		throw "Unable to modify the resource. Ensure the resource exists. You can verify this using `"get-uxresource`""
	}
	
	Else {
		#Unable to Login
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
	}
	#Return fully formatted XML object
	write-verbose $uxdataformatted
}	

#Function to get transformation table
Function global:get-uxtransformationtable {
	<#
	.SYNOPSIS      
	 This cmdlet displays all the transformation table names and ID's
	
	.EXAMPLE
	 get-uxtransformationtable
	
	#>

	[cmdletbinding()]
	Param()
	$args1 = ""
	$url = "https://$uxhostname/rest/transformationtable"
	
	Try {
		$uxrawdata = Invoke-RestMethod -Uri $url -Method GET -WebSession $sessionvar -ErrorAction Stop
	}
	
	Catch {
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
	}
	
	#Check if connection was successful.HTTP code 200 is returned
	If ( $uxrawdata | select-string "<http_code>200</http_code>"){
	
		Write-Verbose $uxrawdata
		
		#Sanitise data and return as object
		Try {
			$m = $uxrawdata.IndexOf("<transformationtable_list")
			$length = ($uxrawdata.length - $m - 8)
			[xml]$uxdataxml =  $uxrawdata.substring($m,$length)
		}
		Catch {
			throw "Unable to convert received data into XML correctly. The error message is $_"
		}
		
	}
	Else {
		#Unable to Login
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
	}
	
	#Create template object to hold the values of Tranformation tables
	$objTemplate = New-Object psobject
	$objTemplate | Add-Member -MemberType NoteProperty -Name id -Value $null
	$objTemplate | Add-Member -MemberType NoteProperty -Name Description -Value $null
	
	#Create an empty array which will contain the output
	$objResult = @()
		
	#This object contains all the Transformation table objects. Do a foreach to grab friendly names of the transformation tables
	foreach ($objtranstable in $uxdataxml.transformationtable_list.transformationtable_pk) {
		Try {
		$uxrawdata2 = Invoke-RestMethod -Uri $($objtranstable.href) -Method GET -WebSession $sessionvar -ErrorAction Stop
		}
	
		Catch {
			throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
		}
	
		#Check if connection was successful.HTTP code 200 is returned
		If ( $uxrawdata2 | select-string "<http_code>200</http_code>"){
	
			Write-Verbose $uxrawdata2
		
			#Sanitise data and return as object
			Try {
				$m = $uxrawdata2.IndexOf("<transformationtable id=")
				$length = ($uxrawdata2.length - $m - 8)
				[xml]$uxdataxml2 =  $uxrawdata2.substring($m,$length)
				
				#Create template object and stuff all the transformation tables into it
				$objTemp = $objTemplate | Select-Object *
				$objTemp.id = $uxdataxml2.transformationtable.id
				$objTemp.description = $uxdataxml2.transformationtable.description
				$objResult+=$objTemp
			}
			Catch {
				throw "Unable to convert received data into XML correctly. The error message is $_"
			}
			
		}
		Else {
			#Unable to Login
			throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
		}
	
	}
	#This object contains all the transformation tables with id to description mapping
	$objResult
}


#Function to get transformation table entries from a specified transformation table
Function global:get-uxtransformationentry {
	<#
	.SYNOPSIS      
	 This cmdlet displays the transformation table entries of a specified transformation table.
	 
	.DESCRIPTION
	This cmdlet displays the transformation table entries if a transformation table id is specified. To extract the tranformation table id execute "get-uxtransformationtable" cmdlet
	The output of the cmdlet contains InputField/OutputFields which are displayed as integer. To map the numbers to friendly names refer: bit.ly/Iy7JQS
	
	.PARAMETER uxtransformationtableid
	Enter here the transformation table id of the transformation table.To extract the tranformation table id execute "get-uxtransformationtable" cmdlet
	
	.EXAMPLE
	 get-uxtransformationentry -uxtransformationtableid 4
	
	#>
	[cmdletbinding()]
	Param(
		[Parameter(Mandatory=$true,Position=0,HelpMessage='To find the ID of the transformation table execute "get-uxtransformationtable" cmdlet')]
	    [int]$uxtransformationtableid
	)
	$args1 = ""
	#URL to grab the Transformation tables entry URL's when tranformation table ID is specified
	$url = "https://$uxhostname/rest/transformationtable/$uxtransformationtableid/transformationentry"
	
	Try {
		$uxrawdata = Invoke-RestMethod -Uri $url -Method GET -WebSession $sessionvar -ErrorAction Stop
	}
	
	Catch {
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
	}
	
	#Check if connection was successful.HTTP code 200 is returned
	If ( $uxrawdata | select-string "<http_code>200</http_code>"){
	
		Write-Verbose -Message $uxrawdata
		
		#Sanitise data and return as object
		Try {
			$m = $uxrawdata.IndexOf("<transformationentry_list")
			$length = ($uxrawdata.length - $m - 8)
			[xml]$uxdataxml =  $uxrawdata.substring($m,$length)
		}
		Catch {
			throw "Unable to convert received data into XML correctly. The error message is $_"
		}
		
	}
	Else {
		#Unable to Login
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
	}
	
	#Grab the sequence of transformation entries in transformation.This information is stored in transformation table, so do have to query transformation table
	#FUNCTION get-uxresource IS USED IN THIS CMDLET
	Try {
		$transformationsequence = (((get-uxresource "transformationtable/$uxtransformationtableid").transformationtable).sequence).split(",")
	}
	
	Catch {
		throw "Unable to find the sequence of transformation entries.The error is $_"
	}
	
	#Create template object to hold the values of Tranformation tables
	$objTemplate = New-Object psobject
	$objTemplate | Add-Member -MemberType NoteProperty -Name InputField -Value $null
	$objTemplate | Add-Member -MemberType NoteProperty -Name InputFieldValue -Value $null
	$objTemplate | Add-Member -MemberType NoteProperty -Name OutputField -Value $null
	$objTemplate | Add-Member -MemberType NoteProperty -Name OutputFieldValue -Value $null
	$objTemplate | Add-Member -MemberType NoteProperty -Name MatchType -Value $null
	$objTemplate | Add-Member -MemberType NoteProperty -Name Description -Value $null
	$objTemplate | Add-Member -MemberType NoteProperty -Name ID -Value $null
	$objTemplate | Add-Member -MemberType NoteProperty -Name SequenceID -Value $null
	
	#Create an empty array which will contain the output
	$objResult = @()
		
	#This object contains all the Transformation table objects. Do a foreach to grab friendly names of the transformation tables
	foreach ($objtransentry in $uxdataxml.transformationentry_list.transformationentry_pk) {
		Try {
		$uxrawdata2 = Invoke-RestMethod -Uri $($objtransentry.href) -Method GET -WebSession $sessionvar -ErrorAction Stop
		}
	
		Catch {
			throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
		}
	
		#Check if connection was successful.HTTP code 200 is returned
		If ( $uxrawdata2 | select-string "<http_code>200</http_code>"){
	
			Write-Verbose $uxrawdata2
		
			#Sanitise data and return as object
			Try {
				$m = $uxrawdata2.IndexOf("<transformationentry id=")
				$length = ($uxrawdata2.length - $m - 8)
				[xml]$uxdataxml2 =  $uxrawdata2.substring($m,$length)
				
				#Sanitise the transformation table entry as it also contains the transformation table id (eg: 3:1, we only need 1)
				$transformationtableentryidraw = $uxdataxml2.transformationentry.id
				$transformationtableentryidfor = $transformationtableentryidraw.Substring(($transformationtableentryidraw.IndexOf(":")+1),$transformationtableentryidraw.Length-($transformationtableentryidraw.IndexOf(":")+1))
				
				#Create template object and stuff all the transformation tables into it
				$objTemp = $objTemplate | Select-Object *
				$objTemp.InputField = $uxdataxml2.transformationentry.InputField
				$objTemp.InputFieldValue = $uxdataxml2.transformationentry.InputFieldValue
				$objTemp.OutputField = $uxdataxml2.transformationentry.OutputField
				$objTemp.OutputFieldValue= $uxdataxml2.transformationentry.OutputFieldValue
				$objTemp.MatchType = $uxdataxml2.transformationentry.MatchType
				$objTemp.Description = $uxdataxml2.transformationentry.Description
				$objTemp.ID = $transformationtableentryidfor
				#Searches for the position in an array of a particular ID
				$objTemp.SequenceID = ($transformationsequence.IndexOf($objTemp.ID)+1)
				$objResult+=$objTemp
			}
			Catch {
				throw "Unable to convert received data into XML correctly. The error message is $_"
			}
			
		}
		Else {
			#Unable to Login
			throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
		}
	
	}
	#This object contains all the transformation tables with id to description mapping
	$objResult
}

#Function to create new transformation table
Function global:new-uxtransformationtable {
	<#
	.SYNOPSIS      
	 This cmdlet creates a new transformation table (not transformation table entry)
	 
	.DESCRIPTION
	This cmdlet creates a transformation table (not transformation table entry).
	
	.PARAMETER Description
	Enter here the Description (Name) of the Transformation table.This is what will be displayed in the Ribbon GUI
	
	.EXAMPLE
	 new-uxtransformationtable -Description "LyncToPBX"
	
	#>
	[cmdletbinding()]
	Param(
		[Parameter(Mandatory=$true,Position=0)]
		[ValidateLength(1,64)]
		[string]$Description
	)
	
	#DEPENDENCY ON get-uxtransformationtable FUNCTION TO GET THE NEXT AVAILABLE TRANSFORMATIONTABLEID
	Try {
		$transformationtableid = ((get-uxtransformationtable | select -ExpandProperty id | Measure-Object -Maximum).Maximum)+1
	}
	Catch {
		throw "Command failed when trying to execute the Transformationtableid using `"get-uxtransformationtable`" cmdlet.The error is $_"
	}
	
	#URL for the new transformation table
	$url = "https://$uxhostname/rest/transformationtable/$transformationtableid"
	
	Try {
		$uxrawdata = Invoke-RestMethod -Uri $url -Method PUT -Body "Description=$Description" -WebSession $sessionvar -ErrorAction Stop
	}
	
	Catch {
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
	}
	#If table is successfully created, 200OK is returned
	If ( $uxrawdata | select-string "<http_code>200</http_code>"){
	
		Write-Verbose -Message $uxrawdata
	}
	#If 500 message is returned
	ElseIf ($uxrawdata | select-string "<http_code>500</http_code>"){
		Write-Verbose -Message $uxrawdata
		throw "Unable to create transformation table. Ensure you have entered a unique transformation table id"
	}
	#If no 200 or 500 message
	Else {
		#Unable to Login
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
	}
	
	#Sanitise data and return as object for verbose only
	Try {
		$m = $uxrawdata.IndexOf("<transformationtable id=")
		$length = ($uxrawdata.length - $m - 8)
		[xml]$uxdataxml =  $uxrawdata.substring($m,$length)
	}
	Catch {
		throw "Unable to convert received data into XML correctly. The error message is $_"
	}
	#Return Transformation table object just created
	write-verbose $uxdataxml.transformationtable
}

#Function to create new transformation table entry
Function global:new-uxtransformationentry {
	<#
	.SYNOPSIS      
	 This cmdlet creates transformation entries in existing transformation table
	 
	.DESCRIPTION
	This cmdlet creates transformation entries in existing transformation table.You need to specify the transformation table where these transformation entries should be created.
	
	.PARAMETER TransformationTableId
	Enter here the TransformationTableID of the transformation table where you want to add the transformation entry. This can be extracted using "get-uxtransformationtable" cmdlet
	
	.PARAMETER InputFieldType
	Enter here the code (integer) of the Field you want to add, eg:If you want to add "CalledNumber" add 0. Full information on which codes maps to which field please refer http://bit.ly/Iy7JQS

	.PARAMETER InputFieldValue
	Enter the value which should be matched.eg: If you want to match all the numbers between 2400 - 2659 you would enter here "^(2([45]\d{2}|6[0-5]\d))$"

	.PARAMETER OutputFieldType
	Enter here the code (integer) of the Field you want to add, eg:If you want to add "CalledNumber" add 0. Full information on which codes maps to which field please refer http://bit.ly/Iy7JQS

	.PARAMETER OutputFieldValue
	Enter here the output of the Input value.eg: If you want to change input of "^(2([45]\d{2}|6[0-5]\d))$" to +44123456XXXX, you would enter here +44123456\1

	.PARAMETER Description
	Enter here the Description (Name) of the Transformation entry. This is what will be displayed in the Ribbon GUI

	.PARAMETER MatchType
	Enter here if the Transformation entry you will create will be Mandatory(0) or Optional(1). If this parameter is not specified the transformation table will be created as Optional

	.EXAMPLE
	Assume you want to create a new transformation table.
	First determine the ID of the transformation table in which you want to create the new transformation entry.
	
	get-uxtransformationtable

	This example creates an Optional (default) transformation entry converting Called Number range  2400 - 2659  to Called Number +44123456XXXX
	
	new-uxtransformationentry -TransformationTableId 6 -InputFieldType 0 -InputFieldValue '^(2([45]\d{2}|6[0-5]\d))$' -OutputFieldType 0 -OutputFieldValue '+44123456\1' -Description "ExtToDDI"
	
	.EXAMPLE
	This example creates an Optional transformation entry converting Calling Number beginning with 0044xxxxxx to Calling Number +44xxxxxx
	
	new-uxtransformationentry -TransformationTableId 3 -InputFieldType 3 -InputFieldValue '00(44\d(.*))' -OutputFieldType 3 -OutputFieldValue '+\1' -Description "UKCLIToE164"
	
	.EXAMPLE
	This example creates a Mandatory CLI (Calling Number)passthrough
	
	new-uxtransformationentry -TransformationTableId 9 -InputFieldType 3 -InputFieldValue '(.*)' -OutputFieldType 3 -OutputFieldValue '\1' -Description "PassthroughCLI" -MatchType 0
	
	.LINK
	For Input/Output Field Value Code mappings, please refer to http://bit.ly/Iy7JQS
	
	#>
	[cmdletbinding()]
	Param(
		[Parameter(Mandatory=$true,Position=0)]
		[int]$TransformationTableId,
		
		[Parameter(Mandatory=$true,Position=1,HelpMessage="Refer http://bit.ly/Iy7JQS for further detail")]
		[ValidateRange(0,31)]
		[int]$InputFieldType,
		
		[Parameter(Mandatory=$true,Position=2)]
		[ValidateLength(1,256)]
		[string]$InputFieldValue,
		
		[Parameter(Mandatory=$true,Position=3,HelpMessage="Refer http://bit.ly/Iy7JQS for for further detail")]
		[ValidateRange(0,31)]
		[string]$OutputFieldType,
		
		[Parameter(Mandatory=$true,Position=4)]
		[ValidateLength(1,256)]
		[string]$OutputFieldValue,
		
		[Parameter(Mandatory=$false,Position=6)]
		[ValidateLength(1,64)]
		[string]$Description,
		
		[Parameter(Mandatory=$False,Position=5)]
		[ValidateSet(0,1)]
		[int]$MatchType = 1
		
	)
	
	#DEPENDENCY ON get-uxtransformationentry FUNCTION TO GET THE NEXT AVAILABLE TRANSFORMATIONTABLEID
	Try {
		$transtableentryid = ((get-uxtransformationentry -uxtransformationtableid $TransformationTableId | select -ExpandProperty id | Measure-Object -Maximum).Maximum)+1
	}
	Catch {
		throw "Command failed when trying to execute the Transformationtableentryid using `"get-uxtransformationentry`" cmdlet.The error is $_"
	}
	
	#URL for the new transformation table
	$url = "https://$uxhostname/rest/transformationtable/$TransformationTableId/transformationentry/$transtableentryid"
	#Replace "+" with "%2B" as + is considered a Space in HTTP/S world, so gets processed as space when used in a command
	$InputFieldValue = $InputFieldValue.replace("+",'%2B')
	$OutputFieldValue = $OutputFieldValue.replace("+",'%2B')
	#Variable which contains all the information we require to create a transformation table.
	$args2 = "Description=$Description&InputField=$InputFieldType&InputFieldValue=$InputFieldValue&OutputField=$OutputFieldType&OutputFieldValue=$OutputFieldValue&MatchType=$MatchType"
	
	Try {
		$uxrawdata3 = Invoke-RestMethod -Uri $url -Method PUT -body $args2 -WebSession $sessionvar -ErrorAction Stop
	}
	
	Catch {
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
	}
	#If table is successfully created, 200OK is returned
	If ( $uxrawdata3 | select-string "<http_code>200</http_code>"){
	
		Write-Verbose -Message $uxrawdata3
	}
	#If 500 message is returned
	ElseIf ($uxrawdata3 | select-string "<http_code>500</http_code>"){
		Write-Verbose -Message $uxrawdata3
		throw "Unable to create transformation table. Ensure you have entered a unique transformation table id"
	}
	#If no 200 or 500 message
	Else {
		#Unable to Login
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
	}
	
	#Sanitise data and return as object for verbose only
	Try {
		$m1 = $uxrawdata3.IndexOf("<transformationentry id=")
		$length1 = ($uxrawdata3.length - $m1 - 8)
		[xml]$uxdataxml3 =  $uxrawdata3.substring($m1,$length1)
	}
	Catch {
		throw "Unable to convert received data into XML correctly. The error message is $_"
	}
	
	#Return Transformation table object just created for verbose only
	write-verbose $uxdataxml3.transformationentry
	
}

#Function to restartUX
Function global:restart-uxgateway {
	<#
	.SYNOPSIS      
	 This cmdlet restarts Ribbon gateway
	 
	.SYNOPSIS      
	This cmdlet restarts Ribbon gateway
	
	.EXAMPLE
	 restart-uxgateway
	
	#>

	[cmdletbinding()]
	Param()
	$args1 = ""
	$url = "https://$uxhostname/rest/system?action=reboot"
	
	Try {
		$uxrawdata = Invoke-RestMethod -Uri $url -Method POST -Body $args1 -WebSession $sessionvar -ErrorAction Stop
	}
	
	Catch {
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
	}
	
	#Check if reboot command was accepted.HTTP code 200 is returned
	If ( $uxrawdata | select-string "<http_code>200</http_code>"){
	
		Write-Verbose $uxrawdata
		
		#Sanitise data and return as object
		Try {
			$m = $uxrawdata.IndexOf("<transformationtable_list")
			$length = ($uxrawdata.length - $m - 8)
			[xml]$uxdataxml =  $uxrawdata.substring($m,$length)
		}
		Catch {
			throw "Unable to convert received data into XML correctly. The error message is $_"
		}
		
	}
	Else {
		#Unable to Login
		throw "Unable to process this command.Ensure you have connected to the gateway using `"connect-uxgateway`" cmdlet or if you were already connected your session may have timed out (10 minutes of no activity).The error message is $_"
	}
}

