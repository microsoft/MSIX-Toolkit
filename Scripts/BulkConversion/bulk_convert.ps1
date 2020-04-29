. $psscriptroot\SharedScriptLib.ps1

function CreateMPTTemplate($conversionParam, $jobId, $virtualMachine, $remoteMachine, $workingDirectory)
{
    ## Package File Path:
    ## If the Save Package Path has been specified, use this directory otherwise use the default working directory.
    If($($conversionParam.SavePackagePath))
        { $saveFolder = [System.IO.Path]::Combine($($conversionParam.SavePackagePath), "MSIX") }
    Else
        { $saveFolder = [System.IO.Path]::Combine($workingDirectory, "MSIX") }

    ## Detects if the provided custom path exists, if not creates the required path.
    IF(!$(Get-Item -Path $saveFolder -ErrorAction SilentlyContinue))
        { New-Item -Force -Type Directory $saveFolder }


    ## Package Template Path:
    ## If the Save Template Path has been specified, use this directory otherwise use the default working directory.
    If($($conversionParam.SaveTemplatePath))
        { $workingDirectory = [System.IO.Path]::Combine($($conversionParam.SaveTemplatePath), "MPT_Templates") }
    Else
        { $workingDirectory = [System.IO.Path]::Combine($($workingDirectory), "MPT_Templates") }

    ## Detects if the MPT Template path exists, if not creates it.
    IF(!$(Get-Item -Path $workingDirectory -ErrorAction SilentlyContinue))
        { New-Item -Force -Type Directory $workingDirectory }
    
    # create template file for this conversion
    $templateFilePath = [System.IO.Path]::Combine($workingDirectory, "MsixPackagingToolTemplate_Job$($jobId).xml")
    $conversionMachine = ""

    ## Determines the type of machine that will be connected to for conversion.
    if ($virtualMachine)
        { $conversionMachine = "<VirtualMachine Name=""$($vm.Name)"" Username=""$($vm.Credential.UserName)"" />" }
    else 
        { $conversionMachine = "<mptv2:RemoteMachine ComputerName=""$($remoteMachine.ComputerName)"" Username=""$($remoteMachine.Credential.UserName)"" />" }

    ## Generates the XML Content
    $xmlContent = @"
<MsixPackagingToolTemplate
    xmlns="http://schemas.microsoft.com/appx/msixpackagingtool/template/2018"
    xmlns:mptv2="http://schemas.microsoft.com/msix/msixpackagingtool/template/1904">
<Installer Path="$($conversionParam.InstallerPath)" Arguments="$($conversionParam.InstallerArguments)" />
$conversionMachine
<SaveLocation PackagePath="$saveFolder" />
<PackageInformation
    PackageName="$($conversionParam.PackageName)"
    PackageDisplayName="$($conversionParam.PackageDisplayName)"
    PublisherName="$($conversionParam.PublisherName)"
    PublisherDisplayName="$($conversionParam.PublisherDisplayName)"
    Version="$($conversionParam.PackageVersion)">
</PackageInformation>
</MsixPackagingToolTemplate>
"@

    ## Creates the XML file with the above content.
    Set-Content -Value $xmlContent -Path $templateFilePath
    $templateFilePath
}

function RunConversionJobs($conversionsParameters, $virtualMachines, $remoteMachines, $workingDirectory)
{
    $LogEntry  = "Conversion Stats:`n"
    $LogEntry += "`t - Total Conversions:      $($conversionsParameters.count)`n"
    $LogEntry += "`t - Total Remote Machines:  $($RemoteMachines.count)`n"
    $LogEntry += "`t - Total Virtual Machines: $($VirtualMachines.count)`n`r"

    Write-Progress -ID 0 -Status "Converting Applications..." -PercentComplete $($(0)/$($conversionsParameters.count)) -Activity "Capture"
    New-LogEntry -LogValue $LogEntry

    ## Creates working directory and child directories
    $scratch = New-Item -Force -Type Directory ([System.IO.Path]::Combine($workingDirectory, "MPT_Templates"))
    $scratch = New-Item -Force -Type Directory ([System.IO.Path]::Combine($workingDirectory, "MSIX"))

    $initialSnapshotName = "BeforeMsixConversions_$(Get-Date -format yyyy-MM-dd)" 
    $runJobScriptPath = [System.IO.Path]::Combine($PSScriptRoot, "run_job.ps1")

    # create list of the indices of $conversionsParameters that haven't started running yet
    $remainingConversions = @()
    $conversionsParameters | Foreach-Object { $i = 0 } { $remainingConversions += ($i++) }

    ## Validates that there are enough remote / virtual machines provided to package all identified applications to the MSIX packaging format.
    If($virtualMachines.count -eq 0)
    {
        If($RemoteMachines.count -lt $ConversionsParameters.count)
        {
            New-LogEntry -logValue "Warning, there are not enough Remote Machines ($($RemoteMachines.count)) to package all identified applications ($($ConversionsParameters.count))" -Severity 2 -Component "bulk_convert:RunConversionJobs"
        }
    }

    $ConversionJobs = @()

    # first schedule jobs on the remote machines. These machines will be recycled and will not be re-used to run additional conversions
    $remoteMachines | Foreach-Object {
        ## Verifies if the remote machine is accessible on the network.
        If(Test-RMConnection -RemoteMachineName $($_.ComputerName))
        {
            # select a job to run
            New-LogEntry -LogValue "Determining next job to run..." -Component "batch_convert:RunConversionJobs"
            $conversionParam = $conversionsParameters[$remainingConversions[0]]

            # Capture the job index and update list of remaining conversions to run
            $_jobId =            $remainingConversions[0]
            $_templateFilePath = CreateMPTTemplate $conversionParam $jobId $nul $_ $workingDirectory
            $_BSTR =             [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($_.Credential.Password)
            $_password =         [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($_BSTR)

#            Write-Progress -ID 0 -Status "Converting Applications..." -PercentComplete $($($_JobID+1)/$($conversionsParameters.count)*100) -Activity "Capture"
            New-LogEntry -LogValue "Dequeuing conversion job ($($_JobId+1)) for installer $($conversionParam.InstallerPath) on remote machine $($_.ComputerName)" -Component "batch_convert:RunConversionJobs"
            
#            $process = Start-Process "powershell.exe" -ArgumentList ($runJobScriptPath, "-jobId", $_jobId, "-machinePassword", $_password, "-templateFilePath", $_templateFilePath, "-workingDirectory", $workingDirectory) -PassThru
            $ConversionJobs += @(Start-Job -Name $("$($_JobId+1) - $($conversionParam.PackageName)") -FilePath $runJobScriptPath -ArgumentList($_JobId, "", 0, $_password, $_templateFilePath, $initialSnapshotName, $PSScriptRoot))
#                "-jobId", $_jobId, "-machinePassword", $_password, "-templateFilePath", $_templateFilePath, "-workingDirectory", $workingDirectory)

            $remainingConversions = $remainingConversions | where { $_ -ne $remainingConversions[0] }

            sleep(1)
            Set-JobProgress -ConversionJobs $ConversionJobs -TotalTasks $($conversionsParameters.count)
        }
    }

    $OnceThrough = $true
    If ($($virtualMachines.Count) -eq 0)
    {
        ## Waits for the conversion on the Remote Machines to complete before exiting.
        While ($(Get-Job | where state -eq running).count -gt 0)
        {
            If ($OnceThrough)
            {
                New-LogEntry -LogValue "Waiting for applications to complete on remote machines." -Component "bulk_convert.ps1:RunConversionJobs"
                $OnceThrough = $false
            }
    
            Sleep(1)
            Set-JobProgress -ConversionJobs $ConversionJobs -TotalTasks $($conversionsParameters.count)
        }    

        Set-JobProgress -ConversionJobs $ConversionJobs -TotalTasks $($conversionsParameters.count)

        ## Exits the conversion, as no more machines are available for use.
        New-LogEntry -LogValue "Finished running all jobs on the provided Remote Machines" -Component "batch_convert:RunConversionJobs"
        Return
    }
    
    # Next schedule jobs on virtual machines which can be checkpointed/re-used
    # keep a mapping of VMs and the current job they're running, initialized ot null
    $vmsCurrentJobMap = @{}
    $virtualMachines | Foreach-Object { $vmsCurrentJobMap.Add($_.Name, $nul) }

    # Use a semaphore to signal when a machine is available. Note we need a global semaphore as the jobs are each started in a different powershell process
    $semaphore = New-Object -TypeName System.Threading.Semaphore -ArgumentList ($virtualMachines.Count, $virtualMachines.Count, "Global\MPTBatchConversion")

    while ($semaphore.WaitOne(-1))
    {
        if ($remainingConversions.Count -gt 0)
        {
            # select a job to run 
            New-LogEntry -LogValue "Determining next job to run..." -Component "batch_convert:RunConversionJobs"
    
            $conversionParam = $conversionsParameters[$remainingConversions[0]]

            # select a VM to run it on. Retry a few times due to race between semaphore signaling and process completion status
            $vm = $nul
            while (-not $vm) { $vm = $virtualMachines | where { -not($vmsCurrentJobMap[$_.Name]) -or -not($vmsCurrentJobMap[$_.Name].ExitCode -eq $Nul) } | Select-Object -First 1 }
            
            # Capture the job index and update list of remaining conversions to run
            $_jobId = $remainingConversions[0]
            $remainingConversions = $remainingConversions | where { $_ -ne $remainingConversions[0] }

#            Write-Progress -ID 0 -Status "Converting Applications..." -PercentComplete $($($_JobID)/$($conversionsParameters.count)*100) -Activity "Capture"
            New-LogEntry -LogValue "Dequeuing conversion job ($($_JobId+1)) for installer $($conversionParam.InstallerPath) on VM $($vm.Name)" -Component "batch_convert:RunConversionJobs"

            $_templateFilePath = CreateMPTTemplate $conversionParam $_jobId $vm $nul $workingDirectory 
            $_BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($vm.Credential.Password)
            $_password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($_BSTR)
            
            ## Converts the Application to the MSIX Packaging format.
#            $process = Start-Process "powershell.exe" -ArgumentList ($runJobScriptPath, "-jobId", $_jobId, "-vmName", $vm.Name, "-vmsCount", $virtualMachines.Count, "-machinePassword", $_password, "-templateFilePath", $_templateFilePath, "-initialSnapshotName", $initialSnapshotName) -PassThru
            $ConversionJobs += @(Start-Job -Name $("$($_JobId+1) - $($conversionParam.PackageName)") -FilePath $runJobScriptPath -ArgumentList($_JobId, $VM.Name, $virtualMachines.Count, $_password, $_templateFilePath, $initialSnapshotName, $PSScriptRoot))
            $vmsCurrentJobMap[$vm.Name] = $process
        }
        else
        {
            $semaphore.Release()
            break;
        }

        Sleep(1)
        Set-JobProgress -ConversionJobs $ConversionJobs -TotalTasks $($conversionsParameters.count)
    }

    $OnceThrough = $true
    ## Waits for the conversion on the Remote Machines to complete before exiting.
    While ($(Get-Job | where state -eq running).count -gt 0)
    {
        If ($OnceThrough)
        {
            New-LogEntry -LogValue "Waiting for applications to complete on remote machines." -Component "bulk_convert.ps1:RunConversionJobs"
            $OnceThrough = $false
        }
        Sleep(1)
        Set-JobProgress -ConversionJobs $ConversionJobs -TotalTasks $($conversionsParameters.count)
    }   

    Set-JobProgress -ConversionJobs $ConversionJobs -TotalTasks $($conversionsParameters.count)
    New-LogEntry -LogValue "Finished scheduling all jobs" -Component "batch_convert:RunConversionJobs"
    $virtualMachines | foreach-object { if ($vmsCurrentJobMap[$_.Name]) { $vmsCurrentJobMap[$_.Name].WaitForExit() } }
    $semaphore.Dispose()
    
    ## Remove and stop all scripted jobs.
    $ConversionJobs | Where-Object State -ne "Completed" | Stop-job
    $ConversionJobs | Remove-job

    #Read-Host -Prompt 'Press any key to continue '
    New-LogEntry -LogValue "Finished running all jobs" -Component "batch_convert:RunConversionJobs"
}

Function Test-VMConnection ([string]$VMName)
{
    ## Retrieves a list of network interfaces for the machine.
    $HostNic = netsh interface ipv4 show interfaces

    ## Retrieves the VM Object, if no object found fails, and returns false.
    $GuestVM = Get-VM -Name $VMName -ErrorVariable Error -ErrorAction SilentlyContinue
    If ($Error) 
    {
        New-LogEntry -LogValue "Unable to locate $VMName on this machine." -Component "SharedScriptLib.ps1:Test-VMConnection" -Severity 3
        Return $false
    }

    ## Collects the name of the VM NIC.
    $GuestVMNic = $(Get-VMNetworkAdapter -VM $GuestVM).SwitchName

    ## Parses through all of the host NIC's to find the matching NIC of the VM. Validates connection status then returns true if status is connected.
    Foreach ($Connection in $HostNic)
    {
        IF($Connection -like "*" + $GuestVMNic + "*" -and $Connection -notlike "*disconnected*")
        {
            New-LogEntry -LogValue "Connection to $VMName VM was successful." -Component "SharedScriptLib.ps1:Test-VMConnection"
            Return $true
        }
    }

    ## Unable to find a matching NIC or the connection was disconnected. Returns false.
    New-LogEntry -LogValue "Connection to $VMName VM failed." -Component "SharedScriptLib.ps1:Test-VMConnection" -Severity 3
    Return $false
}

Function Test-RMConnection ($RemoteMachineName)
{
    ## Sends a network ping request to the Remote Machine
    $PingResult = Test-Connection $RemoteMachineName -ErrorAction SilentlyContinue

    ## Validates if a response of any kind has been returned.
    If ($($PingResult.Count) -gt 0 )
    {
        ## If all Pings returned successfully, consider this a 100% good VM to work with.
        If ($($PingResult.Count) -eq 4)
        {
            New-LogEntry -LogValue "Connection to $RemoteMachineName Successful." -Component "SharedScriptLib.ps1:Test-RMConnection"
            Return $true
        }

        ## If some Pings were lost, still good, just potential network issue.
        New-LogEntry -LogValue "Connection to $RemoteMachineName successful, Some packets were dropped." -Component "SharedScriptLib.ps1:Test-RMConnection" -Severity 2
        Return $true
    }

    ## Returns false, no network response was available.
    New-LogEntry -LogValue "Unable to Connect to $RemoteMachineName`r    - Ensure Firewall has been configured to allow remote connections and PING requests"  -Component "SharedScriptLib.ps1:Test-RMConnection" -Severity 3
    Return $false
}
