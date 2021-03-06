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
		[System.UInt64]
		$KeepLastNBackups
	)

	
	$returnValue = @{
		KeepLastNBackups = $KeepLastNBackups
	}

	$returnValue
	
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.UInt64]
		$KeepLastNBackups,

		[System.String]
		$TargetFolderPath = "G:\DPMDBBackup",

		[ValidateSet("MINUTE","HOURLY","DAILY","WEEKLY","MONTHLY","ONCE","ONLOGON","ONIDLE","ONEVENT")]
		[System.String]
		$ScheduleFrequency = "HOURLY",

		[System.UInt64]
		$ScheduleRecurrence = 4
	)

    #Create DPMDB backup script and schedule it.   
    $installPath      = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup" "InstallPath").InstallPath
    $dpmdbbackupFile  = Join-Path $installPath "bin\BackupDPMDB.ps1"
    $dbschedfile      = Join-Path $installPath "bin\DBBackupSched.cmd"
    del $dpmdbbackupFile -ErrorAction SilentlyContinue
    del $dbschedfile -ErrorAction SilentlyContinue

    #First create PS1 file to take DB backup

    "`$numfiles = $KeepLastNBackups" > $dpmdbbackupFile
    "`$sqlServerName = (Get-ItemProperty `"HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\DB`" `"SqlServer`").SqlServer" >> $dpmdbbackupFile
    "`$sqlInstanceName = (Get-ItemProperty `"HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\DB`" `"InstanceName`").InstanceName" >> $dpmdbbackupFile
    "`$dbName = (Get-ItemProperty `"HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\DB`" `"DatabaseName`").DatabaseName" >> $dpmdbbackupFile
	"IF(!(Test-Path `""+$TargetFolderPath+"`"))" >> $dpmdbbackupFile
	"{" >> $dpmdbbackupFile
	"`tNew-Item $TargetFolderPath -ItemType Directory" >> $dpmdbbackupFile
	"}" >> $dpmdbbackupFile
    "`$filesig = `"$TargetFolderPath\`" + `"`$dbName`" + `"_`"" >> $dpmdbbackupFile
    "for (`$i = 0; `$i -lt `$numfiles; `$i++)" >> $dpmdbbackupFile
    "{" >> $dpmdbbackupFile
    "`t`$oldfile = `$filesig + `$i + `".bak`"" >> $dpmdbbackupFile
    "`t`$newfile = `$filesig + (`$i+1) + `".bak`"" >> $dpmdbbackupFile
    "" >> $dpmdbbackupFile
    "`tif ((Test-Path `$oldfile) -and (Test-Path `$newfile))" >> $dpmdbbackupFile
    "`t{" >> $dpmdbbackupFile
    "`t`tdel `$oldfile" >> $dpmdbbackupFile
    "`t}" >> $dpmdbbackupFile
    "" >> $dpmdbbackupFile
    "`tif (Test-Path `$newfile)" >> $dpmdbbackupFile
    "`t{" >> $dpmdbbackupFile
    "`t`tmove `$newfile `$oldfile" >> $dpmdbbackupFile
    "`t}" >> $dpmdbbackupFile
    "}" >> $dpmdbbackupFile
    "" >> $dpmdbbackupFile
    "`$latestfile = `$filesig + (`$numfiles-1) + `".bak`"" >> $dpmdbbackupFile
    "`$installPath = (Get-ItemProperty `"HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup`" `"InstallPath`").InstallPath" >> $dpmdbbackupFile    
    "`$targetLocation = Join-Path `$installPath `"Temp`"" >> $dpmdbbackupFile    
    "`$DbBackupFile = `$targetLocation + `"\`" + `$dbName + `".bak`"" >> $dpmdbbackupFile
    "`$sqlInstance = `$sqlServerName+ `"\`" + `$sqlInstanceName"  >> $dpmdbbackupFile
    "Backup-SqlDatabase -ServerInstance `$sqlInstance -Database `$dbName -BackupFile `$DbBackupFile"  >> $dpmdbbackupFile
    "`$latestfile = `$filesig + (`$numfiles-1) + `".bak`"" >> $dpmdbbackupFile    
    "move `$DbBackupFile `$latestfile" >> $dpmdbbackupFile

    #Create schedule cmd file
    $dbschedfile = $installPath + "bin\DBBackupSched.cmd"
    $binPath = $installPath + "bin"
    "@echo off" | Out-File -FilePath $dbschedfile -Encoding "ASCII"
    "cd $binPath" | Out-File -FilePath $dbschedfile -Encoding "ASCII" -Append
    "@PowerShell -NonInteractive -NoProfile -ExecutionPolicy Unrestricted -Command `"& {./BackupDPMDB.ps1; exit `$LastExitCode }`"" | Out-File -FilePath $dbschedfile -Encoding "ASCII" -Append
    "exit /B %errorlevel%" | Out-File -FilePath $dbschedfile -Encoding "ASCII" -Append

    #Create Schedule
    cmd.exe /c "schtasks /create /sc $ScheduleFrequency /mo $ScheduleRecurrence /tn ""DPMDB Backup"" /tr `"$dbschedfile`" /F /RL HIGHEST /RU SYSTEM"

}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.UInt64]
		$KeepLastNBackups,

		[System.String]
		$TargetFolderPath = "G:\DPMDBBackup",

		[ValidateSet("MINUTE","HOURLY","DAILY","WEEKLY","MONTHLY","ONCE","ONLOGON","ONIDLE","ONEVENT")]
		[System.String]
		$ScheduleFrequency = "HOURLY",

		[System.UInt64]
		$ScheduleRecurrence = 4
	)

	
	$result = $false
	
	$result
	
}


Export-ModuleMember -Function *-TargetResource

