param($jobId, $vmName, $vmsCount, $machinePassword, $templateFilePath, $initialSnapshotName)
. $PSScriptRoot\SharedScriptLib.ps1

Function New-InitialSnapshot ($SnapshotName, $vmName, $jobId )
{
    ## Verifies if the script snapshot exists, if not exists snapshot is created.
    IF ($SnapshotName -cnotin $(Get-VMSnapshot -VMName $vmName).Name)
    {
        New-LogEntry -LogValue "Creating VM Snap for VM ($VMName): $SnapshotName" -Component "run_job.ps1:$jobId" 
        $Scratch = Checkpoint-VM -Name $vmName -SnapshotName "$SnapshotName"
    }
    Else
    {
        New-LogEntry -LogValue "Snapshot ($SnapshotName) for VM ($VMName) already exists. " -Component "run_job.ps1:$jobId"
    }
}

Function Restore-InitialSnapshot ($SnapshotName, $vmName, $jobId )
{
    IF ($SnapshotName -in $(Get-VMSnapshot -VMName $vmName).Name)
    {
        New-LogEntry -LogValue "Reverting Virtual Machine to earlier snapshot ($initialSnapshotName)" -Component "run_job.ps1:$jobId"
        $Scratch = Restore-VMSnapshot -Name "$SnapshotName" -VMName $vmName -Confirm:$false
    }
}

$TemplateFile = [xml](get-content $($templateFilePath))
New-LogEntry -LogValue "JOB: $jobId - $($TemplateFile.MsixPackagingToolTemplate.PackageInformation.PackageDisplayName)" -Component "run_job.ps1:$jobId"

## Validates that the conversion machine is a Virtual Machine.
if ($vmName)
{
    ## Creates initial Snapshot of Virtual Machine.
    New-InitialSnapshot -SnapshotName $initialSnapshotName -vmName $vmName -jobId $jobId
}

## Reads the Template file, and logs which application is being attempted.
New-LogEntry -LogValue "Initiating capture of $($TemplateFile.MsixPackagingToolTemplate.PackageInformation.PackageDisplayName)." -Component "run_job.ps1:$jobId"

try
{
    ## Convert application to the MSIX Packaging format.
    $Scratch = foreach($Entry in $(MsixPackagingTool.exe create-package --template $templateFilePath --machinePassword $machinePassword))
        {
            $Entry + "`n`r"
        }
    New-LogEntry -LogValue "$Scratch" -Component "run_job.ps1:$jobId" -WriteHost $false
}
Catch{}

## Validates that the conversion machine is a Virtual Machine.
if ($vmName)
{
    ## Restores the VM to pre-app installation setting
    Restore-InitialSnapshot -SnapshotName $initialSnapshotName -vmName $vmName -jobId $jobId

    ## If this is a VM that can be re-used, release the global semaphore after creating a semaphore handle for this process scope
    $semaphore = New-Object -TypeName System.Threading.Semaphore -ArgumentList @($vmsCount, $vmsCount, "Global\MPTBatchConversion")
    $semaphore.Release()
    $semaphore.Dispose()
}

#Read-Host -Prompt 'Press any key to exit this window '
New-LogEntry -LogValue "Conversion of application ($($TemplateFile.MsixPackagingToolTemplate.PackageInformation.PackageDisplayName)) completed" -Component "run_job.ps1:$jobId"
