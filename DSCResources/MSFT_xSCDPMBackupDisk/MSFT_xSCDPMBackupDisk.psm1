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
		[ValidateSet("Attached","Detached")] 
		[System.String]
		$Ensure
	)

	Set-StorageSetting -NewDiskPolicy OnlineAll -ErrorAction Continue
	$disks = Get-Disk | ?{$_.IsBoot -eq $false -and $_.NumberOfPartitions -le 1}
	foreach($disk in $disks)
	{
		if($disk.IsReadOnly)
		{
			Set-Disk -Number $disk.Number -IsReadOnly $false
		}
		if($disk.IsOffline)
		{
			Set-Disk -Number $disk.Number -IsOffline $false
		}
	}

    Start-Sleep -Seconds 10

    $DPMDisks = @()
	$retryCount = 0;
	while (($DPMDisks.Length -eq 0) -and ($retryCount -lt 5))
	{ 
        $DPMDisks = Get-DPMDisk -DPMServerName $env:computername 
		$retryCount++
		Start-Sleep -Seconds 5
	}        
    
    $CurrentState = "Detached"
    $DisksAttached = ($DPMDisks | ? {$_.IsInStoragePool -eq $True})
    $AttachableDisks = ($DPMDisks | ? {$_.CanAddToStoragePool -eq $true -and $_.IsInStoragePool -eq $false -and $_.HasData -eq $false})
    
    if( ($DisksAttached.Length -gt 0) -and  ($AttachableDisks.Length -eq 0) )
    {
        $CurrentState = 'Attached'
    }
    elseif(($DisksAttached.Length -gt 0) -and  ($AttachableDisks.Length -gt 0) )
    {
        $CurrentState = 'SomeAttached' #This intermediate state is used only in code
    }

	
	$returnValue = @{
		Ensure = $CurrentState        
	}

	$returnValue
	
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[ValidateSet("Attached","Detached")]
		[System.String]
		$Ensure
	)
    
    Set-StorageSetting -NewDiskPolicy OnlineAll -ErrorAction Continue
	$disks = Get-Disk | ?{$_.IsBoot -eq $false -and $_.NumberOfPartitions -le 1}
	foreach($disk in $disks)
	{
		if($disk.IsReadOnly)
		{
			Set-Disk -Number $disk.Number -IsReadOnly $false
		}
		if($disk.IsOffline)
		{
			Set-Disk -Number $disk.Number -IsOffline $false
		}
	}
	foreach($disk in $disks)
	{
		if ($disk.PartitionStyle -eq "RAW")
		{
			Write-Verbose -Message "Initializing disk number '$($DiskNumber)'..."

			$disk | Initialize-Disk -PartitionStyle GPT -PassThru     
			Write-Verbose -Message "Successfully initialized disk number $DiskNumber."  
		}
	}

	$DPMDisks = @()
	$retryCount = 0;
	while (($DPMDisks.Length -eq 0) -and ($retryCount -lt 5))
	{ 	
		Start-Sleep -Seconds 15
        $DPMDisks = Get-DPMDisk -DPMServerName $env:computername 
		$retryCount++		
	}        
	  

    $DisksAttached = ($DPMDisks | ? {$_.IsInStoragePool -eq $True})
    $AttachableDisks = ($DPMDisks | ? {$_.CanAddToStoragePool -eq $true -and $_.IsInStoragePool -eq $false -and $_.HasData -eq $false})
    

	if($Ensure -eq "Attached")
    {   
		Add-DPMDisk $AttachableDisks
    }
    else
    {
		Remove-DPMDisk -DPMDisk $DisksAttached
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
		[ValidateSet("Attached","Detached")]
		[System.String]
		$Ensure
	)

	$result = ((Get-TargetResource @PSBoundParameters).Ensure -eq $Ensure)
	Write-Verbose "Test-TargetResource: Result $result" -Verbose
    $result
}


Export-ModuleMember -Function *-TargetResource

