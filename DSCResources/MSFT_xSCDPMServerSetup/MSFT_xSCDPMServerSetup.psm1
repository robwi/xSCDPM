$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Debug -Message "CurrentPath: $currentPath"

# Load Common Code
Import-Module $currentPath\..\..\xSCDPMHelper.psm1 -Verbose:$false -ErrorAction Stop

function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[System.String]
		$SourcePath = "$PSScriptRoot\..\..\",

		[System.String]
		$SourceFolder = "Source",

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$SetupCredential,

		[System.Management.Automation.PSCredential]
		$SourceCredential,

		[System.Boolean]
		$SuppressReboot,

		[System.Boolean]
		$ForceReboot,

		[System.String]
		$UserName,

		[System.String]
		$CompanyName,

		[System.String]
		$ProductKey,

		[System.String]
		$ProgramFiles,

		[parameter(Mandatory = $true)]
		[System.String]
		$YukonMachineName,

		[parameter(Mandatory = $true)]
		[System.String]
		$YukonInstanceName,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$YukonMachineCredential,

		[parameter(Mandatory = $true)]
		[System.String]
		$ReportingMachineName,

		[parameter(Mandatory = $true)]
		[System.String]
		$ReportingInstanceName,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$ReportingMachineCredential
	)

    Import-Module $PSScriptRoot\..\..\xPDT.psm1
        
    if($SourceCredential)
    {
        NetUse -SourcePath $SourcePath -Credential $SourceCredential -Ensure "Present"
    }
    $Path = Join-Path -Path (Join-Path -Path $SourcePath -ChildPath $SourceFolder) -ChildPath "SCDPM\setup.exe"
    if(!(Test-Path -Path $Path))
    {
        $Path = Join-Path -Path (Join-Path -Path $SourcePath -ChildPath $SourceFolder) -ChildPath "setup.exe"
    }
    $Path = ResolvePath $Path
    $Version = (Get-Item -Path $Path).VersionInfo.ProductVersion
    if($SourceCredential)
    {
        NetUse -SourcePath $SourcePath -Credential $SourceCredential -Ensure "Absent"
    }

    $IdentifyingNumber = GetxPDTVariable -Component "SCDPM" -Version $Version -Role "Server" -Name "IdentifyingNumber"
    Write-Verbose "IdentifyingNumber is $IdentifyingNumber"

    if($IdentifyingNumber -and (Get-WmiObject -Class Win32_Product | Where-Object {$_.IdentifyingNumber -eq $IdentifyingNumber}))
    {
	    $UserName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup" -Name "RegisteredUserName").RegisteredUserName
        $CompanyName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup" -Name "RegisteredOrgName").RegisteredOrgName
		$ProgramFiles = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup" -Name "InstallPath").InstallPath
		$YukonMachineName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\DB" -Name "SqlServer").SqlServer
		$YukonInstanceName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\DB" -Name "InstanceName").InstanceName
		$ReportingMachineName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\DB" -Name "ReportingServer").ReportingServer
		$ReportingInstanceName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\DB" -Name "ReportingInstanceName").ReportingInstanceName

        $returnValue = @{
		    Ensure = "Present"
		    SourcePath = $SourcePath
		    SourceFolder = $SourceFolder
		    UserName = $UserName
		    CompanyName = $CompanyName
		    ProgramFiles = $ProgramFiles
		    YukonMachineName = $YukonMachineName
		    YukonInstanceName = $YukonInstanceName
		    ReportingMachineName = $ReportingMachineName
		    ReportingInstanceName = $ReportingInstanceName
	    }
    }
    else
    {
	    $returnValue = @{
		    Ensure = "Absent"
		    SourcePath = $SourcePath
		    SourceFolder = $SourceFolder
	    }
    }

	$returnValue
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[System.String]
		$SourcePath = "$PSScriptRoot\..\..\",

		[System.String]
		$SourceFolder = "Source",

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$SetupCredential,

		[System.Management.Automation.PSCredential]
		$SourceCredential,

		[System.Boolean]
		$SuppressReboot,

		[System.Boolean]
		$ForceReboot,

		[System.String]
		$UserName = "UserName",

		[System.String]
		$CompanyName = "CompanyName",

		[System.String]
		$ProductKey,

		[System.String]
		$ProgramFiles,

		[parameter(Mandatory = $true)]
		[System.String]
		$YukonMachineName,

		[parameter(Mandatory = $true)]
		[System.String]
		$YukonInstanceName,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$YukonMachineCredential,

		[parameter(Mandatory = $true)]
		[System.String]
		$ReportingMachineName,

		[parameter(Mandatory = $true)]
		[System.String]
		$ReportingInstanceName,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$ReportingMachineCredential
	)

    Import-Module $PSScriptRoot\..\..\xPDT.psm1

    if($SourceCredential)
    {
        NetUse -SourcePath $SourcePath -Credential $SourceCredential -Ensure "Present"
        $TempFolder = [IO.Path]::GetTempPath()
        & robocopy.exe (Join-Path -Path $SourcePath -ChildPath $SourceFolder) (Join-Path -Path $TempFolder -ChildPath $SourceFolder) /e
        $SourcePath = $TempFolder
        NetUse -SourcePath $SourcePath -Credential $SourceCredential -Ensure "Absent"
    }
    $Path = Join-Path -Path (Join-Path -Path $SourcePath -ChildPath $SourceFolder) -ChildPath "SCDPM\setup.exe"
    if(!(Test-Path -Path $Path))
    {
        $Path = Join-Path -Path (Join-Path -Path $SourcePath -ChildPath $SourceFolder) -ChildPath "setup.exe"
    }
    $Path = ResolvePath $Path

    $Version = (Get-Item -Path $Path).VersionInfo.ProductVersion

    if ($PSBoundParameters.ContainsKey("ProgramFiles") -and (!($ProgramFiles -contains "%ProgramFiles%")))
    {
        $ProgramFiles = $ProgramFiles.Replace("\Microsoft System Center 2012 R2\DPM","")
    }
    else
    {
        $ProgramFiles = [Environment]::ExpandEnvironmentVariables($ProgramFiles)
    }
    if($PSBoundParameters.ContainsKey("ProductKey"))
    {
        $autorun = Get-Content (Join-Path -Path (Join-Path -Path $SourcePath -ChildPath $SourceFolder) -ChildPath "autorun.inf")
        if ($autorun -contains "sku=evaluation")
        {
            throw New-TerminatingError -ErrorType EvaluationCopyNotAllowed -ErrorCategory PermissionDenied
        }
    }
    $TempFile = [IO.Path]::GetTempFileName()
    $INIFile = @()
    $INIFile += "[Options]"
    $INIFileVars = @(
        "UserName",
        "CompanyName",
        "ProductKey",
        "ProgramFiles",
        "YukonInstanceName",
        "ReportingInstanceName"
    )
    foreach($INIFileVar in $INIFileVars)
    {
        if((Get-Variable -Name $INIFileVar).Value -ne "")
        {
            $INIFile += "$INIFileVar=" + (Get-Variable -Name $INIFileVar).Value
        }
    }
    $INIFileVars = @(
        "YukonMachineName",
        "ReportingMachineName"
    )
    foreach($INIFileVar in $INIFileVars)
    {
        if((Get-Variable -Name $INIFileVar).Value -ne "")
        {
            $INIFile += "$INIFileVar=" + (Get-Variable -Name $INIFileVar).Value.Split(".")[0]
        }
    }
    $AccountVars = @("YukonMachineCredential","ReportingMachineCredential")
    foreach($AccountVar in $AccountVars)
    {
        $INIFile += $AccountVar.Replace("Credential","UserName") + "=" + (Get-Variable -Name $AccountVar).Value.GetNetworkCredential().UserName
        $INIFile += $AccountVar.Replace("Credential","Password") + "=" + (Get-Variable -Name $AccountVar).Value.GetNetworkCredential().Password
        $INIFile += $AccountVar.Replace("Credential","DomainName") + "=" + (Get-Variable -Name $AccountVar).Value.GetNetworkCredential().Domain
    }
    Write-Verbose "INIFile: $TempFile"
    foreach($Line in $INIFile)
    {
        Add-Content -Path $TempFile -Value $Line -Encoding Ascii
        # Replace sensitive values for verbose output
        $LogLine = $Line
        if($ProductKey -ne "")
        {
            $LogLine = $LogLine.Replace($ProductKey,"*****-*****-*****-*****-*****")
        }
        $LogVars = @("YukonMachineCredential","ReportingMachineCredential")
        foreach($LogVar in $LogVars)
        {
            if((Get-Variable -Name $LogVar).Value -ne "")
            {
                $LogLine = $LogLine.Replace((Get-Variable -Name $LogVar).Value.GetNetworkCredential().Password,"********")
            }
        }
        Write-Verbose $LogLine
    }

    switch($Ensure)
    {
        "Present"
        {
            $Arguments = "/i /f $TempFile /q"
        }
        "Absent"
        {
            $Arguments = "/x /f $TempFile /q"
        }
    }

    Write-Verbose "Path: $Path"
    Write-Verbose "Arguments: $Arguments"

    $Process = StartWin32Process -Path $Path -Arguments $Arguments -Credential $SetupCredential
    Write-Verbose $Process
    WaitForWin32ProcessEnd -Path $Path -Arguments $Arguments -Credential $SetupCredential

    Remove-Item $TempFile

    if($ForceReboot -or ((Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue) -ne $null))
    {
	    if(!($SuppressReboot))
        {
            $global:DSCMachineStatus = 1
        }
        else
        {
            Write-Verbose "Suppressing reboot"
        }
    }

    if(!(Test-TargetResource @PSBoundParameters))
    {
        throw New-TerminatingError -ErrorType TestFailedAfterSet -ErrorCategory InvalidResult
    }
}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[System.String]
		$SourcePath = "$PSScriptRoot\..\..\",

		[System.String]
		$SourceFolder = "Source",

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$SetupCredential,

		[System.Management.Automation.PSCredential]
		$SourceCredential,

		[System.Boolean]
		$SuppressReboot,

		[System.Boolean]
		$ForceReboot,

		[System.String]
		$UserName,

		[System.String]
		$CompanyName,

		[System.String]
		$ProductKey,

		[System.String]
		$ProgramFiles,

		[parameter(Mandatory = $true)]
		[System.String]
		$YukonMachineName,

		[parameter(Mandatory = $true)]
		[System.String]
		$YukonInstanceName,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$YukonMachineCredential,

		[parameter(Mandatory = $true)]
		[System.String]
		$ReportingMachineName,

		[parameter(Mandatory = $true)]
		[System.String]
		$ReportingInstanceName,

		[parameter(Mandatory = $true)]
		[System.Management.Automation.PSCredential]
		$ReportingMachineCredential
	)

	$result = ((Get-TargetResource @PSBoundParameters).Ensure -eq $Ensure)

	$result
}


Export-ModuleMember -Function *-TargetResource