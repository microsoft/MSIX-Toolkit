param($jobId, $vmName, $vmsCount, $machinePassword, $templateFilePath, $initialSnapshotName, $ScriptRoot, $localMachine=$true, $workingDirectory="$PSScriptRoot\Out\Log")


#param(  [Parameter(Position=0)]$jobId, 
#        [Parameter(Position=1)]$vmName, 
#        [Parameter(Position=2)]$vmsCount, 
#        [Parameter(Position=3)]$machinePassword, 
#        [Parameter(Position=4)]$templateFilePath, 
#        [Parameter(Position=5)]$initialSnapshotName, 
#        [Parameter(Position=6)]$ScriptRoot, 
#        [Parameter(Position=7)]$localMachine=$true, 
#        [Parameter(Position=8)]$workingDirectory="$PSScriptRoot\Out\Log")

IF($PSScriptRoot)
{ . $PSScriptRoot\SharedScriptLib.ps1 }
Else
{ . $ScriptRoot\SharedScriptLib.ps1 }





Write-Host "    run_job.ps1" -ForegroundColor White -BackgroundColor Black
New-LogEntry -WriteHost $true -LogValue "#############`n`nJobID:  $jobId `nVMName:  $vmName `nVMCount:  $vmsCount `nMachinePassword:  $machinePassword `nTemplateFilePath:  $templateFilePath `nInitialSnapshotName:  $initialSnapshotName `nScriptRoot:  $ScriptRoot `nLocalMachine:  $localMachine `n`n#############" -Component "run_job.ps1:$($jobId+1)" -Path $workingDirectory

$Scratch = ""
$TemplateFile = [xml](get-content $($templateFilePath))
New-LogEntry -WriteHost $true -LogValue "JOB: $($jobId+1) - $($TemplateFile.MsixPackagingToolTemplate.PackageInformation.PackageDisplayName)" -Component "run_job.ps1:$($jobId+1)"

## Validates that the conversion machine is a Virtual Machine.
if ($vmName)
{
    ## Creates initial Snapshot of Virtual Machine.
    $Scratch = New-InitialSnapshot -SnapshotName $initialSnapshotName -vmName $vmName -jobId $jobId
}

## Reads the Template file, and logs which application is being attempted.
$Scratch +=  "`nInitiating capture of $($TemplateFile.MsixPackagingToolTemplate.PackageInformation.PackageDisplayName).`n"
New-LogEntry -WriteHost $true -LogValue "Initiating capture of $($TemplateFile.MsixPackagingToolTemplate.PackageInformation.PackageDisplayName)." -Component "run_job.ps1:$($jobId+1)" 

try
{

    #New-LogEntry -LogValue "MsixPackagingTool.exe create-package --template $templateFilePath --machinePassword $machinePassword" -Component "run_job.ps1:$($jobId+1)"
    ## Convert application to the MSIX Packaging format.

    #IF($machinePassword -eq "")
    IF($localMachine -eq $true)
    {
        New-LogEntry -WriteHost $true -LogValue "MsixPackagingTool.exe create-package --template $templateFilePath" -Component "run_job.ps1:$($jobId+1)"
        Write-Host "Password is Null"
        foreach($Entry in $(MsixPackagingTool.exe create-package --template $templateFilePath))
        {
            Write-host $Entry
            $Scratch += $Entry + "`n`r"
        }
    }
    else 
    {
        New-LogEntry -WriteHost $true -LogValue "MsixPackagingTool.exe create-package --template $templateFilePath --machinePassword $machinePassword" -Component "run_job.ps1:$($jobId+1)" 
        Write-Host "Password is not Null"
        foreach($Entry in $(MsixPackagingTool.exe create-package --template $templateFilePath --machinePassword $machinePassword))
        {
            Write-host $Entry
            $Scratch += $Entry + "`n`r"
        }
    }

    If ($Error)
        { New-LogEntry -LogValue "$Scratch" -Component "run_job.ps1:$($jobId+1)" -WriteHost $false -Severity 3  }
    Else
        { New-LogEntry -LogValue "$Scratch" -Component "run_job.ps1:$($jobId+1)" -WriteHost $false  }
    
}
Catch{}

## Validates that the conversion machine is a Virtual Machine.
if ($vmName)
{
    ## Restores the VM to pre-app installation setting
#    Restore-InitialSnapshot -SnapshotName $initialSnapshotName -vmName $vmName -jobId $($jobId+1)

    ## If this is a VM that can be re-used, release the global semaphore after creating a semaphore handle for this process scope
    $semaphore = New-Object -TypeName System.Threading.Semaphore -ArgumentList @($vmsCount, $vmsCount, "Global\MPTBatchConversion")
    $semaphore.Release()
    $semaphore.Dispose()
}

#Read-Host -Prompt 'Press any key to exit this window '
New-LogEntry -LogValue "Conversion of application ($($TemplateFile.MsixPackagingToolTemplate.PackageInformation.PackageDisplayName)) completed" -Component "run_job.ps1:$($jobId+1)" 

Return $Scratch