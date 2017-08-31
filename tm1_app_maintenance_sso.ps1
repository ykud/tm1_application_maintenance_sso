# Execute TM1 application maintenance utility with Single Signon CAM secured environments
# We need to acquire a CAM passport and then call application maintenance bat file with this authentication
# see this technote for more details
# We are doing the following in each call:
# 1) Acquiring a global mutually exclusive lock (MutEx) to ensure that multiple calls to update applications are 
#    serialised and we don't get an 'Another application update job is already running for this application or server' error
# 2) Login to Cognos BI portal with provided credentials and grab CAM passport cookie
# 3) Run application_maintenance.bat with CAM passport with just got
# Version history 
# 0.2, 11/08/2017, ykud@pmsquare.com.au: Adding handling of all operations
# 0.1, 08/08/2017, ykud@pmsquare.com.au: Initial version
#
param
(
  [Parameter(Mandatory=$True)]
  [string] $logFileLocation,
  [Parameter(Mandatory=$True)]
  [string] $cognos_gateway_url,
  [Parameter(Mandatory=$True)]
  [string] $domain,
  [Parameter(Mandatory=$True)]
  [string] $user,
  [Parameter(Mandatory=$True)]
  [string] $password,
  [Parameter(Mandatory=$True)]
  [string] $app_maintenance_utility_path,
  [Parameter(Mandatory=$True)]
  [string] $tm1_application_server_url,
  [Parameter(Mandatory=$True)]
  [string] $application_id,
  [ValidateSet("activate","deactivate","deploy","exportrights","importrights","importrights -merge","refreshrights","reset", "reset -remove_sandboxes")] 
  [string] $operation,
  [Parameter(Mandatory=$False)] [string] $rights_file
)

Function Write-Log {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$False)]
	
    [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
    [String]
    $Level = "INFO",
    [Parameter(Mandatory=$True)]
	
    [string]
    $Message,
    [Parameter(Mandatory=$False)]
	
    [string]
    $logfile
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"
    If($logfile) {
        Add-Content $logfile -Value $Line
    }
    Else {
        Write-Output $Line
    }
}

### Main log file
$logFile = "$logFileLocation\application_maintenance_sso.log"
# how long do we wait before giving up
$maxWaitInMinutes = 180
# Check whether we have the required arguments
if ($operation -eq "exportrights" -or $operation -eq "importrights" -or $operation -eq"importrights -merge" )
	{
		if (!$rights_file)
		{
			Write-Log "ERROR" "$application_id : Please specify rights file for $operation" $logFile
		}
		else
		{
			$operationString = "-op $operation -rightsFile ""$rights_file"""
		}
	}
else
	{
		$operationString = "-op $operation"
	}
### START MUTEX HERE
$Mutex = New-Object System.Threading.Mutex($false, "Global\TM1AppMaintenanceMutex")
IF ($Mutex.WaitOne($maxWaitInMinutes*60*1000))
{
	Write-Log "INFO" "$application_id : We will try to $operationString for the application $application_id" $logFile
	#Write-Log "INFO" "$application_id : We can start updating the application, no other update is running" $logFile
	#Write-Log "INFO" "Trying to login to Cognos portal on $cognos_gateway_url $user $password $domain" $logFile
	$cookiejar = New-Object System.Net.CookieContainer
	$webrequest = [System.Net.HTTPWebRequest]::Create($cognos_gateway_url);
	if ($error.count -gt 0)
	{
		Write-Log "ERROR" $error[0] $logFile
		exit
	}
	$webrequest.CookieContainer = $cookiejar
	$credut = New-Object System.Net.NetworkCredential;
	$credut.UserName = $user;
	$credut.Password = $password;
	$credut.Domain = $domain
	$webrequest.Credentials = $credut
	$response = $webrequest.GetResponse()
	if ($error.count -gt 0)
	{
		Write-Log "ERROR" $error[0] $logFile
		exit
	}
	$cookies = $cookiejar.GetCookies($cognos_gateway_url)
	if ($error.count -gt 0)
	{
		Write-Log "ERROR" $error[0] $logFile
		exit
	} 
	$cam_passport = $cookies["cam_passport"].Value 
	if (!$cam_passport) 
	  {
		Write-Log "ERROR" "$application_id : Couldn't authenticate and get CAM passport " $logfile
		exit
	  }
	# Prepare the execution string  
	$timeStamp = (Get-Date).toString("yyyy_MM_dd_HHmmss")
	$debugLogFile = """$logFileLocation$($application_id)$($timeStamp)_app_maintenance_debug.txt"""
	$sArgumentList = " -serviceURL $tm1_application_server_url -credentials CAM:$cam_passport -applicationid ""$application_id"" $operationString -logfile ""$logFileLocation$($application_id)$($timeStamp)_app_maintenance_debug_log.txt"" -loglevel DEBUG"
	
    $executionResult = Start-Process -FilePath """$($app_maintenance_utility_path)app_maintenance.bat""" -ArgumentList $sArgumentList -Wait -passthru -WorkingDirectory $app_maintenance_utility_path -RedirectStandardError "$logFileLocation$($application_id)$($timeStamp)_stderr.txt" -RedirectStandardOutput "$logFileLocation$($application_id)$($timeStamp)_stdout.txt"
	# Run string and check result
	if ($executionResult.ExitCode -ne 0)
	{
		Write-Log "ERROR" "$application_id : Application updated failed, please see the $debugLogFile file for details" $logFile
	}
	else
	{
		Write-Log "INFO" "$application_id : Application updated successfully" $logFile
	}
	# Release Mutex
	$Mutex.ReleaseMutex()
	}
else
{
	Write-Log "ERROR" "$application_id : Couldn't acquire the lock to update application after $maxWaitInMinutes minutes, giving up" $logfile
}
