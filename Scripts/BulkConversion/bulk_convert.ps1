. $psscriptroot\SharedScriptLib.ps1

function CreateMPTTemplate([Parameter(Mandatory=$True,ParameterSetName=$('VirtualMachine'),Position=0)]$virtualMachine, 
                           [Parameter(Mandatory=$True,ParameterSetName=$('RemoteMachine'), Position=0)]$remoteMachine, 
                           [Parameter(Mandatory=$True,ParameterSetName=$('VMLocal'),       Position=0)][Switch]$VMLocal,
                           [Parameter(Mandatory=$False,Position=1)]$conversionParam, 
                           [Parameter(Mandatory=$False,Position=2)]$jobId, 
                           [Parameter(Mandatory=$False,Position=3)]$workingDirectory)
{
    ## Sets the default values for each field in the MPT Template
    $FunctionName            = Get-FunctionName
    $LoggingComponent        = "JobID($JobID) - $FunctionName"
    $objInstallerPath        = $conversionParam.InstallerPath
    $objInstallerPathRoot    = $conversionParam.AppInstallerFolderPath      # $($(Get-Item -Path $($conversionParam.InstallerPath)).Directory).FullName
    $objInstallerFileName    = $conversionParam.AppFileName                 # $($(Get-Item -Path $objInstallerPath).Name)
    $objInstallerArguments   = $conversionParam.InstallerArguments
    $objPackageName          = $conversionParam.PackageName
    $objPackageDisplayName   = $conversionParam.PackageDisplayName
    $objPublisherName        = $conversionParam.PublisherName
    $objPublisherDisplayName = $conversionParam.PublisherDisplayName
    $objPackageVersion       = $conversionParam.PackageVersion

    $saveFolder              = [System.IO.Path]::Combine($workingDirectory, "MSIX")
    $workingDirectory        = [System.IO.Path]::Combine($workingDirectory, "MPT_Templates")
    $templateFilePath        = [System.IO.Path]::Combine($workingDirectory, "MsixPackagingToolTemplate_Job$($jobId).xml")
    $conversionMachine       = ""

    IF($null -ne $conversionParam.ContentParentRoot)
        { $saveFolder              = [System.IO.Path]::Combine($saveFolder, "$($conversionParam.ContentParentRoot)") }

    New-LogEntry -LogValue "        - Installer Path:                 $objInstallerPath`n        - Installer Path Root:            $objInstallerPathRoot`n        - Installer FileName:             $objInstallerFileName`n        - Installer Arguments:            $objInstallerArguments`n        - Package Name:                   $objPackageName`n        - Package Display Name:           $objPackageDisplayName`n        - Package Publisher Name:         $objPublisherName`n        - Package Publisher Display Name: $objPublisherDisplayName`n        - Package Version:                $objPackageVersion`n        - Save Folder:                    $saveFolder`n        - Working Directory:              $workingDirectory`n        - Template File Path:             $templateFilePath`n        - Conversion Machine:             $conversionMachine`n        - Local Machine:                  $objlocalMachine`n" -Severity 1 -Component $LoggingComponent -writeHost $false
    New-LogEntry -LogValue "    Current Save Directory is: $saveFolder" -Severity 1 -Component $LoggingComponent

    ## Detects if the provided custom path exists, if not creates the required path.
    IF(!$(Get-Item -Path $saveFolder -ErrorAction SilentlyContinue))
        { $Scratch = New-Item -Force -Type Directory $saveFolder }

    ## If the Save Template Path has been specified, use this directory otherwise use the default working directory.
    If($($conversionParam.SaveTemplatePath))
        { $workingDirectory = [System.IO.Path]::Combine($($conversionParam.SaveTemplatePath), "MPT_Templates") }

    ## Detects if the MPT Template path exists, if not creates it.
    IF(!$(Get-Item -Path $workingDirectory -ErrorAction SilentlyContinue))
        { $Scratch = New-Item -Force -Type Directory $workingDirectory }
    
    ## Determines the type of machine that will be connected to for conversion.
    switch ($PSCmdlet.ParameterSetName)
    {
        "VirtualMachine" { $conversionMachine = "<VirtualMachine Name=""$($virtualMachine.Name)"" Username=""$($virtualMachine.Credential.UserName)"" />" }
        "RemoteMachine"  { $conversionMachine = "<mptv2:RemoteMachine ComputerName=""$($remoteMachine.ComputerName)"" Username=""$($remoteMachine.Credential.UserName)"" />" }
        "VMLocal"        { $conversionMachine = "" }
    }

    ## Generates the XML Content
    $xmlContent = @"
<MsixPackagingToolTemplate
    xmlns="http://schemas.microsoft.com/appx/msixpackagingtool/template/2018"
    xmlns:mptv2="http://schemas.microsoft.com/msix/msixpackagingtool/template/1904">
<Installer Path="$($objInstallerPath)" Arguments="$($objInstallerArguments)" />
$conversionMachine
<SaveLocation PackagePath="$saveFolder" />
<PackageInformation
    PackageName="$($objPackageName)"
    PackageDisplayName="$($objPackageDisplayName)"
    PublisherName="$($objPublisherName)"
    PublisherDisplayName="$($objPublisherDisplayName)"
    Version="$($objPackageVersion)">
</PackageInformation>
</MsixPackagingToolTemplate>
"@

    ## Creates the XML file with the above content.
    Set-Content -Value $xmlContent -Path $templateFilePath

    $ConversionInfo = New-Object PSObject
    $ConversionInfo | Add-Member -MemberType NoteProperty -Name "Content"      -Value $($xmlContent)
    $ConversionInfo | Add-Member -MemberType NoteProperty -Name "Path"         -Value $($templateFilePath)
    $ConversionInfo | Add-Member -MemberType NoteProperty -Name "SavePath"     -Value $($saveFolder)
    $ConversionInfo | Add-Member -MemberType NoteProperty -Name "TemplatePath" -Value $($workingDirectory)

    Return $ConversionInfo
}

function RunConversionJobs($conversionsParameters, $virtualMachines, $remoteMachines, $workingDirectory)
{
    $FunctionName = Get-FunctionName

    $LogEntry  = "Conversion Stats:`n"
    $LogEntry += "    - Total Conversions:      $($conversionsParameters.count)`n"
    $LogEntry += "    - Total Remote Machines:  $($RemoteMachines.count)`n"
    $LogEntry += "    - Total Virtual Machines: $($VirtualMachines.count)`n`r"

    Write-Progress -ID 0 -Status "Converting Applications..." -PercentComplete $($(0)/$($conversionsParameters.count)) -Activity "Capture"
    New-LogEntry -LogValue $LogEntry -Severity 1 -Component "JobID(-) - $FunctionName"

    ## Includes the Job Status Member to List of Virtual Machines
    $virtualMachines | ForEach-Object{$_ | Add-Member -MemberType NoteProperty -Name "ConversionJob" -Value @()}

    ## Creates working directory and child directories
    $scratch = New-Item -Force -Type Directory ([System.IO.Path]::Combine($workingDirectory, "MPT_Templates"))
    $scratch = New-Item -Force -Type Directory ([System.IO.Path]::Combine($workingDirectory, "MSIX"))
    $scratch = New-Item -Force -Type Directory ([System.IO.Path]::Combine($workingDirectory, "ErrorLogs"))
    $initialSnapshotName = "BeforeMsixConversions_$(Get-Date -format yyyy-MM-dd)" 
    $runJobScriptPath    = [System.IO.Path]::Combine($PSScriptRoot, "run_job.ps1")

    # create list of the indices of $conversionsParameters that haven't started running yet
    $remainingConversions = @()
    $conversionsParameters | Foreach-Object { $i = 0 } { $remainingConversions += ($i++) }

    ## Validates that there are enough remote / virtual machines provided to package all identified applications to the MSIX packaging format.
    If($virtualMachines.count -eq 0)
    {
        If($RemoteMachines.count -lt $ConversionsParameters.count)
        {
            New-LogEntry -logValue "Warning, there are not enough Remote Machines ($($RemoteMachines.count)) to package all identified applications ($($ConversionsParameters.count))" -Severity 2 -Component "JobID(-) - $FunctionName"
        }
    }

    ####################
    ## Remote Machine ##
    ####################
    $ConversionJobs = @()

    IF($remoteMachines.count -gt 0)
    {
        # first schedule jobs on the remote machines. These machines will be recycled and will not be re-used to run additional conversions
        $remoteMachines | Foreach-Object 
            {
                ## Verifies if the remote machine is accessible on the network.
                If(Test-RMConnection -RemoteMachineName $($_.ComputerName))
                {
                    ## Determining next job to run.
                    $_jobId               = $remainingConversions[0]
                    $remainingConversions = $remainingConversions | where { $_ -ne $remainingConversions[0] }
                    $conversionParam   = $conversionsParameters[$_jobId]
                    $LoggingComponent  = "JobID($_JobID) - $FunctionName"
                    $ConversionJobName = "Job($_JobID) - $($ConversionParam.PackageDisplayName)"

                    New-LogEntry -LogValue "Determining next job to run..." -Component $LoggingComponent
                    
                    $FuncScriptBlock = $Function:NewMSIXConvertedApp
                    $VM.Job = Start-Job -Name $ConversionJobName -ScriptBlock $([scriptblock]::Create($FuncScriptBlock)) -ArgumentList ("RemoteMachine", $_, $conversionParam, $_JobID, $WorkingDirectory, $PSScriptRoot)

                    sleep(1)
                    Set-JobProgress -ConversionJobs $ConversionJobs -TotalTasks $($conversionsParameters.count)
                }
            }
    }
    
    ######################
    ## Virtual Machines ##
    ######################

    IF($($virtualMachines.Count) -gt 0)
    {
        # Next schedule jobs on virtual machines which can be checkpointed/re-used
        # keep a mapping of VMs and the current job they're running, initialized ot null
        $vmsCurrentJobMap = @{}
        $virtualMachines | Foreach-Object { $vmsCurrentJobMap.Add($_.Name, $nul) }

        While($remainingConversions.Count -gt 0)
        {
            ## Sets the Job ID, then removes it from the list of pending jobs (Remaining Conversion).
            $_jobId = $remainingConversions[0]
            $remainingConversions = $remainingConversions | Where-Object { $_ -ne $remainingConversions[0] }
            
            $conversionParam  = $conversionsParameters[$_jobId]
            $LoggingComponent = "JobID($_JobID) - $FunctionName"

            $VM = $null
            while ($null -eq $VM) 
            {
                ## Creates a reference to the VM in a completed or non-running state.
                IF($($VirtualMachines.Where({$_.Job.State -ne "Running"})).Count -gt 0 )
                { $VM = $VirtualMachines.Where({$_.Job.State -ne "Running"}) | Select-Object -First 1 }
            }

            New-LogEntry -LogValue "Dequeuing conversion job ($($_JobId)) for installer $($conversionParam.InstallerPath) on VM $($vm.Name)" -Component $LoggingComponent

            $FuncScriptBlock   = $Function:NewMSIXConvertedApp
            $ConversionJobName = "Job $_JobID - $($ConversionParam.PackageDisplayName)"

            ## If sourced from ConfigMgr or Export then run Local if more than 1 file exists in root.
            IF($($conversionParam.AppInstallerFolderPath) -and $($($(Get-ChildItem -Recurse -Path $conversionParam.AppInstallerFolderPath).count -gt 1) -or $($($conversionParam.AppInstallerFolderPath).StartsWith) ))
                { $VM.Job = Start-Job -Name $ConversionJobName -ScriptBlock $([scriptblock]::Create($FuncScriptBlock)) -ArgumentList ("RunLocal", $VM, $conversionParam, $_JobID, $WorkingDirectory, $PSScriptRoot) }
            ELSE 
                { $VM.Job = Start-Job -Name $ConversionJobName -ScriptBlock $([scriptblock]::Create($FuncScriptBlock)) -ArgumentList ("VirtualMachine", $VM, $conversionParam, $_JobID, $WorkingDirectory, $PSScriptRoot) }

            $ConversionJobs += $($VM.Job)
            
            Start-Sleep(1)
            Set-JobProgress -ConversionJobs $ConversionJobs -TotalTasks $($conversionsParameters.count)
        }
    }
    else 
    {
        New-LogEntry -LogValue "Finished running all jobs on the provided Remote Machines" -Component "JobID(-) - $FunctionName"
    }


    ###################################
    ## Pending Conversion Completion ##
    ###################################

    $OnceThrough = $true

    ## Waits for the conversion on the Remote Machines to complete before exiting.
    While ($(Get-Job | where state -eq running).count -gt 0)
    {
        If ($OnceThrough)
        {
            New-LogEntry -LogValue "Waiting for applications to complete conversion..." -Component "JobID(-) - $FunctionName"
            $OnceThrough = $false
        }
        Sleep(1)
        Set-JobProgress -ConversionJobs $ConversionJobs -TotalTasks $($conversionsParameters.count)
    }   

    ##############
    ## Clean-up ##
    ##############

    Set-JobProgress -ConversionJobs $ConversionJobs -TotalTasks $($conversionsParameters.count)
    New-LogEntry -LogValue "Finished scheduling all jobs" -Component "JobID(-) - $FunctionName"
    #$virtualMachines | foreach-object { if ($vmsCurrentJobMap[$_.Name]) { $vmsCurrentJobMap[$_.Name].WaitForExit() } }
    
    ## Remove and stop all scripted jobs.
    $ConversionJobs | Where-Object State -ne "Completed" | Stop-job
    $ConversionJobs | Remove-job

    #Read-Host -Prompt 'Press any key to continue '
    New-LogEntry -LogValue "Finished running all jobs" -Component "JobID(-) - $FunctionName"
}

Function NewMSIXConvertedApp ([Parameter(Mandatory=$True,Position=0)][ValidateSet ("RunLocal", "RemoteMachine", "VirtualMachine")] [String]$ConversionTarget,
#                               [Parameter(Mandatory=$True, Position=0,ParameterSetName=$('RunLocal'))]      [Switch]$RunLocal, 
#                               [Parameter(Mandatory=$True, Position=0,ParameterSetName=$('RemoteMachine' ))][Switch]$RemoteMachine, 
#                               [Parameter(Mandatory=$True, Position=0,ParameterSetName=$('VirtualMachine'))][Switch]$VirtualMachine, 
#                               [Parameter(Mandatory=$True, Position=4,ParameterSetName=$('VirtualMachine'))][int]$VMCount,
                               [Parameter(Mandatory=$True, Position=1)]$TargetMachine, 
                               [Parameter(Mandatory=$True, Position=2)]$ConversionParameters, 
                               [Parameter(Mandatory=$False,Position=3)][int]$JobID=0, 
                               [Parameter(Mandatory=$False,Position=4)][string]$WorkingDirectory="C:\Temp\MSIXBulkConversion",
                               [Parameter(Mandatory=$False,Position=5)][string]$ScriptRepository=$PSScriptRoot)
{
    . $ScriptRepository\SharedScriptLib.ps1
    . $ScriptRepository\Bulk_Convert.ps1

    $scratch = New-Item -Force -Type Directory ([System.IO.Path]::Combine($workingDirectory, "MPT_Templates"))
    $scratch = New-Item -Force -Type Directory ([System.IO.Path]::Combine($workingDirectory, "MSIX"))
    $scratch = New-Item -Force -Type Directory ([System.IO.Path]::Combine($workingDirectory, "ErrorLogs"))
    $runJobScriptPath = [System.IO.Path]::Combine($ScriptRepository, "run_job.ps1")
    $objTimerSeconds  = 600    ## 600 = 10 minutes
    $FunctionName     = "NewMSIXConvertedApp"
    $LoggingComponent = "JobID($JobID) - $FunctionName"


    $_BSTR             = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($TargetMachine.Credential.Password)
    $_password         = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($_BSTR)

    $initialSnapshotName = "Pre-MSIX Conversion"


    Switch ($ConversionTarget)
    {
        "RemoteMachine"
        {
            ## Remote Machine Conversion:
            $ConversionInfo    = CreateMPTTemplate -remoteMachine $TargetMachine $ConversionParameters $JobId $workingDirectory
            $_templateFilePath = $ConversionInfo.Path
            $RemoteTemplateFilePath  = $([String]$($(Get-Item -Path $_templateFilePath).FullName))

            New-LogEntry -LogValue "Dequeuing conversion job ($($JobId)) for installer $($ConversionParameters.InstallerPath) on remote machine $($TargetMachine.ComputerName)" -Component $LoggingComponent
            
            $ConvertScriptBlock = "MsixPackagingTool.exe create-package --template $RemoteTemplateFilePath --machinePassword ""$_password"""
            New-LogEntry -LogValue $ConvertScriptBlock -Component $LoggingComponent

            $Job = Invoke-Command -AsJob -Credential $TargetMachine.Credential -ScriptBlock $([scriptblock]::Create($ConvertScriptBlock))

            ## Sets a timeout for the installer, checking the job status once every second.
            do {
                $objJobStatus = $($Job | Get-Job -InformationAction SilentlyContinue).State
        
                Start-Sleep -Seconds 1
                $objTimerSeconds --
            } while ($($($objJobStatus -ne "Completed") -and $($objJobStatus -ne "Failed")) -and $($objTimerSeconds -gt 0))
        }
        "VirtualMachine"
        {
            $ConversionInfo    = CreateMPTTemplate -virtualMachine $TargetMachine $ConversionParameters $JobId $workingDirectory
            $_templateFilePath = $ConversionInfo.Path
            $RemoteTemplateFilePath  = $([String]$($(Get-Item -Path $_templateFilePath).FullName))
            
            $ConvertScriptBlock = "MsixPackagingTool.exe create-package --template $RemoteTemplateFilePath --machinePassword $_password"
            New-LogEntry -LogValue $ConvertScriptBlock -Component $LoggingComponent
            $Job = Start-Job -ScriptBlock $([scriptblock]::Create($ConvertScriptBlock))
            #$Job = Invoke-Command -AsJob -Credential $TargetMachine.Credential -ScriptBlock $([scriptblock]::Create($ConvertScriptBlock))

            ## Sets a timeout for the installer, checking the job status once every second.
            do {
                $objJobStatus = $($Job | Get-Job -InformationAction SilentlyContinue).State
        
                Start-Sleep -Seconds 1
                $objTimerSeconds --
            } while ($($($objJobStatus -ne "Completed") -and $($objJobStatus -ne "Failed")) -and $($objTimerSeconds -gt 0))

            New-LogEntry -LogValue "    Reverting VM ($($TargetMachine.Name)" -Component $LoggingComponent -Severity 1
            Restore-InitialSnapshot -SnapshotName $initialSnapshotName -VMName $($TargetMachine.Name) -jobId ""
        }
        "RunLocal"
        {
            New-InitialSnapshot -SnapshotName $initialSnapshotName -VMName $($virtualMachines.Name) -jobId ""

            $objSeverity = 1
            IF($($($ConversionParameters.InstallerArguments) -eq ""))
                { $objSeverity = 2 }
            Write-Host "`nConversion Job ($JobID)" -backgroundcolor Black
            New-LogEntry -LogValue "Conversion Job ($JobID)" -Component $LoggingComponent -Severity 1 -WriteHost $false
            New-LogEntry -LogValue "    Converting Application ($($ConversionParameters.PackageDisplayName))`n        - Deployment Type:      $($ConversionParameters.DeploymentType)`n        - Installer Full Path:  $($ConversionParameters.InstallerPath)`n        - Installer Filename:   $($ConversionParameters.AppFileName)`n        - Installer Argument:   $($ConversionParameters.InstallerArguments)" -Component $LoggingComponent -Severity $objSeverity

            IF($($($ConversionParameters.InstallerArguments) -ne ""))
            {
                $objConversionInfo = CreateMPTTemplate -VMLocal $ConversionParameters $JobID $workingDirectory
                $_templateFilePath = $objConversionInfo.Path
                $objXMLContent     = $($objConversionInfo.Content).Replace("'", "")
                $objSavePath       = $objConversionInfo.SavePath
                $objTemplatePath   = $objConversionInfo.TemplatePath

                ## Enables Guest Service on VM
                Enable-VMIntegrationService -Name "Guest Service Interface" -VMName $($TargetMachine.Name) -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 5

                ################# Creating / Copying Script Folder #################
#                Get-ChildItem -Recurse $ScriptRepository | ForEach-Object { Copy-VMFile -Name $($TargetMachine.Name) -Force -SourcePath $($_.FullName) -DestinationPath $($_.FullName) -FileSource Host -CreateFullPath }
                
                ################# Creating / Copying Template Folder #################
                $Job = Copy-VMFile -Name $($TargetMachine.Name) -Force -SourcePath $($_templateFilePath) -DestinationPath $($_templateFilePath) -FileSource Host -CreateFullPath

                ################# Creating / Copying Installer Folder #################
                Get-ChildItem -Recurse $($ConversionParameters.AppInstallerFolderPath) | ForEach-Object { Copy-VMFile -Name $($TargetMachine.Name) -Force -SourcePath $($_.FullName) -DestinationPath $($_.FullName.Replace($($ConversionParameters.AppInstallerFolderPath), $($ConversionParameters.InstallerFolderPath))) -FileSource Host -CreateFullPath -ErrorAction SilentlyContinue }
                
                ################# Converting App #################
                $RemoteTemplateParentDir = $([String]$($(Get-Item -Path $_templateFilePath).Directory))
                $RemoteTemplateFilePath  = $([String]$($(Get-Item -Path $_templateFilePath).FullName))
                $RemoteScriptRoot        = $([String]$($(Get-Item -Path $ScriptRepository).FullName))

                New-LogEntry -LogValue "        - Remote Template Parent Dir: $RemoteTemplateParentDir`n        - Remote Template File Path:  $RemoteTemplateFilePath`n        - runJobScriptPath:           $runJobScriptPath`n        - PS Scriptroot:              $RemoteScriptRoot" -Severity 1 -Component $LoggingComponent -WriteHost $false
#                New-LogEntry -LogValue "    Invoking the localbulk_conversion.ps1 script" -Severity 1 -Component $LoggingComponent
                
                $ConvertScriptBlock = "MsixPackagingTool.exe create-package --template $RemoteTemplateFilePath"
                $Job = Invoke-Command -vmName $($TargetMachine.name) -AsJob -Credential $TargetMachine.Credential -ScriptBlock $([scriptblock]::Create($ConvertScriptBlock))

                ## Sets a timeout for the installer.
                $objJobStatus = ""
                do {
                    $objJobStatus = $($Job | Get-Job -InformationAction SilentlyContinue).State

                    ## Checks the job status every 1 second.
                    Start-Sleep -Seconds 1
                    $objTimerSeconds --
                } while ($($($objJobStatus -ne "Completed") -and $($objJobStatus -ne "Failed")) -and $($objTimerSeconds -gt 0))

                IF($($objTimerSeconds -gt 0) -and $($objJobStatus -eq "Completed"))
                {
                    ################# Exporting Converted App #################
                    New-LogEntry -LogValue "    Creating PS Remoting Session." -Severity 1 -Component $LoggingComponent
                    $Session = New-PSSession -VMName $($TargetMachine.Name) -Credential $($TargetMachine.Credential)

                    New-LogEntry -LogValue "    Creating the export folder." -Severity 1 -Component $LoggingComponent
                    New-Item -Path $objSavePath -Force -ErrorAction SilentlyContinue

                    New-LogEntry -LogValue "    Exporting the completed app to host computer" -Severity 1 -Component $LoggingComponent
                    $objScriptBlock = "Get-ChildItem -Path ""$objSavePath"""
                    $objConvertedAppPath = Invoke-Command -Session $Session -ScriptBlock $([scriptblock]::Create($objScriptBlock))
                    New-LogEntry -LogValue "        Script Block:  $objScriptBlock" -Severity 1 -Component $LoggingComponent -WriteHost $true
                    New-LogEntry -LogValue "        App Path:      $($objConvertedAppPath.FullName)" -Severity 1 -Component $LoggingComponent -WriteHost $true                

                    Copy-Item -Path $($objConvertedAppPath.FullName) -Destination $($objConvertedAppPath.FullName) -FromSession $Session
                }

                #Pause
                Start-Sleep -Seconds 5

                New-LogEntry -LogValue "    Reverting VM ($($TargetMachine.Name)" -Component $LoggingComponent -Severity 1
                Restore-InitialSnapshot -SnapshotName $initialSnapshotName -VMName $($TargetMachine.Name) -jobId ""
            }
        }
    }

    New-LogEntry -LogValue "    Installation Job Status:  $($objJobStatus)" -Severity 1 -Component $LoggingComponent -writeHost $false

    IF($objTimerSeconds -le 0)
    { 
        New-LogEntry -LogValue "    ERROR:  Application Conversion failed to package the application ($($ConversionParameters.PackageDisplayName))" -Severity 3 -Component $LoggingComponent
        New-LogEntry -LogValue "    ERROR:  Application Conversion Results:`n"$($Job | Receive-Job) -Severity 3 -Component $LoggingComponent
        New-LogEntry -LogValue "    ERROR:  Failed to complete install of application ($($ConversionParameters.PackageDisplayName)), timeout has been reached... Skipping application" -Severity 3 -Component $LoggingComponent -writeHost $true 
    }
    ELSEIF($($objJobStatus -ne "Completed"))
    {
        New-LogEntry -LogValue "    ERROR:  Application Conversion failed to package the application ($($ConversionParameters.PackageDisplayName))" -Severity 3 -Component $LoggingComponent
        New-LogEntry -LogValue "    ERROR:  Application Conversion Results:`n"$($Job | Receive-Job) -Severity 3 -Component $LoggingComponent
        New-LogEntry -LogValue "    ERROR:  $($Job.ChildJobs[0].Error)" -Severity 3 -Component $LoggingComponent
    }
    Else
    {
        New-LogEntry -LogValue "    Application Conversion Results:`n$($Job | Receive-Job)" -Severity 1 -Component $LoggingComponent -writeHost $true
    }
    
    Return $Job
    #    Return $ConversionJobs
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

Function Compress-MSIXAppInstaller ($Path, $InstallerPath, $InstallerArgument)
{
    IF($Path[$Path.Length -1] -eq "\")
        { $Path = $Path.Substring(0, $($Path.Length -1)) }

    ## Identifies the original structure, creating a plan which can be used to restore after extraction
    $Path               = $(Get-Item $Path).FullName
    $ContainerPath      = $Path
    $ExportPath         = "C:\Temp\Output"
    $CMDScriptFilePath  = "$ContainerPath\MSIXCompressedExport.cmd"
    $ScriptFilePath     = "$ContainerPath\MSIXCompressedExport.ps1"
    $templateFilePath   = "$ContainerPath\MSIXCompressedExport.xml"
    $EXEOutPath         = "$ContainerPath\MSIXCompressedExport.EXE"
    $SEDOutPath         = "$ContainerPath\MSIXCompressedExport.SED"
    $EXEFriendlyName    = "MSIXCompressedExport"
    $EXECmdline         = $CMDScriptFilePath
    $FileDetails        = @()
    $XML                = ""
    $SEDFiles           = ""
    $SEDFolders         = ""
    $FileIncrement      = 0
    $DirectoryIncrement = 0

    IF($(Get-Item $EXEOutPath -ErrorAction SilentlyContinue).Exists -eq $true)
        { Remove-Item $EXEOutPath -Force }

    New-LogEntry -LogValue "Multiple files required for app install compressing all content into a self-extracting exe" -Component "Compress-MSIXAppInstaller" -Severity 2 -WriteHost $VerboseLogging

    ##############################  PS1  ##################################################################################
    ## Creates the PowerShell script which will export the contents to proper path and trigger application installation. ##
    $($ScriptContent = @'
$XMLData = [xml](Get-Content -Path ".\MSIXCompressedExport.xml")
Write-Host "`nExport Path" -backgroundcolor Black
Write-Host "$($XMLData.MSIXCompressedExport.Items.exportpath)"
Write-Host "`nDirectories" -backgroundcolor Black
$XMLData.MSIXCompressedExport.Items.Directory | ForEach-Object{Write-Host "$($_.Name.PadRight(40, ' '))$($_.RelativePath)" }
Write-Host "`nFiles" -backgroundcolor Black
$XMLData.MSIXCompressedExport.Items.File | ForEach-Object{Write-Host "$($_.Name.PadRight(40, ' '))$($_.RelativePath)" }

IF($(Get-Item $($XMLData.MSIXCompressedExport.Items.exportpath -ErrorAction SilentlyContinue)).Exists -eq $true)
    { Remove-Item $($XMLData.MSIXCompressedExport.Items.exportpath) -Recurse -Force }

Foreach ($Item in $XMLData.MSIXCompressedExport.Items.Directory) {$Scratch = mkdir "$($XMLData.MSIXCompressedExport.Items.exportpath)$($Item.RelativePath)"}
Foreach ($Item in $XMLData.MSIXCompressedExport.Items.File) {Copy-Item -Path ".\$($Item.Name)" -Destination "$($XMLData.MSIXCompressedExport.Items.exportpath)$($Item.RelativePath)"}

Write-Host "Start-Process -FilePath ""$($XMLData.MSIXCompressedExport.Items.exportpath)\$($XMLData.MSIXCompressedExport.Installer.Path)"" -ArgumentList ""$($XMLData.MSIXCompressedExport.Installer.Arguments)"" -wait"
Start-Process -FilePath "$($XMLData.MSIXCompressedExport.Items.exportpath)\$($XMLData.MSIXCompressedExport.Installer.Path)" -ArgumentList "$($XMLData.MSIXCompressedExport.Installer.Arguments)" -wait
'@)

    ## Exports the PowerShell script which will be used to restructure the content, and trigger the app install.
    New-LogEntry -LogValue "Creating the PS1 file:`n`nSet-Content -Value ScriptContent -Path $ScriptFilePath -Force `n`r$ScriptContent" -Component "Compress-MSIXAppInstaller" -Severity 1 -WriteHost $false
    Set-Content -Value $ScriptContent -Path $ScriptFilePath -Force

    ##############################  CMD  ########################################
    ## Exports the cmd script which will be used to run the PowerShell script. ##
    New-LogEntry -LogValue "Creating the CMD file:`n`nSet-Content -Value ScriptContent -Path $($CMDScriptFilePath.Replace($ContainerPath, '')) -Force `n`rPowerShell.exe $ScriptFilePath" -Component "Compress-MSIXAppInstaller" -Severity 1 -WriteHost $false
    Set-Content -Value "Start /Wait powershell.exe -executionpolicy Bypass -file $("$($ScriptFilePath.Replace($("$ContainerPath\"), ''))")" -Path $($CMDScriptFilePath) -Force

    ##############################  XML  ##############################
    ## Creates entries for each file and folder contained in the XML ##
    $ChildItems = Get-ChildItem $Path -Recurse
    $iFiles = 1
    $iDirs = 1
    $XMLFiles += "`t`t<File Name=""$($templateFilePath.replace($("$ContainerPath\"), ''))"" ParentPath=""$ContainerPath\"" RelativePath=""$($templateFilePath.replace($ContainerPath, ''))"" Extension=""xlsx"" SEDFile=""FILE0"" />"
    $XMLDirectories += "`t`t<Directory Name=""root"" FullPath=""$Path"" RelativePath="""" SEDFolder=""SourceFiles0"" />"

    foreach ($Item in $ChildItems) 
    {
        If($Item.Attributes -ne 'Directory')
            { 
                $XMLFiles += "`n`t`t<File Name=""$($Item.Name)"" ParentPath=""$($Item.FullName.Replace($($Item.Name), ''))"" RelativePath=""$($Item.FullName.Replace($Path, ''))"" Extension=""$($Item.Extension)"" SEDFile=""FILE$($iFiles)"" />" 
                $iFiles++
            }
        Else 
            { 
                $XMLDirectories += "`n`t`t<Directory Name=""$($Item.Name)"" FullPath=""$($Item.FullName)"" RelativePath=""$($Item.FullName.Replace($Path, ''))"" SEDFolder=""SourceFiles$($iDirs)"" />" 
                $iDirs++
            }

        $FileDetails += $ObjFileDetails
    }

    $templateFilePath   = "$ContainerPath\MSIXCompressedExport.xml"

    ## Outputs the folder and file structure to an XML file.
    $($xmlContent = @"
<MSIXCompressedExport
    xmlns="http://schemas.microsoft.com/appx/msixpackagingtool/template/2018"
    xmlns:mptv2="http://schemas.microsoft.com/msix/msixpackagingtool/template/1904">
    <Items exportpath="$($ExportPath)">
$XMLDirectories
$XMLFiles
    </Items>
    <Installer Path="$InstallerPath" Arguments="$InstallerArgument" />
</MSIXCompressedExport>
"@)

    ## Exports the XML file which contains the original file and folder structure.
    New-LogEntry -LogValue "Creating the XML file:`n`nSet-Content -Value xmlContent -Path $templateFilePath -Force `n`r$xmlContent" -Component "Compress-MSIXAppInstaller" -Severity 1 -WriteHost $false
    Set-Content -Value $xmlContent -Path $templateFilePath -Force

    ##############################  SED  ####################
    ## Extracts the required files and folder information. ##
    $ChildItems = Get-ChildItem $Path -Recurse
    $SEDFolders = ""
    $XMLData = [xml](Get-Content -Path "$templateFilePath")
    $objSEDFileStructure = ""
    $SEDFiles = ""

    foreach($ObjFolder in $($XMLData.MSIXCompressedExport.Items.Directory))
    {
        If($(Get-ChildItem $($objFolder.FullPath)).Count -ne 0)
            { 
                $objSEDFileStructure += "[$($ObjFolder.SEDFolder)]`n"
                $SEDFolders += "$($ObjFolder.SEDFolder)=$($objFolder.FullPath)`n" 
            }
        
        foreach($objFile in $($XMLData.MSIXCompressedExport.Items.File.Where({$_.ParentPath -eq "$($ObjFolder.FullPath)\"})))
            { $objSEDFileStructure += "%$($ObjFile.SEDFile)%=`n" }
    }


    foreach($objFile in $($XMLData.MSIXCompressedExport.Items.File))
        { $SEDFiles += "$($ObjFile.SEDFile)=""$($ObjFile.Name)""`n" }

    $($SEDExportTemplate = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=I
InstallPrompt=%InstallPrompt%
DisplayLicense=%DisplayLicense%
FinishMessage=%FinishMessage%
TargetName=%TargetName%
FriendlyName=%FriendlyName%
AppLaunched=%AppLaunched%
PostInstallCmd=%PostInstallCmd%
AdminQuietInstCmd=%AdminQuietInstCmd%
UserQuietInstCmd=%UserQuietInstCmd%
SourceFiles=SourceFiles
[Strings]
InstallPrompt=
DisplayLicense=
FinishMessage=
TargetName=$EXEOutPath
FriendlyName=$EXEFriendlyName
AppLaunched=$($EXECmdline.Replace("$ContainerPath\", ''))
PostInstallCmd=<None>
AdminQuietInstCmd=
UserQuietInstCmd=
$SEDFiles
[SourceFiles]
$SEDFolders
$objSEDFileStructure
"@)

    ## Exports the XML file which contains the original file and folder structure.
    New-LogEntry -LogValue "Creating the SED file:`n`nSet-Content -Value xmlContent -Path $SEDOutPath -Force `n`r$SEDExportTemplate" -Component "Compress-MSIXAppInstaller" -Severity 1 -WriteHost $false
    Set-Content -Value $SEDExportTemplate -Path $SEDOutPath -Force

    ##############################  EXE  #######
    ## Creates the self extracting executable ##

    Start-Process -FilePath "iExpress.exe" -ArgumentList "/N $SEDOutPath" -wait
    
    $ObjMSIXAppDetails = New-Object PSObject
    $ObjMSIXAppDetails | Add-Member -MemberType NoteProperty -Name "Filename"  -Value $($EXEOutPath.Replace($("$ContainerPath\"), ''))
    $ObjMSIXAppDetails | Add-Member -MemberType NoteProperty -Name "Arguments" -Value $("/C:$($EXECmdline.Replace("$ContainerPath\", ''))")

    ## Clean-up
    Remove-Item $CMDScriptFilePath -Force
    Remove-Item $ScriptFilePath -Force
    Remove-Item $templateFilePath -Force
    Remove-Item $SEDOutPath -Force

    Return $ObjMSIXAppDetails
}
