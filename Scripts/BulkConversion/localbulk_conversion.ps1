param($_JobId, $VMName, $VMCount, $_password, $RemoteTemplateFilePath, $initialSnapshotName, $RemoteScriptRoot, $Var2, $RemoteTemplateParentDir, $runJobScriptPath, $objxmlContent, $workingDirectory, $remoteMachines)
#      $_JobId, "",      0,        $_password, $RemoteTemplateFilePath, $initialSnapshotName, $RemoteScriptRoot, $true, $RemoteTemplateParentDir

Function New-LogEntry
{
Param(
    [Parameter(Position=0)] [string]  $LogValue,
    [Parameter(Position=1)] [string]  $Component = "",
    [Parameter(Position=2)] [int]     $Severity  = 1,
    [Parameter(Position=3)] [boolean] $WriteHost = $true,
                            [string]  $Path      = $("C:\Temp\Log")
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
#Write-Host "PSDrive (Scripting):  $(Get-PSDrive -Name Scripting)"
Write-Host "`n    LOCALBULK_Conversion.ps1" -ForegroundColor White -BackgroundColor Black

## Updates the Network Connection Profiles to Private Network
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private -ErrorVariable Err -InformationAction Info

IF($null -ne $Err)
    { New-LogEntry -LogValue "Updating NetConnection Profile: Failed`n`n$Err" -Severity 3 -Component "localbulk_conversion" }
ElseIF($null -ne $Info)
    { New-LogEntry -LogValue "Updating NetConnection Profile: Success`n`n$Info" -Severity 3 -Component "localbulk_conversion" }

$Err  = $null
$Info = $null

#### Create method to enable -PSRemoting.
Enable-PSRemoting -Force -ErrorVariable $Err -InformationAction $Info

IF($null -ne $Err)
    { New-LogEntry -LogValue "Enabling PS Remoting: Failed`n`n$Err" -Severity 3 -Component "localbulk_conversion" }
ElseIF($null -ne $Info)
    { New-LogEntry -LogValue "Enabling PS Remoting: Success`n`n$Info" -Severity 3 -Component "localbulk_conversion" }

$Err  = $null
$Info = $null



$jobId                  = $_JobId
$vmName                 = $VMName
$vmsCount               = $VMCount
$machinePassword        = $_password
$templateFilePath       = $RemoteTemplateFilePath
$initialSnapshotName    = $initialSnapshotName
$ScriptRoot             = $RemoteScriptRoot
$localMachine           = $true
$workingDirectory       = "$PSScriptRoot\Out\Log"
$objVerbose             = $false

#Write-Host "`n    run_job.ps1" -ForegroundColor White -BackgroundColor Black
#New-LogEntry -WriteHost $true -LogValue "    #############`n`nJobID:  $jobId `nVMName:  $vmName `nVMCount:  $vmsCount `nMachinePassword:  $machinePassword `nTemplateFilePath:  $templateFilePath `nInitialSnapshotName:  $initialSnapshotName `nScriptRoot:  $ScriptRoot `nLocalMachine:  $localMachine `n`n#############" -Component "run_job.ps1:$($jobId)" -Path $workingDirectory

New-LogEntry -WriteHost $objVerbose -LogValue "    Variables:`n        - JobID:                $jobId `n        - VMName:               $vmName `n        - VMCount:              $vmsCount `n        - MachinePassword:      $machinePassword `n        - TemplateFilePath:     $templateFilePath `n        - InitialSnapshotName:  $initialSnapshotName `n        - ScriptRoot:           $ScriptRoot `n        - LocalMachine:         $localMachine `n" -Component "run_job.ps1:$($jobId)"

$Scratch = ""
$TemplateFile = [xml](get-content $($templateFilePath))
New-LogEntry -WriteHost $objVerbose -LogValue "    JOB: $($jobId) - $($TemplateFile.MsixPackagingToolTemplate.PackageInformation.PackageDisplayName)" -Component "run_job.ps1:$($jobId)"

## Validates that the conversion machine is a Virtual Machine.
if ($vmName)
{
    ## Creates initial Snapshot of Virtual Machine.
    $Scratch = New-InitialSnapshot -SnapshotName $initialSnapshotName -vmName $vmName -jobId $jobId
}

## Reads the Template file, and logs which application is being attempted.
$Scratch +=  "`nInitiating capture of $($TemplateFile.MsixPackagingToolTemplate.PackageInformation.PackageDisplayName).`n"
New-LogEntry -WriteHost $objVerbose -LogValue "    Initiating capture of $($TemplateFile.MsixPackagingToolTemplate.PackageInformation.PackageDisplayName)." -Component "run_job.ps1:$($jobId)"
$ConversionLog = @()

try
{

    #New-LogEntry -LogValue "MsixPackagingTool.exe create-package --template $templateFilePath --machinePassword $machinePassword" -Component "run_job.ps1:$($jobId)"
    ## Convert application to the MSIX Packaging format.

    #IF($machinePassword -eq "")
    IF($localMachine -eq $true)
    {
        New-LogEntry -WriteHost $objVerbose -LogValue "    MsixPackagingTool.exe create-package --template $templateFilePath" -Component "run_job.ps1:$($jobId)"
        #Write-Host "Password is Null"
        foreach($Entry in $(MsixPackagingTool.exe create-package --template $templateFilePath))
        {
            #Write-host $Entry
            #$ConversionLog += $Entry + "`n`r"
            $ConversionLog += $Entry
        }
    }
    else 
    {
        New-LogEntry -WriteHost $objVerbose -LogValue "    MsixPackagingTool.exe create-package --template $templateFilePath --machinePassword $machinePassword" -Component "run_job.ps1:$($jobId)" 
        #Write-Host "Password is not Null"
        foreach($Entry in $(MsixPackagingTool.exe create-package --template $templateFilePath --machinePassword $machinePassword))
        {
            #Write-host $Entry
            #$ConversionLog += $Entry + "`n`r"
            $ConversionLog += $Entry
        }
    }

    $objErrorCapturing = $false
    If ($Error)
    { 
        New-LogEntry -LogValue "    $($ConversionLog | ForEach-Object{$_ + "`n`r"})" -Component "run_job.ps1:$($jobId)" -WriteHost $objVerbose -Severity 3
        $objErrorCapturing = $true
    }
    Else
        { New-LogEntry -LogValue "    $($ConversionLog | ForEach-Object{$_ + "`n`r"})" -Component "run_job.ps1:$($jobId)" -WriteHost $objVerbose  }
    
}
Catch{}

## Validates that the conversion machine is a Virtual Machine.
if ($vmName)
{
    ## Restores the VM to pre-app installation setting
#    Restore-InitialSnapshot -SnapshotName $initialSnapshotName -vmName $vmName -jobId $($jobId)

    ## If this is a VM that can be re-used, release the global semaphore after creating a semaphore handle for this process scope
    $semaphore = New-Object -TypeName System.Threading.Semaphore -ArgumentList @($vmsCount, $vmsCount, "Global\MPTBatchConversion")
    $semaphore.Release()
    $semaphore.Dispose()
}

#Read-Host -Prompt 'Press any key to exit this window '
$ConversionLogPath = $($($($ConversionLog.Where({$_ -like "Log file is located under: *"})).Replace("Log file is located under: ", "")).Replace("%UserProfile%", "$env:USERPROFILE"))
Copy-Item $ConversionLogPath -Destination "\\MSGenesis\Temp\Log\JobID$JobID.log"

#New-LogEntry -LogValue "    Conversion Log:`n $ConversionLog" -Severity 1 -Component "run_job.ps1:$($jobId)"
New-LogEntry -LogValue "    Conversion Log Path:  $ConversionLogPath" -Severity 1 -Component "run_job.ps1:$($jobId)"
$ConversionLogContent = Get-Content $ConversionLogPath

#New-LogEntry -LogValue "    RPM Says" -Severity 2 -Component "run_job.ps1:$($JobID)"
#New-LogEntry -LogValue "    ROY SAYS: App Conversion Log:`n$ConversionLogContent" -Severity 1 -Component "run_job.ps1:$($jobId)" 

IF($objErrorCapturing)
{ 
    New-LogEntry -LogValue "    App Conversion Log:`n$ConversionLogContent" -Severity 3 -Component "run_job.ps1:$($jobId)" 
    New-LogEntry -LogValue "    $($ConversionLogContent.Where({$_ -like "*ERROR*"}))" -Severity 3 -Component "run_job.ps1:$($jobId)"
    Throw "    $($ConversionLogContent.Where({$_ -like "*ERROR*"}))" 
}
else 
{
    New-LogEntry -LogValue "    App Conversion Log:`n$ConversionLogContent" -Severity 1 -Component "run_job.ps1:$($jobId)" 
    New-LogEntry -LogValue "    Conversion of application ($($TemplateFile.MsixPackagingToolTemplate.PackageInformation.PackageDisplayName)) completed" -Severity 1 -Component "run_job.ps1:$($jobId)" 
}

Return $Scratch