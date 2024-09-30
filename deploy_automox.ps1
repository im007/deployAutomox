<#
.SYNOPSIS
  Downloads and installs the latest Automox Agent MSI
  It will also join the device to your organization
  and optionally a specific server group.

.DESCRIPTION
  Uses a WebClient object to download the latest Automox Agent MSI and
  install it with silent options and your specified organization access key.

.PARAMETER AccessKey
  This parameter is required to run.
  Specifies the Automox Organization this device should belong to.
  Can also be referred to as "Organization Key" or
  "Unique User Key". This is a unique identifier for your organization
  and can be found in your Automox Console in these locations:

  Devices -> Add Devices
  Settings -> API

  This must be a valid GUID to allow the script to run

  -AccessKey xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

.PARAMETER GroupName
  Specifies the Automox Server Group to move the device to upon
  joining your Organization. Note that if this isn't a top-level
  Group, then you will also need to specify the ParentGroupName
  as well

  -GroupName "My Group Name"

.PARAMETER ParentGroupName
  Specifies the Parent Group of the Server Group specified
  previously.

  -ParentGroupName "My Parent Group Name"

.NOTES
  If you prefer not to specify parameters to this script file,
  you may enter the values manually in the param section in the
  Setup region below.

  Released: 2019-05-08
  Author: Automox Support

.EXAMPLE
  Run this script file with at least an AccessKey specified
    Install-AxAgentMsi.ps1 -AccessKey xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

  Optionally include a Group and Parent Group Name as needed
    Install-AxAgentMsi.ps1 -AccessKey xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -GroupName "My Group Name" -ParentGroupName "My Parent Group Name"

.LINK
http://www.automox.com
#>

#region Setup

param (
    [Parameter(Mandatory = $true)]
    [ValidatePattern('(\{|\()?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\}|\()?')]
    [String]$AccessKey = "",
    [Parameter(Mandatory = $false)][String]$GroupName,
    [Parameter(Mandatory = $false)][String]$ParentGroupName
)

# These values are typically fixed. But may be modified to fit a custom scenario
$installerUrl = "https://console.automox.com/installers/Automox_Installer-latest.msi"
$installerName = "Automox_Installer-latest.msi"
$installerPath = "$env:TEMP\$installerName"
$agentPath = "${env:ProgramFiles(x86)}\Automox\amagent.exe"
$logFile = "$env:TEMP\AutomoxInstallandLaunch.log"

#endregion Setup

#region Functions

function Write-Log
{
    param (
        [Parameter(Mandatory = $true)][String]$line,
        [Parameter(Mandatory = $true)][String]$file,
        [Parameter(Mandatory = $false)][Switch]$Overwrite,
        [Parameter(Mandatory = $false)][Switch]$ToConsole,
        [Parameter(Mandatory = $false)][Switch]$IsError
    )
    $timeStamp = "[" + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") + "]"

    if ((!(Test-Path $file)) -or ($overwrite))
    {
        Set-Content -Path $file -Value "$timeStamp $line"
    }
    else
    {
        Add-Content -Path $file -Value "$timeStamp $line"
    }

    if ($ToConsole)
    {
        if ($IsError)
        {
            Write-Error "$timeStamp $line"
        }
        else
        {
            Write-Host "$timeStamp $line"
        }
    }
}

function Download-AxInstaller
{
    param (
        [Parameter(Mandatory = $true)][String]$installerUrl,
        [Parameter(Mandatory = $true)][String]$installerPath
    )
    $downloader = New-Object System.Net.WebClient
    try
    {
        $downloader.DownloadFile("$installerUrl", "$installerPath")
        return $true
    }
    catch
    {
        Write-Error "Failed to download installer from $installerUrl to $installerPath. Error: $_"
        return $false
    }
}

function Set-AxServerGroup
{
    param (
        [Parameter(Mandatory = $true)][String]$Group,
        [Parameter(Mandatory = $false)][String]$ParentGroup
    )
    if ($ParentGroup)
    {
        $argList = "--setgrp `"Default Group/$ParentGroup/$Group`""
    }
    else
    {
        $argList = "--setgrp `"Default Group/$Group`""
    }
    try
    {
        Start-Process -FilePath $agentPath -ArgumentList "$argList" -Wait -ErrorAction Stop
        Start-Process -FilePath $agentPath -ArgumentList "--deregister" -ErrorAction Stop
    }
    catch
    {
        Write-Error "Failed to set server group. Error: $_"
    }
}

function Install-AxAgent
{
    param (
        [Parameter(Mandatory = $true)][String]$installerPath,
        [Parameter(Mandatory = $true)][String]$AccessKey
    )
    try
    {
        $process = Start-Process 'msiexec.exe' -ArgumentList "/i `"$installerPath`" /qn /norestart ACCESSKEY=$AccessKey" -Wait -PassThru -ErrorAction Stop
        return $process.ExitCode
    }
    catch
    {
        Write-Error "Failed to install Automox Agent. Error: $_"
        return 1
    }
}

#endregion Functions


#region Operations

# Check for existing Agent Service and Running Status
# If not installed, continue
# If installed and not "Running" start the service
# If installed and "Running" do nothing
Write-Log "Checking Agent Status" $logFile -Overwrite -ToConsole
try
{
    $service = Get-Service -Name amagent -ErrorAction Stop
}
catch
{
    Write-Error "Failed to get the Automox Agent service. Error: $_"
    $service = $null
}

## Case 1: Agent exists and status is "Running"
if ($service -ne $null -and $service.Status -eq "Running")
{
    Write-Log "Service is installed and Running. No further action needed`n Exit Code = 0" $logFile -ToConsole
    Exit 0
    ## Case 2: Agent exists and status is NOT "Running"
}
elseif ($service -ne $null -and $service.Status -ne "Running")
{
    Write-Log "Service is installed but not Running" $logFile -ToConsole
    try
    {
        # Attempt to start the Service. Exit 0 for success, Exit 1 for failure
        Start-Service -Name amagent -ErrorAction Stop
        Write-Log "Started Service, no further action needed`nExit Code = 0" $logFile -ToConsole
        Exit 0
    }
    catch
    {
        Write-Log "Unable to Start Agent Service, Please try to start the Automox Agent (amagent) service manually`n Exit Code = 1" $logFile -ToConsole -IsError
        Write-Error "Unable to Start Agent Service, Please try to start the Automox Agent (amagent) service manually"
        Exit 1
    }
}
else
{
    ## Case 3: Agent is not installed
    Write-Log "Agent is not present. Proceeding to Download and Install" $logFile -ToConsole
}


# Begin File Download. Assert Success before continuing
Write-Log "Download started" $logFile -ToConsole
$download = Download-AxInstaller -installerUrl $installerUrl -installerPath $installerPath

if (!$download)
{
    Write-Log "Download failed. Installation stopped`n Exit Code = 1" $logFile -ToConsole -IsError
    Exit 1
}
else
{
    Write-Log "Download succeeded" $logFile -ToConsole
}


# If successful download, then execute installer and log ExitCode
Write-Log "Starting installation of $installerName" $logFile -ToConsole
$exitCode = Install-AxAgent -installerPath $installerPath -AccessKey $AccessKey
Write-Log "Installation completed with Exit Code $exitCode" $logFile -ToConsole


# If successful installation (based on exit code), then proceed
# to set the group.
if (($exitCode -eq '0') -or ($exitCode -eq '1641') -or ($exitCode -eq '3010'))
{
    if (-not [string]::IsNullOrEmpty($ParentGroupName))
    {
        Write-Log "Moving Device to Group: $GroupName" $logFile -ToConsole
        Set-AxServerGroup -Group $GroupName -ParentGroup $ParentGroupName
    }
    elseif (-not [string]::IsNullOrEmpty($GroupName))
    {
        Write-Log "Moving Device to Group: $GroupName" $logFile -ToConsole
        Set-AxServerGroup -Group $GroupName
    }
}
else
{
    Write-Log "Installation failed with Exit Code $exitCode. Unable to set group. Please try again" $logFile -ToConsole -IsError
    Write-Error "Installation failed with Exit Code $exitCode. Unable to set group. Please try again"
    Exit 1
}

#endregion Operations
