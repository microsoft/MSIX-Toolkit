. $psscriptroot\SharedScriptLib.ps1

function CreateMPTTemplate($conversionParam, $jobId, $virtualMachine, $remoteMachine, $targetMachine, $workingDirectory)
{
    ## Sets the default values for each field in the MPT Template
    $objInstallerPath        = $conversionParam.InstallerPath
    $objInstallerPathRoot    = $($(Get-Item -Path $($conversionParam.InstallerPath)).Directory).FullName
    $objInstallerFileName    = $($(Get-Item -Path $objInstallerPath).Name)
    $objInstallerArguments   = $conversionParam.InstallerArguments
    $objPackageName          = $conversionParam.PackageName
    $objPackageDisplayName   = $conversionParam.PackageDisplayName
    $objPublisherName        = $conversionParam.PublisherName
    $objPublisherDisplayName = $conversionParam.PublisherDisplayName
    $objPackageVersion       = $conversionParam.PackageVersion
    $saveFolder              = $saveFolder = [System.IO.Path]::Combine($workingDirectory, "MSIX")
    $workingDirectory        = [System.IO.Path]::Combine($($workingDirectory), "MPT_Templates")
    $templateFilePath        = [System.IO.Path]::Combine($workingDirectory, "MsixPackagingToolTemplate_Job$($jobId).xml")
    $conversionMachine       = ""
    $objlocalMachine         = $targetMachine.Type

    ## If multiple files in install dir, compress the contents into a wrapped executable
    # IF($($(Get-ChildItem $objInstallerPathRoot).Count -gt 1) -and $($objlocalMachine -ne "LocalMachine") -and $($false))
    # {
    #     $InstallInstructions   = Compress-MSIXAppInstaller -Path $objInstallerPathRoot -InstallerPath $objInstallerFileName -InstallerArgument $objInstallerArguments
    #     $objInstallerPath      = $InstallInstructions.Filename
    #     $objInstallerArguments = $InstallInstructions.Arguments

    #     Write-Host "------------------------------------------------------------" -ForegroundColor Green
    #     Write-Host "`t Installer Filename:   |$objInstallerPath|" -ForegroundColor Green
    #     Write-Host "`t Installer Argument:   |$objInstallerArguments|" -ForegroundColor Green
    # }
   
    ## Package File Path:
    ## If the Save Package Path has been specified, use this directory otherwise use the default working directory.
    If($($conversionParam.SavePackagePath))
        { $saveFolder = [System.IO.Path]::Combine($($conversionParam.SavePackagePath), "MSIX") }
#    Else
#        { $saveFolder = [System.IO.Path]::Combine($workingDirectory, "MSIX") }

    ## Detects if the provided custom path exists, if not creates the required path.
    IF(!$(Get-Item -Path $saveFolder -ErrorAction SilentlyContinue))
        { $Scratch = New-Item -Force -Type Directory $saveFolder }


    ## Package Template Path:
    ## If the Save Template Path has been specified, use this directory otherwise use the default working directory.
    If($($conversionParam.SaveTemplatePath))
        { $workingDirectory = [System.IO.Path]::Combine($($conversionParam.SaveTemplatePath), "MPT_Templates") }
#    Else
#        { $workingDirectory = [System.IO.Path]::Combine($($workingDirectory), "MPT_Templates") }

    ## Detects if the MPT Template path exists, if not creates it.
    IF(!$(Get-Item -Path $workingDirectory -ErrorAction SilentlyContinue))
        { $Scratch = New-Item -Force -Type Directory $workingDirectory }
    
    ## Determines the type of machine that will be connected to for conversion.
    switch ($($targetMachine.Type))
    {
        "VirtualMachine" { $conversionMachine = "<VirtualMachine Name=""$($vm.Name)"" Username=""$($vm.Credential.UserName)"" />" }
        "RemoteMachine"  { $conversionMachine = "<mptv2:RemoteMachine ComputerName=""$($remoteMachine.ComputerName)"" Username=""$($remoteMachine.Credential.UserName)"" />" }
        "LocalMachine"   { $conversionMachine = "" }
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

    ####################
    ## Remote Machine ##
    ####################
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
            $targetMachine = New-Object PSObject
            $targetMachine | Add-Member -MemberType NoteProperty -Name "Type"         -Value $("RemoteMachine")
            $targetMachine | Add-Member -MemberType NoteProperty -Name "MachineName"  -Value $($_)
            
            $_jobId =            $remainingConversions[0]
            $_templateFilePath = CreateMPTTemplate $conversionParam $jobId $nul $_ $targetMachine $workingDirectory
            $_BSTR =             [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($_.Credential.Password)
            $_password =         [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($_BSTR)

#            Write-Progress -ID 0 -Status "Converting Applications..." -PercentComplete $($($_JobID+1)/$($conversionsParameters.count)*100) -Activity "Capture"
            New-LogEntry -LogValue "Dequeuing conversion job ($($_JobId+1)) for installer $($conversionParam.InstallerPath) on remote machine $($_.ComputerName)" -Component "batch_convert:RunConversionJobs"
            
#            $process = Start-Process "powershell.exe" -ArgumentList ($runJobScriptPath, "-jobId", $_jobId, "-machinePassword", $_password, "-templateFilePath", $_templateFilePath, "-workingDirectory", $workingDirectory) -PassThru
            $ConversionJobs += @(Start-Job -Name $("JobID: $($_JobId+1) - Converting $($conversionParam.PackageDisplayName)") -FilePath $runJobScriptPath -ArgumentList($_JobId, "", 0, $_password, $_templateFilePath, $initialSnapshotName, $PSScriptRoot))
#                "-jobId", $_jobId, "-machinePassword", $_password, "-templateFilePath", $_templateFilePath, "-workingDirectory", $workingDirectory)

            $remainingConversions = $remainingConversions | where { $_ -ne $remainingConversions[0] }

            sleep(1)
            Set-JobProgress -ConversionJobs $ConversionJobs -TotalTasks $($conversionsParameters.count)
        }
    }

    ######################
    ## Virtual Machines ##
    ######################
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

            $targetMachine = New-Object PSObject
            $targetMachine | Add-Member -MemberType NoteProperty -Name "Type"         -Value $("VirtualMachine")
            $targetMachine | Add-Member -MemberType NoteProperty -Name "MachineName"  -Value $($vm)

            $_templateFilePath = CreateMPTTemplate $conversionParam $_jobId $vm $nul $targetMachine $workingDirectory 
            $_BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($vm.Credential.Password)
            $_password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($_BSTR)
            
            ## Converts the Application to the MSIX Packaging format.
#            $process = Start-Process "powershell.exe" -ArgumentList ($runJobScriptPath, "-jobId", $_jobId, "-vmName", $vm.Name, "-vmsCount", $virtualMachines.Count, "-machinePassword", $_password, "-templateFilePath", $_templateFilePath, "-initialSnapshotName", $initialSnapshotName) -PassThru
            $ConversionJobs += @(Start-Job -Name $("JobID: $($_JobId+1) - Converting $($conversionParam.PackageDisplayName)") -FilePath $runJobScriptPath -ArgumentList($_JobId, $VM.Name, $virtualMachines.Count, $_password, $_templateFilePath, $initialSnapshotName, $PSScriptRoot))
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


function RunConversionJobsLocal($conversionsParameters, $workingDirectory)
{
    $_jobID              = 0
    $ConversionJobs      = @()
    $scratch             = New-Item -Force -Type Directory ([System.IO.Path]::Combine($workingDirectory, "MPT_Templates"))
    $scratch             = New-Item -Force -Type Directory ([System.IO.Path]::Combine($workingDirectory, "MSIX"))
    $initialSnapshotName = "BeforeMsixConversions_$(Get-Date -format yyyy-MM-dd)" 
    $runJobScriptPath    = [System.IO.Path]::Combine($PSScriptRoot, "run_job.ps1")
    $targetMachine       = New-Object PSObject
    $_password           = ""

    $targetMachine | Add-Member -MemberType NoteProperty -Name "Type"         -Value $("LocalMachine")
    $targetMachine | Add-Member -MemberType NoteProperty -Name "MachineName"  -Value $("")

    New-LogEntry -LogValue "Conversion Stats:`n    - Total Conversions:`t $($conversionsParameters.count)`n    - Running on Local Machine`n`n" -Component "bulk_convert:RunConversionJobsLocal" -Severity 1
    
    foreach ($AppConversionParameters in $conversionsParameters) 
    {
        $_templateFilePath = CreateMPTTemplate $AppConversionParameters $_jobID $nul $_ $targetMachine $workingDirectory

        New-LogEntry -LogValue "Conversion Job ($_JobID)" -Component "bulk_convert:RunConversionJobsLocal" -Severity 1
        New-LogEntry -LogValue "    Converting Application ($($AppConversionParameters.PackageDisplayName))`n        - Installer:  $($AppConversionParameters.InstallerPath)`n        - Argument:  $($AppConversionParameters.InstallerArguments)" -Component "bulk_convert:RunConversionJobsLocal" -Severity 1       
        #Start-Process -FilePath $runJobScriptPath -ArgumentList $("-jobId $_JobId -vmName "" -vmsCount 0 -machinePassword $_password -templateFilePath $_templateFilePath -initialSnapshotName $initialSnapshotName -ScriptRoot $PSScriptRoot") -Wait
        #Invoke-Command "$runJobScriptPath -jobId $_JobId -vmName "" -vmsCount 0 -machinePassword $_password -templateFilePath $_templateFilePath -initialSnapshotName $initialSnapshotName -ScriptRoot $PSScriptRoot"
        $ConversionJobs = @(Start-Job -Name $("JobID: $($_JobId) - Converting $($conversionParam.PackageDisplayName)") -FilePath $runJobScriptPath -ArgumentList($_JobId, $VM.Name, $virtualMachines.Count, $_password, $_templateFilePath, $initialSnapshotName, $PSScriptRoot))
        $ConversionJobs | Wait-Job

        New-LogEntry -LogValue "    Uninstalling Application ($($AppConversionParameters.PackageDisplayName))`n        - Installer:  $($AppConversionParameters.UninstallerPath)`n        - Argument:  $($AppConversionParameters.UninstallerArguments)" -Component "bulk_convert:RunConversionJobsLocal" -Severity 1
        New-LogEntry -LogValue "Uninstalling Application" -Component "bulk_convert:RunConversionJobsLocal" -Severity 1
        #Start-Process -FilePath $($AppConversionParameters.UninstallerPath) -ArgumentList ($($AppConversionParameters.UninstallerArguments)) -Wait
        $UninstallJobs = @(Start-Job -Name $("JobID: $($_JobId) - Uninstalling $($conversionParam.PackageDisplayName)") -FilePath $($AppConversionParameters.UninstallerPath) -ArgumentList($($AppConversionParameters.UninstallerArguments)))
        $UninstallJobs | Wait-Job

        $_jobID++
    }
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
#    Set-Content -Value "PowerShell.exe $("$ExportPath\$($ScriptFilePath.Replace($("$ContainerPath\"), ''))")" -Path $($CMDScriptFilePath) -Force
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
    #Invoke-Expression "iexpress.exe /N $SEDOutPath"
    
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
