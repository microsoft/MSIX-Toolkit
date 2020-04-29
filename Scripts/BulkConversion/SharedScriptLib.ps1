Function New-LogEntry
{
Param(
    [Parameter(Position=0)] [string]  $LogValue,
    [Parameter(Position=1)] [string]  $Component = "",
    [Parameter(Position=2)] [int]     $Severity  = 1,
    [Parameter(Position=3)] [boolean] $WriteHost = $true,
                            [string]  $Path      = $($PSScriptRoot + "\Log")
)
    IF(!(Test-path -Path $Path)) {$Scratch = mkdir $Path}
    $Error.Clear()

    #Formats the values required to enter for Trace32 Format
    #$TimeZoneBias = Get-WmiObject -Query "Select Bias from Win32_TimeZone"
    [string]$Time = Get-Date -Format "HH:mm:ss.ffff"
    [string]$Date = Get-Date -Format "MM-dd-yyyy"

    #Appends the newest log entry to the end of the log file in a Trace32 Formatting
    $('<![LOG['+$LogValue+']LOG]!><time="'+$Time+'" date="'+$Date+'" component="'+$component+'" context="Empty" type="'+$severity+'" thread="Empty" file="'+"Empty"+'">') | out-file -FilePath $($Path+"\BulkConversion.log") -Append -NoClobber -encoding default -ErrorAction SilentlyContinue -ErrorVariable LogError

    ## If Writing to log file fails try again.
    While ($Error.count -gt 0)
    {
        ## Gives a random amount of time to wait until next write attempt.
        $Error.Clear()
        Sleep($(get-random -Maximum 0.5 -Minimum 0.0))

        #$('<![LOG['+$LogError+']LOG]!><time="'+$Time+'" date="'+$Date+'" component="'+$component+'" context="Empty" type="'+3+'" thread="Empty" file="'+"Empty"+'">') | out-file -FilePath $($Path+"\BulkConversion.log") -Append -NoClobber -encoding default -ErrorAction SilentlyContinue -ErrorVariable LogError

        #Appends the newest log entry to the end of the log file in a Trace32 Formatting
        $('<![LOG['+$LogValue+']LOG]!><time="'+$Time+'" date="'+$Date+'" component="'+$component+'" context="Empty" type="'+$severity+'" thread="Empty" file="'+"Empty"+'">') | out-file -FilePath $($Path+"\BulkConversion.log") -Append -NoClobber -encoding default -ErrorAction SilentlyContinue -ErrorVariable LogError
    }

    IF($WriteHost)
    {
        Write-Host $("" + $LogValue) -ForegroundColor $(switch ($Severity) {1 {"White"} 2 {"Yellow"} 3 {"Red"}})
    }
}
Function New-InitialSnapshot ($SnapshotName, $VMName, $jobId="" )
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

Function Restore-InitialSnapshot ($SnapshotName, $VMName, $jobId="" )
{
    IF ($SnapshotName -in $(Get-VMSnapshot -VMName $vmName).Name)
    {
        New-LogEntry -LogValue "Reverting Virtual Machine to earlier snapshot ($initialSnapshotName)" -Component "run_job.ps1:$jobId"
        $Scratch = Restore-VMSnapshot -Name "$SnapshotName" -VMName $vmName -Confirm:$false
    }
}

Function Set-JobProgress ($ConversionJobs, $TotalTasks)
{
    foreach ($job in $ConversionJobs)
    {
        If($job.State -ne "Running")
            { Write-Progress -ID $job.id -Activity $job.Name -Completed -ParentID 0 }
        Else
            { Write-Progress -ID $job.id -Activity $job.Name -PercentComplete -1 -ParentID 0 }
    }

    $RunningJobs = $($($ConversionJobs | where-object State -eq "Running").count)/2
    $CompletedJobs = $($($ConversionJobs | where-object State -ne "Running").count)

    If($($ConversionJobs | Where-object State -ne "Running").Count -eq $TotalTasks)
        { Write-Progress -ID 0 -Status "Completed" -Completed -Activity "Capture" }
    Else
        { Write-Progress -ID 0 -Status "Converting Applications..." -PercentComplete $($($($RunningJobs + $CompletedJobs)/$TotalTasks)*100) -Activity "Capture" }
}