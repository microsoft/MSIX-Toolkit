param($jobId, $vmName, $vmsCount, $machinePassword, $templateFilePath, $initialSnapshotName)

write-host "JOB: $jobId"
try
{
    if ($vmName -and -not (Get-VMSnapshot -Name $initialSnapshotName -VMName $vmName -ErrorAction SilentlyContinue))
    {
        #Write-Host "Creating VM snapshot for $($vmName): $initialSnapshotName"
        #Checkpoint-VM -Name $vmName -SnapshotName "$initialSnapshotName"
    }

    MsixPackagingTool.exe create-package --template $templateFilePath --machinePassword $machinePassword

    if ($vmName)
    {
        #Checkpoint-VM -Name $vmName -SnapshotName "AfterMsixConversion_Job$jobId"
        #Write-Host "Creating VM snapshot for $($vmName): AfterMsixConversion_Job$jobId"
        #Restore-VMSnapshot -Name "$initialSnapshotName" -VMName $vmName -Confirm:$false
        #Write-Host "Restoring VM snapshot for $($vmName): $initialSnapshotName"
    }
}
finally
{
    # if this is a VM that can be re-used, release the global semaphore after creating a semaphore handle for this process scope
    if ($vmName)
    {
        $semaphore = New-Object -TypeName System.Threading.Semaphore -ArgumentList @($vmsCount, $vmsCount, "Global\MPTBatchConversion")
        $semaphore.Release()
        $semaphore.Dispose()
    }

    Read-Host -Prompt 'Press any key to exit this window '
}