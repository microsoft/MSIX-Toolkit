param($_JobId, $VMName, $VMCount, $_password, $RemoteTemplateFilePath, $initialSnapshotName, $RemoteScriptRoot, $Var2, $RemoteTemplateParentDir, $runJobScriptPath, $objxmlContent, $workingDirectory, $remoteMachines)
#      $_JobId, "",      0,        $_password, $RemoteTemplateFilePath, $initialSnapshotName, $RemoteScriptRoot, $true, $RemoteTemplateParentDir

Function New-LogEntry
{
Param(
    [Parameter(Position=0)] [string]  $LogValue,
    [Parameter(Position=1)] [string]  $Component = "",
    [Parameter(Position=2)] [int]     $Severity  = 1,
    [Parameter(Position=3)] [boolean] $WriteHost = $true,
                            [string]  $Path      = $("\\MSGenesis\Temp\Log")
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

$whoamI = whoami.exe
Write-Host "    Connected to: $($(gwmi -namespace root\cimv2 -class win32_computersystem -Property Name).Name)"
Write-Host "    Connected as: $whoamI"
#Write-Host "    Permissions:  `n$(whoami /priv)"

#Write-Host "    Validating if a new PS Drive will be created..."
#IF($null -eq $(Get-PSDrive -Name "Scripting" -ErrorAction SilentlyContinue))
#{
#    Write-Host "    Creating a new PSDrive"
#    $Scratch = New-PSDrive -Root "C:\Temp" -PSProvider FileSystem -Name "Scripting" -ErrorAction SilentlyContinue -InformationAction SilentlyContinue
#}
#$Scratch = New-PSDrive -Root "\\MSGenesis\Temp" -PSProvider FileSystem -Name "Scripting" -ErrorAction SilentlyContinue -InformationAction SilentlyContinue

#Write-Host "PSDrive (Scripting):  $(Get-PSDrive -Name Scripting)"

#mkdir $RemoteTemplateParentDir
#Write-Host "    New-Item $RemoteTemplateParentDir"
#New-Item $RemoteTemplateParentDir -Force

#Write-Host "Set-Content -Value $objxmlContent -Path $RemoteTemplateFilePath -Force" -ForegroundColor Black -BackgroundColor Yellow
#$Scratch = Set-Content -Value $objxmlContent -Path $RemoteTemplateFilePath -Force

#Write-Host "Try Harder..."

#New-PSDrive -Name "Scripting" -PSProvider FileSystem -Root "\\DESKTOP-RUGEAND\Temp"

#Write-Host "        - Something:                $RemoteTemplateFilePath"
#Write-Host "        - JobID:                    $_JobId`n        - VMName:                   $VMName`n        - VMCount:                  $VMCount`n        - Password:                 $_password`n        - RemoteTemplate FilePath:  $RemoteTemplateFilePath`n        - SnapshotName:             $initialSnapshotName`n        - RemoteScriptRoot:         $RemoteScriptRoot`n        - Var2:                     $Var2`n        - RemoteTemp ParentDir:     $RemoteTemplateParentDir`n        - RemoteTemp FilePath:      $RemoteTemplateFilePath`n"

#$whoamI = $(Invoke-Command -RunAsAdministrator C:\Temp\whoami.ps1 -ContainerId Var)
#$whoamI = whoami.exe

#Write-Host "    Creating new folder:            $WorkingDirectory"
#$Scratch = New-Item $workingDirectory

#Write-Host "    Configuring the Execution Policy"
#Set-ExecutionPolicy Bypass -Force

#Invoke-Command -RunAsAdministrator -ContainerId Var -ScriptBlock(whoami.exe)

#Write-Host "    ""$_JobId"" ""$VMName"" ""$VMCount"" ""$_password"" ""$RemoteTemplateFilePath"" ""$initialSnapshotName"" ""$RemoteScriptRoot"" ""$Var2"""

#Write-Host "    Running Conversion job on local VM."
#Write-Host "    Invoke-Command -FilePath ""$runJobScriptPath"" -ArgumentList("-jobId ""$_JobId"" -vmName ""$VMName"" -vmscount ""$VMCount"" -MachinePassword ""$_password"" -templateFilePath ""$RemoteTemplateFilePath"" -initialSnapshotName ""$initialSnapshotName"" -ScriptRoot ""$RemoteScriptRoot"" -localMachine ""$Var2""") -AsJob -Credential ""$($remoteMachines.Credential)"""
#Write-Host "    Invoke-Command -Credential $($remoteMachines.Credential) -FilePath ""$runJobScriptPath"" -ArgumentList(""$_JobId"" ""$VMName"" ""$VMCount"" ""$_password"" ""$RemoteTemplateFilePath"" ""$initialSnapshotName"" ""$RemoteScriptRoot"" ""$Var2"" ""C:\Temp"") -AsJob"
#Invoke-Command -FilePath $runJobScriptPath -ArgumentList($_JobId, $VMName, $VMCount, $_password, $RemoteTemplateFilePath, $initialSnapshotName, $RemoteScriptRoot, $Var2, "C:\Temp")
#Invoke-Command -FilePath $runJobScriptPath -ArgumentList("0", "", "0", "", "C:\Temp\Projects2\MSIX-Toolkit\Scripts\MSIXConnect\out\MPT_Templates\MsixPackagingToolTemplate_Job0.xml", "BeforeMsixConversions_2020-07-06", "C:\Temp\Projects2\MSIX-Toolkit\Scripts\BulkConversion", "True") -VMName "MSIX Packaging Tool Environment" -AsJob -Credential $Credentials
#$ConversionJobs = $(Invoke-Command -FilePath $runJobScriptPath -ArgumentList("-jobId ""$_JobId"" -vmName ""$VMName"" -vmscount ""$VMCount"" -MachinePassword ""$_password"" -templateFilePath ""$RemoteTemplateFilePath"" -initialSnapshotName ""$initialSnapshotName"" -ScriptRoot ""$RemoteScriptRoot"" -localMachine ""$Var2""") -AsJob -Credential $($remoteMachines.Credential))
#$jobId, $vmName, $vmsCount, $machinePassword, $templateFilePath, $initialSnapshotName, $ScriptRoot, $localMachine=$true
#$runJobScriptPath $_JobId, $VMName, $VMCount, $_password, $RemoteTemplateFilePath, $initialSnapshotName, $RemoteScriptRoot, $Var2, "C:\Temp"
#Invoke-Command -RunAsAdministrator -ContainerId var -FilePath $runJobScriptPath -ArgumentList($_JobId, $VMName, $VMCount, $_password, $RemoteTemplateFilePath, $initialSnapshotName, $RemoteScriptRoot, $Var2)
#Write-Host $Var
#$ConversionJobs = @(Start-Job -Credential $($remoteMachines.Credential) -FilePath $runJobScriptPath -ArgumentList("-JobID ""0"" -VMName """" -VMCount ""0"" -machinePassword """" -templateFilePath ""C:\Temp\Projects2\MSIX-Toolkit\Scripts\MSIXConnect\out\MPT_Templates\MsixPackagingToolTemplate_Job0.xml"" -initialSnapshotName ""BeforeMsixConversions_2020-07-06"" -ScriptRoot ""C:\Temp\Projects2\MSIX-Toolkit\Scripts\BulkConversion"" -localMachine ""True"""))
#$ConversionJobs = @(Start-Job -Credential $($remoteMachines.Credential) -FilePath $runJobScriptPath -ArgumentList($_JobId, $VMName, $VMCount, $_password, $RemoteTemplateFilePath, $initialSnapshotName, $RemoteScriptRoot, $Var2))

#Write-Host "    Waiting for job to complete..."
#$ConversionJobs | Wait-Job
#Write-Host "`n    Job Completed."

#$ConversionJobs | Receive-Job
#.\BulkConversion\run_job.ps1 -JobID "0" -VMName "" -VMCount "0" -machinePassword "" -templateFilePath "C:\Temp\Projects2\MSIX-Toolkit\Scripts\MSIXConnect\out\MPT_Templates\MsixPackagingToolTemplate_Job0.xml" -initialSnapshotName "BeforeMsixConversions_2020-07-06" -ScriptRoot "C:\Temp\Projects2\MSIX-Toolkit\Scripts\BulkConversion" -localMachine "True"

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
#New-LogEntry -WriteHost $true -LogValue "    #############`n`nJobID:  $jobId `nVMName:  $vmName `nVMCount:  $vmsCount `nMachinePassword:  $machinePassword `nTemplateFilePath:  $templateFilePath `nInitialSnapshotName:  $initialSnapshotName `nScriptRoot:  $ScriptRoot `nLocalMachine:  $localMachine `n`n#############" -Component "run_job.ps1:$($jobId+1)" -Path $workingDirectory

New-LogEntry -WriteHost $objVerbose -LogValue "    Variables:`n        - JobID:                $jobId `n        - VMName:               $vmName `n        - VMCount:              $vmsCount `n        - MachinePassword:      $machinePassword `n        - TemplateFilePath:     $templateFilePath `n        - InitialSnapshotName:  $initialSnapshotName `n        - ScriptRoot:           $ScriptRoot `n        - LocalMachine:         $localMachine `n" -Component "run_job.ps1:$($jobId+1)"

$Scratch = ""
$TemplateFile = [xml](get-content $($templateFilePath))
New-LogEntry -WriteHost $objVerbose -LogValue "    JOB: $($jobId+1) - $($TemplateFile.MsixPackagingToolTemplate.PackageInformation.PackageDisplayName)" -Component "run_job.ps1:$($jobId+1)"

## Validates that the conversion machine is a Virtual Machine.
if ($vmName)
{
    ## Creates initial Snapshot of Virtual Machine.
    $Scratch = New-InitialSnapshot -SnapshotName $initialSnapshotName -vmName $vmName -jobId $jobId
}

## Reads the Template file, and logs which application is being attempted.
$Scratch +=  "`nInitiating capture of $($TemplateFile.MsixPackagingToolTemplate.PackageInformation.PackageDisplayName).`n"
New-LogEntry -WriteHost $objVerbose -LogValue "    Initiating capture of $($TemplateFile.MsixPackagingToolTemplate.PackageInformation.PackageDisplayName)." -Component "run_job.ps1:$($jobId+1)"

try
{

    #New-LogEntry -LogValue "MsixPackagingTool.exe create-package --template $templateFilePath --machinePassword $machinePassword" -Component "run_job.ps1:$($jobId+1)"
    ## Convert application to the MSIX Packaging format.

    #IF($machinePassword -eq "")
    IF($localMachine -eq $true)
    {
        New-LogEntry -WriteHost $objVerbose -LogValue "    MsixPackagingTool.exe create-package --template $templateFilePath" -Component "run_job.ps1:$($jobId+1)"
        #Write-Host "Password is Null"
        foreach($Entry in $(MsixPackagingTool.exe create-package --template $templateFilePath))
        {
            #Write-host $Entry
            $Scratch += $Entry + "`n`r"
        }
    }
    else 
    {
        New-LogEntry -WriteHost $objVerbose -LogValue "    MsixPackagingTool.exe create-package --template $templateFilePath --machinePassword $machinePassword" -Component "run_job.ps1:$($jobId+1)" 
        #Write-Host "Password is not Null"
        foreach($Entry in $(MsixPackagingTool.exe create-package --template $templateFilePath --machinePassword $machinePassword))
        {
            #Write-host $Entry
            $Scratch += $Entry + "`n`r"
        }
    }

    If ($Error)
        { New-LogEntry -LogValue "    $Scratch" -Component "run_job.ps1:$($jobId+1)" -WriteHost $objVerbose -Severity 3  }
    Else
        { New-LogEntry -LogValue "    $Scratch" -Component "run_job.ps1:$($jobId+1)" -WriteHost $objVerbose  }
    
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
New-LogEntry -LogValue "    Conversion of application ($($TemplateFile.MsixPackagingToolTemplate.PackageInformation.PackageDisplayName)) completed" -Component "run_job.ps1:$($jobId+1)" 



Return $Scratch