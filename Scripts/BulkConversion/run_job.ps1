param($jobId, $vmName, $vmsCount, $machinePassword, $templateFilePath, $initialSnapshotName, $ScriptRoot)

IF($PSScriptRoot)
{ . $PSScriptRoot\SharedScriptLib.ps1 }
Else
{ . $ScriptRoot\SharedScriptLib.ps1 }

#Write-Host "#############`n`nJobID:  $jobId `nVMName:  $vmName `nVMCount:  $vmsCount `nMachinePassword:  $machinePassword `nTemplateFilePath:  $templateFilePath `nInitialSnapshotName:  $initialSnapshotName `nScriptRoot:  $ScriptRoot `n`n#############"

$Scratch = ""
$TemplateFile = [xml](get-content $($templateFilePath))
New-LogEntry -LogValue "JOB: $($jobId+1) - $($TemplateFile.MsixPackagingToolTemplate.PackageInformation.PackageDisplayName)" -Component "run_job.ps1:$($jobId+1)"

## Validates that the conversion machine is a Virtual Machine.
if ($vmName)
{
    ## Creates initial Snapshot of Virtual Machine.
    $Scratch = New-InitialSnapshot -SnapshotName $initialSnapshotName -vmName $vmName -jobId $jobId
}

## Reads the Template file, and logs which application is being attempted.
$Scratch +=  "`nInitiating capture of $($TemplateFile.MsixPackagingToolTemplate.PackageInformation.PackageDisplayName).`n"
New-LogEntry -LogValue "Initiating capture of $($TemplateFile.MsixPackagingToolTemplate.PackageInformation.PackageDisplayName)." -Component "run_job.ps1:$($jobId+1)"

try
{

    New-LogEntry -LogValue "MsixPackagingTool.exe create-package --template $templateFilePath --machinePassword $machinePassword" -Component "run_job.ps1:$($jobId+1)"
    ## Convert application to the MSIX Packaging format.
    foreach($Entry in $(MsixPackagingTool.exe create-package --template $templateFilePath --machinePassword $machinePassword))
    {
        Write-host $Entry
        $Scratch += $Entry + "`n`r"
    }

    If ($Error)
        { New-LogEntry -LogValue "$Scratch" -Component "run_job.ps1:$($jobId+1)" -WriteHost $false -Severity 3 }
    Else
        { New-LogEntry -LogValue "$Scratch" -Component "run_job.ps1:$($jobId+1)" -WriteHost $false }
    
}
Catch{}

## Validates that the conversion machine is a Virtual Machine.
if ($vmName)
{
    ## Restores the VM to pre-app installation setting
    Restore-InitialSnapshot -SnapshotName $initialSnapshotName -vmName $vmName -jobId $($jobId+1)

    ## If this is a VM that can be re-used, release the global semaphore after creating a semaphore handle for this process scope
    $semaphore = New-Object -TypeName System.Threading.Semaphore -ArgumentList @($vmsCount, $vmsCount, "Global\MPTBatchConversion")
    $semaphore.Release()
    $semaphore.Dispose()
}

#Read-Host -Prompt 'Press any key to exit this window '
New-LogEntry -LogValue "Conversion of application ($($TemplateFile.MsixPackagingToolTemplate.PackageInformation.PackageDisplayName)) completed" -Component "run_job.ps1:$($jobId+1)"
Return $Scratch