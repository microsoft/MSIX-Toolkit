#. $psscriptroot\SharedScriptLib.ps1

function CreateMPTTemplate
{
    <#
    .SYNOPSIS
    Creates the Template file used by the MSIX Packaging Tool to convert applications
    .DESCRIPTION
    Creates the Template file used by the MSIX Packaging Tool to convert applications. Populated with the target machine (Virtual, Remote, VM Local) which is determined based on the passed parameters.
    .PARAMETER virtualMachine
    Is the [TargetMachine] class object, which has the Virtual Machine Name, and Credentials used to access this Virtual Machine.
    .PARAMETER remoteMachine
    Is the [TargetMachine] class object, which has the Remote Machine Name, and Credentials used to access this Remote Machine.
    .PARAMETER VMLocal
    [Switch]
    .PARAMETER conversionParam
    Is the [ConversionParam] class object, containing the application installation parameters.
    .PARAMETER jobId
    Is the current job identifier - specifies the incremental counter for the conversion..
    .PARAMETER workingDirectory
    Working Directory
    .EXAMPLE
    CreateMPTTemplate -VirtualMachine $VirtualMachine -ConversionParam $AppConversionParameters -JobID 1 -WorkingDirectory "C:\Temp\WorkingDirectory"
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, Position=0,ParameterSetName=$('VirtualMachine'))] $virtualMachine,
        [Parameter(Mandatory=$True, Position=0,ParameterSetName=$('RemoteMachine' ))] $remoteMachine,
        [Parameter(Mandatory=$True, Position=0,ParameterSetName=$('VMLocal'       ))][switch] $VMLocal,
        [Parameter(Mandatory=$True, Position=1)] $conversionParam,
        [Parameter(Mandatory=$False,Position=2)][string] $jobId = "--",
        [Parameter(Mandatory=$True, Position=3)][string] $workingDirectory)
    
    ## Sets variables
    Begin {

        ###############################
        ## Variable input Validation ##
        ###############################

        ## Validate Parameter Set Values
        Switch ($PSCmdlet.ParameterSetName)
        {
            "VirtualMachine" 
            { 
                #########################
                #### $virtualMachine ####
                IF($virtualMachine -eq "" -or $null -eq $virtualMachine)
                {
                    ## Verifies that the object is not null or empty
                    New-LogEntry -LogValue "Virtual machine object is null or empty. Please update with Virtual Machine Name and re-run script." -Severity 3 -writeHost $True -Component $LoggingComponent -Path $WorkingDirectory -Path $WorkingDirectory
                    Return
                }
                ELSEIF($virtualMachine.Name -eq "" -or $null -eq $virtualMachine.Name)
                {
                    ## Verifies that the Virtual Machine has a name provided
                    New-LogEntry -LogValue "Virtual machine Name is null or empty. Please update with Virtual Machine Name and re-run script." -Severity 3 -writeHost $True -Component $LoggingComponent -Path $WorkingDirectory
                    Return
                }
                ELSE
                {
                    $ValidationResult = $(Get-VM).Name -contains $($virtualMachine.Name)
                    IF(-not $ValidationResult)
                    {
                        ## Verifies that a VM on the host machine matches with the provided virtual machine name.
                        New-LogEntry -LogValue "$($Env:ComputerName) does not contain a VM with the name: $($virtualMachine.Name). Please update the name and try again."
                        Return
                    }
                }
            }
            "RemoteMachine"
            {
                #######################
                #### remoteMachine ####
                IF($remoteMachine -eq "" -or $null -eq $remoteMachine)
                {
                    New-LogEntry -LogValue "Remote machine object is null or empty. Please update with Remote Machine Name and re-run script." -Severity 3 -writeHost $True -Component $LoggingComponent -Path $WorkingDirectory
                    Return
                }
                ELSEIF($remoteMachine.ComputerName -eq "" -or $null -eq $remoteMachine.ComputerName)
                {
                    New-LogEntry -LogValue "Remote machine Name is null or empty. Please update with Remote Machine Name and re-run script." -Severity 3 -writeHost $True -Component $LoggingComponent -Path $WorkingDirectory
                    Return
                }
                else 
                {
                    ## Validates that the Remote machine is accessible.
                    $ValidationResult = [boolean]$(Test-Connection -ComputerName $($remoteMachine.ComputerName))
                    IF(-Not $ValidationResult)
                        { Throw "$($Env:ComputerName) was unable to contact ConfigMgr Server $($remoteMachine.ComputerName). Please verify the name of the server and try again." }
                }
            }
        }


        #################################
        ## Set Initial Variable Values ##
        #################################
        $FunctionName            = Get-FunctionName
        $LoggingComponent        = "JobID($JobID) - $FunctionName"
        $objInstallerPath        = $conversionParam.InstallerPath
        $objInstallerPathRoot    = $conversionParam.AppInstallerFolderPath
        $objInstallerFileName    = $conversionParam.AppFileName
        $objInstallerArguments   = $conversionParam.InstallerArguments
        $objPackageName          = $conversionParam.PackageName
        $objPackageDisplayName   = $conversionParam.PackageDisplayName
        $objPublisherName        = $conversionParam.PublisherName
        $objPublisherDisplayName = $conversionParam.PublisherDisplayName
        $objPackageVersion       = $conversionParam.PackageVersion

        $saveFolder              = [System.IO.Path]::Combine($workingDirectory, "MSIX")
        $MPTTemplate             = [System.IO.Path]::Combine($workingDirectory, "MPT_Templates")
        #$workingDirectory        = [System.IO.Path]::Combine($workingDirectory, "MPT_Templates")
        $templateFilePath        = [System.IO.Path]::Combine($MPTTemplate, "MsixPackagingToolTemplate_Job$($jobId).xml")
        $conversionMachine       = ""

        New-LogEntry -LogValue "    Creating the MPT Template using the following values:`n`t - ParameterSet:`t`t $($PSCmdlet.ParameterSetName)`n`t - JobID:`t`t`t $JobID`n`t - WorkingDirectory:`t $WorkingDirectory`n`t - VirtualMachine:`t`t $($VirtualMachine.Name)`n`t - RemoteMachine:`t`t $($RemoteMachine.ComputerName)`n`t - ConversionParam:`t $ConversionParam" -severity 1 -Component $LoggingComponent -Path $WorkingDirectory
    }

    ## Creates a new MPT Template based on the provided parameters
    Process{
        IF($null -ne $conversionParam.ContentParentRoot)
            { $saveFolder = [System.IO.Path]::Combine($saveFolder, "$($conversionParam.ContentParentRoot)") }

        New-LogEntry -LogValue "    Variable Output:`n        - Installer Path:`t`t $objInstallerPath`n        - Installer Path Root:`t`t $objInstallerPathRoot`n        - Installer FileName:`t`t $objInstallerFileName`n        - Installer Arguments:`t`t $objInstallerArguments`n        - Package Name:`t`t $objPackageName`n        - Package Display Name:`t`t $objPackageDisplayName`n        - Package Publisher Name:`t $objPublisherName`n        - Package Publisher Display Name:`t $objPublisherDisplayName`n        - Package Version:`t`t $objPackageVersion`n        - Save Folder:`t`t`t $saveFolder`n        - Working Directory:`t`t $workingDirectory`n        - Template File Path: `t`t $templateFilePath`n        - Conversion Machine:`t $($TargetMachine.ComputerName)$($TargetMachine.Name) `n        - Local Machine:`t`t $objlocalMachine`n" -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory -writeHost $false
        New-LogEntry -LogValue "    Current Save Directory is: $saveFolder" -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory

        ## Detects if the provided custom path exists, if not creates the required path.
        IF(!$(Get-Item -Path $saveFolder -ErrorAction SilentlyContinue))
            { $Scratch = New-Item -Force -Type Directory $saveFolder }

        ## If the Save Template Path has been specified, use this directory otherwise use the default working directory.
        If($($conversionParam.SaveTemplatePath))
            { $MPTTemplate = [System.IO.Path]::Combine($($conversionParam.SaveTemplatePath), "MPT_Templates") }

        ## Detects if the MPT Template path exists, if not creates it.
        IF(!$(Get-Item -Path $MPTTemplate -ErrorAction SilentlyContinue))
            { $Scratch = New-Item -Force -Type Directory $MPTTemplate }
        
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
        $ConversionInfo | Add-Member -MemberType NoteProperty -Name "TemplatePath" -Value $($MPTTemplate)
    }

    ## Returns the MPT Template Details.
    End{
        Return $ConversionInfo
    }
}

function RunConversionJobs
{
    <#
    .SYNOPSIS
    Converts applications to the MSIX packaging format.
    .DESCRIPTION
    Receives a list of application installation parameters, and remote/virtual machines which will be used in the conversion process. Triggering and tracking the conversion jobs on remote/virtual machines.
    Allows for multiple installations to be triggered at the same time.
    .PARAMETER conversionParam
    Is the [ConversionParam] class object, containing the application installation parameters.
    .PARAMETER virtualMachine
    Is the [TargetMachine] class object, which has the Virtual Machine Name, and Credentials used to access this Virtual Machine.
    .PARAMETER remoteMachine
    Is the [TargetMachine] class object, which has the Remote Machine Name, and Credentials used to access this Remote Machine.    
    .PARAMETER workingDirectory
    Working Directory
    .EXAMPLE
    RunConversionJobs -ConversionParameters $ConversionParameters -VirtualMachines $VirtualMachines -RemoteMachines $RemoteMachines -WorkingDirectory "C:\Temp\WorkingDirectory"
    #>
    
    [CmdletBinding()]
    param (
        $conversionsParameters,
        $virtualMachines,
        $remoteMachines,
        $workingDirectory
    )

    ## Validates the paramters, and sets variables required by the function.
#    Begin{
        $FunctionName = Get-FunctionName
        $LoggingComponent = "JobID(-) - $FunctionName"

        $LogEntry  = "Conversion Stats:`n"
        $LogEntry += "    - Total Conversions:      $($conversionsParameters.count)`n"
        $LogEntry += "    - Total Remote Machines:  $($RemoteMachines.count)`n"
        $LogEntry += "    - Total Virtual Machines: $($VirtualMachines.count)`n`r"

        Write-Progress -ID 0 -Status "Converting Applications..." -PercentComplete $($(0)/$($conversionsParameters.count)) -Activity "Capture"
        New-LogEntry -LogValue $LogEntry -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory

        ## Creates working directory and child directories
        $scratch = New-Item -Force -Type Directory ([System.IO.Path]::Combine($workingDirectory, "MPT_Templates"))
        $scratch = New-Item -Force -Type Directory ([System.IO.Path]::Combine($workingDirectory, "MSIX"))
        $scratch = New-Item -Force -Type Directory ([System.IO.Path]::Combine($workingDirectory, "Logs"))

        # create list of the indices of $conversionsParameters that haven't started running yet
        $remainingConversions = @()
        $conversionsParameters | Foreach-Object { $i = 0 } { $remainingConversions += ($i++) }

        ## Validates that there are enough remote / virtual machines provided to package all identified applications to the MSIX packaging format.
        If($virtualMachines.count -eq 0)
        {
            If($RemoteMachines.count -lt $ConversionsParameters.count)
            {
                New-LogEntry -logValue "Warning, there are not enough Remote Machines ($($RemoteMachines.count)) to package all identified applications ($($ConversionsParameters.count))" -Severity 2 -Component $LoggingComponent -Path $WorkingDirectory
            }
        }
#    }

    ## Triggers the newMSIXConvertedApp Function to convert the application for each app
#    Process{
        ####################
        ## Remote Machine ##
        ####################
        $ConversionJobs = @()

        IF($remoteMachines.count -gt 0)
        {
            # first schedule jobs on the remote machines. These machines will be recycled and will not be re-used to run additional conversions
            $remoteMachines | Foreach-Object {
                ## Verifies if the remote machine is accessible on the network.
                If(Test-RMConnection -RemoteMachineName $($_.ComputerName) -WorkingDirectory $WorkingDirectory)
                {
                    ## Determining next job to run.
                    $_jobId               = $remainingConversions[0]
                    $remainingConversions = $remainingConversions | Where-Object { $_ -ne $remainingConversions[0] }
                    $conversionParam      = $conversionsParameters[$_jobId]
                    $LoggingComponent     = "JobID($_JobID) - $FunctionName"
                    $ConversionJobName    = "Job($_JobID) - $($ConversionParam.PackageDisplayName)"

                    New-LogEntry -LogValue "Determining next job to run..." -Component $LoggingComponent -Path $WorkingDirectory
                    New-LogEntry -LogValue "Dequeuing conversion job ($($_JobId)) for installer $($conversionParam.InstallerPath) on Remote Machine $($_.ComputerName)" -Component $LoggingComponent -Path $WorkingDirectory
                    
                    $FuncScriptBlock = $Function:NewMSIXConvertedApp

                    ## If sourced from ConfigMgr or Export then run Local if more than 1 file exists in root.
                    IF($($conversionParam.AppInstallerFolderPath) -and $($($(Get-ChildItem -Recurse -Path $conversionParam.AppInstallerFolderPath).count -gt 1) -or $($($conversionParam.AppInstallerFolderPath).StartsWith("\\"))))
                    {
                        New-LogEntry -LogValue "    Running Job on Remote Machine using the following parameters:`n`t - RunLocal-RM`n`t - ConversionJob: $($_.ConversionJob)`n`t - Target Machine Name: $($_.ComputerName)`n`t - Working Directory: $WorkingDirectory`n`t - PS ScriptRoot: $PSScriptRoot" -Severity 1 -WriteHost $False -Component $LoggingComponent -Path $WorkingDirectory
                        $_.ConversionJob = Start-Job -Name $ConversionJobName -ScriptBlock $([scriptblock]::Create($FuncScriptBlock)) -ArgumentList ("RunLocal-RM", $_, $conversionParam, $_JobID, $WorkingDirectory, $PSScriptRoot) 
                    }
                    ELSE 
                    {
                        New-LogEntry -LogValue "    Running Job on Remote Machine using the following parameters:`n`t - RemoteMachine`n`t - ConversionJob: $($_.ConversionJob)`n`t - Target Machine Name: $($_.ComputerName)`n`t - Working Directory: $WorkingDirectory`n`t - PS ScriptRoot: $PSScriptRoot" -Severity 1 -WriteHost $False -Component $LoggingComponent -Path $WorkingDirectory
                        $_.ConversionJob = Start-Job -Name $ConversionJobName -ScriptBlock $([scriptblock]::Create($FuncScriptBlock)) -ArgumentList ("RemoteMachine", $_, $conversionParam, $_JobID, $WorkingDirectory, $PSScriptRoot)
                    }

                    $ConversionJobs += $($_.ConversionJob)

                    Start-Sleep(1)
                    Set-JobProgress -ConversionJobs $ConversionJobs -TotalTasks $($conversionsParameters.count) -WorkingDirectory $WorkingDirectory
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

                ## Loops through all VMs checking the status of any running jobs. If a job is not in the running state (In either Completed or Failed), then the VM is selected for conversion.
                $VM = $null
                while ($null -eq $VM) 
                {
                    ## Creates a reference to the VM in a completed or non-running state.
                    IF($($VirtualMachines.Where({$_.ConversionJob.State -ne "Running"})).Count -gt 0 )
                        { $VM = $VirtualMachines.Where({$_.ConversionJob.State -ne "Running"}) | Select-Object -First 1 }
                }

                New-LogEntry -LogValue "Dequeuing conversion job ($($_JobId)) for installer $($conversionParam.InstallerPath) on VM $($vm.Name)" -Component $LoggingComponent -Path $WorkingDirectory

                $FuncScriptBlock   = $Function:NewMSIXConvertedApp
                $ConversionJobName = "Job $_JobID - $($ConversionParam.PackageDisplayName)"

                ## If sourced from ConfigMgr or Export then run Local if more than 1 file exists in root.
                IF($($conversionParam.AppInstallerFolderPath) -and $($($(Get-ChildItem -Recurse -Path $conversionParam.AppInstallerFolderPath).count -gt 1) -or $($($conversionParam.AppInstallerFolderPath).StartsWith("\\"))))
                    { $VM.ConversionJob = Start-Job -Name $ConversionJobName -ScriptBlock $([scriptblock]::Create($FuncScriptBlock)) -ArgumentList ("RunLocal-VM", $VM, $conversionParam, $_JobID, $WorkingDirectory, $PSScriptRoot) }
                ELSE 
                    { $VM.ConversionJob = Start-Job -Name $ConversionJobName -ScriptBlock $([scriptblock]::Create($FuncScriptBlock)) -ArgumentList ("VirtualMachine", $VM, $conversionParam, $_JobID, $WorkingDirectory, $PSScriptRoot) }

                $ConversionJobs += $($VM.ConversionJob)
                
                Start-Sleep(1)
                Set-JobProgress -ConversionJobs $ConversionJobs -TotalTasks $($conversionsParameters.count) -WorkingDirectory $WorkingDirectory
            }
        }
        else 
        {
            New-LogEntry -LogValue "Finished running all jobs on the provided Remote Machines" -Component "JobID(-) - $FunctionName" -Path $WorkingDirectory
        }


        ###################################
        ## Pending Conversion Completion ##
        ###################################

        $LoggingComponent = "JobID(-) - $FunctionName"
        $OnceThrough = $true

        ## Waits for the conversion on the Remote Machines to complete before exiting.
        While ($(Get-Job | Where-Object state -eq running).count -gt 0)
        {
            If ($OnceThrough)
            {
                New-LogEntry -LogValue "Waiting for applications to complete conversion..." -Component $LoggingComponent -Path $WorkingDirectory
                $OnceThrough = $false
            }
            Start-Sleep -Seconds 1
            Set-JobProgress -ConversionJobs $ConversionJobs -TotalTasks $($conversionsParameters.count) -WorkingDirectory $WorkingDirectory
        }
#    }

    ## Stops any failed or currently running jobs, and cleans up jobs
#    End{

        ##############
        ## Clean-up ##
        ##############

        Set-JobProgress -ConversionJobs $ConversionJobs -TotalTasks $($conversionsParameters.count) -WorkingDirectory $WorkingDirectory
        New-LogEntry -LogValue "Finished scheduling all jobs" -Component $LoggingComponent -Path $WorkingDirectory
        
        ## Remove and stop all scripted jobs.
        $ConversionJobs | Where-Object State -ne "Completed" | Stop-job
        $ConversionJobs | Remove-job

        #Read-Host -Prompt 'Press any key to continue '
        New-LogEntry -LogValue "Finished running all jobs" -Component $LoggingComponent -Path $WorkingDirectory
#    }
}

Function NewMSIXConvertedApp 
{
    
    <#
    .SYNOPSIS
    Converts individual applications as a job.    
    .DESCRIPTION
    This Function is executed as a job by the RunConversionJobs. This Function will trigger the creation of a new Conversion Template by calling the CreateMPTTemplate Function, then identify which conversion method is required: Remote Machine, Virtual Machine, VM Local. Then will convert the application using the identified method.
    .PARAMETER ConversionTarget
    Specifies where the conversion will occur.
    .PARAMETER TargetMachine
    Is the [TargetMachine] class object, which has the Virtual/Remote Machine Name, and Credentials used to access this Virtual/Remote Machine.
    .PARAMETER ConversionParameters
    Is the [ConversionParam] class object, containing the application installation parameters.
    .PARAMETER jobId
    Is the current job identifier - specifies the incremental counter for the conversion..
    .PARAMETER workingDirectory
    Working Directory
    .PARAMETER ScriptRepository
    Specifies the directory which contains the MSIX Packaging Tool scripts, pointing at the "BulkConverion" folder.
    .EXAMPLE
    NewMSIXConvertedApp -ConversionTarget "VirtualMachine" -TargetMachine $VirtualMachine -ConversionParameters $ConversionParameters -JobID 1 -WorkingDirectory "C:\Temp\WorkingDirectory" -ScriptRepository "C:\Temp\WorkingDirectory\MSIXPackagingTool\Scripts\BulkConversion"
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, Position=0)][ValidateSet ("RunLocal-RM", "RunLocal-VM", "RemoteMachine", "VirtualMachine")][String] $ConversionTarget,
        [Parameter(Mandatory=$True, Position=1)] $TargetMachine,
        [Parameter(Mandatory=$True, Position=2)] $ConversionParameters,
        [Parameter(Mandatory=$False,Position=3)][string] $JobID="-",
        [Parameter(Mandatory=$False,Position=4)][string] $WorkingDirectory="C:\Temp\MSIXBulkConversion",
        [Parameter(Mandatory=$False,Position=5)][string] $ScriptRepository=$PSScriptRoot
    )

    ## Verifies provided paramters, and sets variables required by function.
    Begin {
        . $ScriptRepository\SharedScriptLib.ps1
        . $ScriptRepository\Bulk_Convert.ps1

        ###############################
        ## Variable input Validation ##
        ###############################

        ########################
        #### $TargetMachine ####
        IF($TargetMachine -eq "" -or $null -eq $TargetMachine)
        {
            ## Verifies that the object is not null or empty
            New-LogEntry -LogValue "Virtual machine object is null or empty. Please update with Virtual Machine Name and re-run script." -Severity 3 -writeHost $True -Component $LoggingComponent -Path $WorkingDirectory
            Return
        }
        ELSEIF($($TargetMachine.Name -eq "" -or $null -eq $TargetMachine.Name) -and $($TargetMachine.ComputerName -eq "" -or $null -eq $TargetMachine.ComputerName))
        {
            ## Verifies that the Target Machine has a name provided
            New-LogEntry -LogValue "Virtual machine Name is null or empty. Please update with Virtual Machine Name and re-run script." -Severity 3 -writeHost $True -Component $LoggingComponent -Path $WorkingDirectory
            Return
        }
        ELSE
        {
            $VMResult = $(Get-VM).Name -contains $($TargetMachine.Name)
            $RMResult = [boolean]$(Test-Connection -ComputerName $TargetMachine.ComputerName)
            
            IF( -not $($VMResult -or $RMResult))
            {
                ## Verifies access to target machine.
                New-LogEntry -LogValue "$($Env:ComputerName) is unable to access the target machine $($TargetMachine.ComputerName)$($TargetMachine.Name). Please update and re-run script." -Severity 2 -Component $LoggingComponent -Path $WorkingDirectory
                Return
            }
        }

        #################################
        ## Set Initial Variable Values ##
        #################################
        $scratch = New-Item -Force -Type Directory ([System.IO.Path]::Combine($workingDirectory, "MPT_Templates"))
        $scratch = New-Item -Force -Type Directory ([System.IO.Path]::Combine($workingDirectory, "MSIX"))
        $objTimerSeconds     = 900    ## 600 = 10 minutes
        $FunctionName        = "NewMSIXConvertedApp"
        $LoggingComponent    = "JobID($JobID) - $FunctionName"
        $_BSTR               = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($TargetMachine.Credential.Password)
        $_password           = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($_BSTR)
        $initialSnapshotName = "Pre-MSIX Conversion"
        
        ## Sets the Conversion Machine Details for use in the function.
        [TargetMachine]$_ConversionMachine = @()

        ## Maps the variable values to the same child values.
        IF($TargetMachine.Name -eq "" -or $null -eq $TargetMachine.Name)
        {
            ## Target Machine was identified as a Remote Machine Target.
            $_ConversionMachine.Name        = $TargetMachine.ComputerName
            $_ConversionMachine.Credentials = $TargetMachine.Credentials
        }
        Else
        {
            ## Target Machine was identified as a Virtual Machine Target.
            $_ConversionMachine = $TargetMachine
        }

        ## Outputs the Application Conversion information to the log file for reference.
        $AppConversionDetails =  "    Application Conversion for $($ConversionParameters.PackageDisplayName) contains the following information:`n"
        $AppConversionDetails += "`t - Package Display Name:`t $($ConversionParameters.PackageDisplayName)`n"
        $AppConversionDetails += "`t - Publisher Display Name:`t $($ConversionParameters.PublisherDisplayName)`n"
        $AppConversionDetails += "`t - Package Name:`t`t $($ConversionParameters.PackageName)`n"
        $AppConversionDetails += "`t - Publisher Name:`t`t $($ConversionParameters.PublisherName)`n"
        $AppConversionDetails += "`t - Package Version:`t`t $($ConversionParameters.PackageVersion)`n"
        $AppConversionDetails += "`t - Installer Path:`t`t $($ConversionParameters.InstallerPath)`n"
        $AppConversionDetails += "`t - Installer Folder Path:`t $($ConversionParameters.InstallerFolderPath)`n"
        $AppConversionDetails += "`t - Uninstall Path:`t`t $($ConversionParameters.UninstallerPath)`n"
        $AppConversionDetails += "`t - Uninstaller Argument:`t`t $($ConversionParameters.UninstallerArgument)`n"
        $AppConversionDetails += "`t - App Description:`t`t $($ConversionParameters.AppDescription)`n"
        $AppConversionDetails += "`t - CM App Package ID:`t $($ConversionParameters.CMAppPackageID)`n"
        $AppConversionDetails += "`t - Requires User Interaction:`t $($ConversionParameters.RequiresUserInteraction)`n"
        $AppConversionDetails += "`t - App Folder Path:`t`t $($ConversionParameters.AppFolderPath)`n"
        $AppConversionDetails += "`t - App Installer Folder Path:`t $($ConversionParameters.AppInstallerFolderPath)`n"
        $AppConversionDetails += "`t - App Filename:`t`t $($ConversionParameters.AppFileName)`n"
        $AppConversionDetails += "`t - App Installer Type:`t $($ConversionParameters.AppIntallerType)`n"
        $AppConversionDetails += "`t - Content ID:`t`t $($ConversionParameters.ContentID)`n"
        $AppConversionDetails += "`t - Installer Arguments:`t $($ConversionParameters.InstallerArguments)`n"
        $AppConversionDetails += "`t - Execution Context:`t $($ConversionParameters.ExecutionContext)`n"
        $AppConversionDetails += "`t - Content Parent Root:`t $($ConversionParameters.ContentParentRoot)`n"
        $AppConversionDetails += "`t - Deployment Type:`t $($ConversionParameters.DeploymentType)`n"
        $AppConversionDetails += "`t - Save Package Path:`t $($ConversionParameters.SavePackagePath)`n"
        $AppConversionDetails += "`t - Save Template Path:`t $($ConversionParameters.SaveTemplatePath)`n"
        $AppConversionDetails += "`t - CM Installer Path:`t`t $($ConversionParameters.CMInstallerPath)`n"
        $AppConversionDetails += "`t - CM Installer Folder Path:`t $($ConversionParameters.CMInstallerFolderPath)"

        ## Creating header in Log file marking the start of the app conversion.
        Write-Host "Conversion Job ($JobID)" -backgroundcolor Black
        New-LogEntry -LogValue "Conversion Job ($JobID)" -Severity 1 -WriteHost $false -Component $LoggingComponent -Path $WorkingDirectory
        #New-LogEntry -LogValue "    Converting Application ($($ConversionParameters.PackageDisplayName))`n        - Deployment Type:      $($ConversionParameters.DeploymentType)`n        - Installer Full Path:  $($ConversionParameters.InstallerPath)`n        - Installer Filename:   $($ConversionParameters.AppFileName)`n        - Installer Argument:   $($ConversionParameters.InstallerArguments)" -Severity $objSeverity -Component $LoggingComponent -Path $WorkingDirectory
        New-LogEntry -LogValue "    #### Converting Application: $($ConversionParameters.PackageDisplayName) ####" -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory
        New-LogEntry -LogValue $AppConversionDetails -Severity 1 -WriteHost $False -Component $LoggingComponent -Path $WorkingDirectory
    }

    ## Created the MPT Template, and converts the application against the target machine.
    Process{
        Switch ($ConversionTarget)
        {
            "RemoteMachine"
            {
                ## Creating Conversion Template
                New-LogEntry -LogValue "    CreateMPTTemplate -remoteMachine $($TargetMachine) `n`n`$ConversionParameters `n`n`$JobId `n`n`$workingDirectory" -severity 1 -Component $LoggingComponent -Path $WorkingDirectory
                $ConversionInfo    = CreateMPTTemplate -remoteMachine $TargetMachine $ConversionParameters $JobId $workingDirectory

                New-LogEntry -LogValue "    Dequeuing conversion job ($($JobId)) for installer $($ConversionParameters.InstallerPath) on remote machine $($TargetMachine.ComputerName)" -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory
                $_templateFilePath      = $ConversionInfo.Path
                $RemoteTemplateFilePath = $([String]$($(Get-Item -Path $_templateFilePath).FullName))
               
                $ConvertScriptBlock = "MsixPackagingTool.exe create-package --template $RemoteTemplateFilePath --machinePassword ""$_password"""
                New-LogEntry -LogValue "    $($ConvertScriptBlock.Replace($_password, "XXXXXXXXXX"))" -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory

                $Job = Start-Job -ScriptBlock $([scriptblock]::Create($ConvertScriptBlock))
#                $Job = Invoke-Command -AsJob -Credential $TargetMachine.Credential -ScriptBlock $([scriptblock]::Create($ConvertScriptBlock))

                ## Sets a timeout for the installer, checking the job status once every second.
                do {
                    $objJobStatus = $($Job | Get-Job -InformationAction SilentlyContinue).State
            
                    Start-Sleep -Seconds 1
                    $objTimerSeconds --
                } while ($($($objJobStatus -ne "Completed") -and $($objJobStatus -ne "Failed")) -and $($objTimerSeconds -gt 0))
            }
            "RunLocal-RM"
            {
                ##################################
                ## Creating Conversion Template ##
                New-LogEntry -LogValue "    Creating the MPT Template:" -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory
                New-LogEntry -LogValue "        CreateMPTTemplate -remoteMachine $TargetMachine `n`n`$ConversionParameters `n`n`$JobId `n`n`$workingDirectory" -severity 1 -Component $LoggingComponent -Path $WorkingDirectory
                $ConversionInfo    = CreateMPTTemplate -remoteMachine $TargetMachine $ConversionParameters $JobId $workingDirectory

                New-LogEntry -LogValue "        Dequeuing conversion job ($($JobId)) for installer $($ConversionParameters.InstallerPath) on remote machine $($TargetMachine.ComputerName)" -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory
                $_templateFilePath      = $ConversionInfo.Path
                $RemoteTemplateFilePath = $([String]$($(Get-Item -Path $_templateFilePath).FullName))

                ###########################################
                ## Transfers Application to Host Machine ##
                New-LogEntry -LogValue "    Transferring Applications:" -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory -WriteHost $True

                ## Creates the destination folder and copies the Application Content local to the Remote Machine for conversion
                $objScriptBlock = "New-Item -Path ""$($ConversionParameters.InstallerFolderPath)"" -ItemType Directory -Force"
                New-LogEntry -LogValue "        Creating Application Content parent folder on Host Machine: $($TargetMachine.ComputerName)`n`t - Running Cmd: $objScriptBlock" -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory -WriteHost $True
                Invoke-Command -ScriptBlock $([Scriptblock]::Create($objScriptBlock))

                $AppInstallerFiles = Get-ChildItem -Recurse -Path $($ConversionParameters.CMInstallerFolderPath)
                $AppInstallerFiles | ForEach-Object{ Copy-Item -Path $_.FullName -Destination $($ConversionParameters.InstallerFolderPath) }

                ############################################
                ## Converts the App on the Remote Machine ##
                New-LogEntry -LogValue "    Converting Application:" -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory
                $ConvertScriptBlock = "MsixPackagingTool.exe create-package --template ""$RemoteTemplateFilePath"" --machinePassword ""$_password"""
                New-LogEntry -LogValue "        $($ConvertScriptBlock.Replace($_password, "XXXXXXXXXX"))" -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory

                $Job = Start-Job -ScriptBlock $([scriptblock]::Create($ConvertScriptBlock))
                #$Job = Invoke-Command -Session $Session -AsJob -ScriptBlock $([scriptblock]::Create($ConvertScriptBlock))
                #$Job = Invoke-Command -AsJob -ScriptBlock $([scriptblock]::Create($ConvertScriptBlock))

                ## Sets a timeout for the installer, checking the job status once every second.
                do {
                    $objJobStatus = $($Job | Get-Job -InformationAction SilentlyContinue).State
            
                    Start-Sleep -Seconds 1
                    $objTimerSeconds --
                } while ($($($objJobStatus -ne "Completed") -and $($objJobStatus -ne "Failed")) -and $($objTimerSeconds -gt 0))
            }
            "VirtualMachine"
            {
                New-InitialSnapshot -SnapshotName $initialSnapshotName -VMName $($virtualMachines.Name) -jobId $JobID -WorkingDirectory $WorkingDirectory

                New-LogEntry -LogValue "    Conversion input info: `n`t - CreateMPTTemplate: virtualMachine `n`t - Target Machine: $TargetMachine `n`t - Conversion Parameters: $ConversionParameters `n`t - JobID: $JobId `n`t - Working Directory: $workingDirectory" -severity 1 -Component $LoggingComponent -Path $WorkingDirectory
                $ConversionInfo    = CreateMPTTemplate -virtualMachine $TargetMachine $ConversionParameters $JobId $workingDirectory
                $_templateFilePath = $ConversionInfo.Path
                $RemoteTemplateFilePath  = $([String]$($(Get-Item -Path $_templateFilePath).FullName))
                
                New-LogEntry -LogEntry "    App Conversion Inputs: `n`t - Remote Template File Path: $RemoteTemplateFilePath `n`t - Password: $_password" -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory
                $ConvertScriptBlock = "MsixPackagingTool.exe create-package --template ""$RemoteTemplateFilePath"" --machinePassword ""$_password"""
                New-LogEntry -LogValue "    $($ConvertScriptBlock.Replace($_password, "XXXXXXXXXX"))" -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory
                $Job = Start-Job -ScriptBlock $([scriptblock]::Create($ConvertScriptBlock))
                #$Job = Invoke-Command -AsJob -Credential $TargetMachine.Credential -ScriptBlock $([scriptblock]::Create($ConvertScriptBlock))
                #$Job = Invoke-Command -vmName $($TargetMachine.name) -AsJob -Credential $TargetMachine.Credential -ScriptBlock $([scriptblock]::Create($ConvertScriptBlock))

                ## Sets a timeout for the installer, checking the job status once every second.
                do {
                    $objJobStatus = $($Job | Get-Job -InformationAction SilentlyContinue).State
            
                    Start-Sleep -Seconds 1
                    $objTimerSeconds --
                } while ($($($objJobStatus -ne "Completed") -and $($objJobStatus -ne "Failed")) -and $($objTimerSeconds -gt 0))

                New-LogEntry -LogValue "    Reverting VM ($($TargetMachine.Name)" -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory
                Restore-InitialSnapshot -SnapshotName $initialSnapshotName -VMName $($TargetMachine.Name) -jobId ""
            }
            "RunLocal-VM"
            {
                ## Creates a new Snapshot of the VM before initiating the conversion.
                New-LogEntry -LogValue "    Snapshot details: `n`t - Snapshot Name:  $initialSnapshotName `n`t - VM Name: $($TargetMachine.Name) `n`t - JobID: $JobID" -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory
                New-InitialSnapshot -SnapshotName $initialSnapshotName -VMName $($TargetMachine.Name) -jobId $JobID -WorkingDirectory $WorkingDirectory

                ## Sets the Severity of the following error message, if missing requirements marks the entry as an error.
                $objSeverity = 1
                IF($($($ConversionParameters.InstallerArguments) -eq ""))
                    { $objSeverity = 2 }

#                Write-Host "`nConversion Job ($JobID)" -backgroundcolor Black
#                New-LogEntry -LogValue "Conversion Job ($JobID)" -Severity 1 -WriteHost $false -Component $LoggingComponent -Path $WorkingDirectory
#                New-LogEntry -LogValue "    Converting Application ($($ConversionParameters.PackageDisplayName))`n        - Deployment Type:      $($ConversionParameters.DeploymentType)`n        - Installer Full Path:  $($ConversionParameters.InstallerPath)`n        - Installer Filename:   $($ConversionParameters.AppFileName)`n        - Installer Argument:   $($ConversionParameters.InstallerArguments)" -Severity $objSeverity -Component $LoggingComponent -Path $WorkingDirectory

                ## As long as the installer has silent installer arguments, then we will continue with the conversion.
                IF($($($ConversionParameters.InstallerArguments) -ne ""))
                {
                    New-LogEntry -LogValue "Creating the MPT Template" -Severity 1 -WriteHost $false -Component $LoggingComponent -Path $WorkingDirectory
                    $objConversionInfo = CreateMPTTemplate -VMLocal $ConversionParameters $JobID $workingDirectory
                    $_templateFilePath = $objConversionInfo.Path
                    $objXMLContent     = $($objConversionInfo.Content).Replace("'", "")
                    $objSavePath       = $objConversionInfo.SavePath
                    $objTemplatePath   = $objConversionInfo.TemplatePath

                    ## Enables Guest Service on VM
                    Enable-VMIntegrationService -Name "Guest Service Interface" -VMName $($TargetMachine.Name) -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 5

                    ################# Creating / Copying Script Folder #################
                    New-LogEntry -LogValue "    Copying MSIX Toolkit Scripts folder to VM ($($TargetMachine.Name))" -Severity 1 -WriteHost $false -Component $LoggingComponent -Path $WorkingDirectory
                    Get-ChildItem -Recurse $ScriptRepository | ForEach-Object { Copy-VMFile -Name $($TargetMachine.Name) -Force -SourcePath $($_.FullName) -DestinationPath $($_.FullName) -FileSource Host -CreateFullPath }
                    
                    ################# Creating / Copying Template Folder #################
                    New-LogEntry -LogValue "    Copying MSIX MPT Template file to VM ($($TargetMachine.Name))" -Severity 1 -WriteHost $false -Component $LoggingComponent -Path $WorkingDirectory
                    $Job = Copy-VMFile -Name $($TargetMachine.Name) -Force -SourcePath $($_templateFilePath) -DestinationPath $($_templateFilePath) -FileSource Host -CreateFullPath

                    ################# Creating / Copying Installer Folder #################
                    New-LogEntry -LogValue "    Copying the Application installation media to the VM ($($TargetMachine.Name))" -Severity 1 -WriteHost $false -Component $LoggingComponent -Path $WorkingDirectory
                    Get-ChildItem -Recurse $($ConversionParameters.AppInstallerFolderPath) | ForEach-Object { Copy-VMFile -Name $($TargetMachine.Name) -Force -SourcePath $($_.FullName) -DestinationPath $($_.FullName.Replace($($ConversionParameters.AppInstallerFolderPath), $($ConversionParameters.InstallerFolderPath))) -FileSource Host -CreateFullPath -ErrorAction SilentlyContinue }
                    
                    ################# Converting App #################
                    $RemoteTemplateParentDir = $([String]$($(Get-Item -Path $_templateFilePath).Directory))
                    $RemoteTemplateFilePath  = $([String]$($(Get-Item -Path $_templateFilePath).FullName))
                    $RemoteScriptRoot        = $([String]$($(Get-Item -Path $ScriptRepository).FullName))

                    New-LogEntry -LogValue "        - Remote Template Parent Dir: $RemoteTemplateParentDir`n        - Remote Template File Path:  $RemoteTemplateFilePath`n        - PS Scriptroot:              $RemoteScriptRoot" -Severity 1 -WriteHost $false -Component $LoggingComponent -Path $WorkingDirectory
                    
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
                        New-LogEntry -LogValue "    Creating PS Remoting Session." -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory
                        $Session = New-PSSession -VMName $($TargetMachine.Name) -Credential $($TargetMachine.Credential)

                        New-LogEntry -LogValue "    Creating the export folder." -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory
                        New-Item -Path $objSavePath -Force -ErrorAction SilentlyContinue

                        New-LogEntry -LogValue "    Exporting the completed app to host computer" -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory
                        $objScriptBlock = "Get-ChildItem -Path ""$objSavePath"""
                        $objConvertedAppPath = Invoke-Command -Session $Session -ScriptBlock $([scriptblock]::Create($objScriptBlock))
                        New-LogEntry -LogValue "        Script Block:  $objScriptBlock" -Severity 1 -WriteHost $true -Component $LoggingComponent -Path $WorkingDirectory
                        New-LogEntry -LogValue "        App Path:      $($objConvertedAppPath.FullName)" -Severity 1 -WriteHost $true -Component $LoggingComponent -Path $WorkingDirectory

                        Copy-Item -Path $($objConvertedAppPath.FullName) -Destination $($objConvertedAppPath.FullName) -FromSession $Session
                    }

                    #Pause
                    Start-Sleep -Seconds 5

                    New-LogEntry -LogValue "    Reverting VM ($($TargetMachine.Name)" -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory
                    Restore-InitialSnapshot -SnapshotName $initialSnapshotName -VMName $($TargetMachine.Name) -jobId "" -WorkingDirectory $WorkingDirectory
                }
            }
        }

        New-LogEntry -LogValue "    Installation Job Status:  $($objJobStatus)" -Severity 1 -writeHost $false -Component $LoggingComponent -Path $WorkingDirectory

        IF($objTimerSeconds -le 0)
        { 
            New-LogEntry -LogValue "    ERROR:  Application Conversion failed to package the application ($($ConversionParameters.PackageDisplayName))" -Severity 3 -Component $LoggingComponent -Path $WorkingDirectory
            New-LogEntry -LogValue "    ERROR:  Application Conversion Results:`n$($Job | Receive-Job)" -Severity 3 -Component $LoggingComponent -Path $WorkingDirectory
            New-LogEntry -LogValue "    ERROR:  Failed to complete install of application ($($ConversionParameters.PackageDisplayName)), timeout has been reached... Skipping application" -Severity 3 -writeHost $true -Component $LoggingComponent -Path $WorkingDirectory
        }
        ELSEIF($($objJobStatus -ne "Completed"))
        {
            New-LogEntry -LogValue "    ERROR:  Application Conversion failed to package the application ($($ConversionParameters.PackageDisplayName))" -Severity 3 -Component $LoggingComponent -Path $WorkingDirectory
            New-LogEntry -LogValue "    ERROR:  Application Conversion Results:`n$($Job | Receive-Job)" -Severity 3 -Component $LoggingComponent -Path $WorkingDirectory
            New-LogEntry -LogValue "    ERROR:  $($Job.ChildJobs[0].Error)" -Severity 3 -Component $LoggingComponent -Path $WorkingDirectory
        }
        Else
        {
            New-LogEntry -LogValue "    Application Conversion Results:`n$($Job | Receive-Job)" -Severity 1 -writeHost $true -Component $LoggingComponent -Path $WorkingDirectory
        }
    }
    
    ## Returns the results.
    End{
        Return $Job
        #Return $ConversionJobs
    }
    
}

Function Test-VMConnection 
{
    <#
    .SYNOPSIS
    Verifies a connection is able to be established with the Virtual Machine
    .DESCRIPTION
    Attempts to identify if the Virtual Machine exists, then verifies that the Network Switch used with the Virtual Machine is connected.
    .PARAMETER VMName
    Is the name of the Virtual Machine being tested
    .EXAMPLE
    Test-VMConnection -VMName "MSIXConversionVM"
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, Position=0)][ValidateNotNullOrEmpty()][string] $VMName,
        [Parameter(Mandatory=$False,Position=1)] $workingDirectory
    )

    ## Sets the variables required by the function
    Begin{
        $ReturnResult = $True
        $ListofVMs    = Get-VM
        $HostNic      = netsh interface ipv4 show interfaces
        $GuestVMNic   = $(Get-VMNetworkAdapter -VMName $VMName -ErrorAction SilentlyContinue).SwitchName
        $NicMatched   = $False
    }

    ## Validates that the VM meets the connection requirements.
    Process{

        ## Compares VM Nic and Host Nic to find a matching Switch Name
        $($GuestVMNic.Where({$_.Status -notlike "*Disconnected*"})).SwitchName | ForEach-Object {IF([Boolean]$($HostNic -like "*$_*")){$NicMatched = $True}}

        ## Retrieves the VM Object, if no object found fails, and returns false.
        $ValidationResult = $ListofVMs.Name -contains $VMName

        IF(-not $ValidationResult)
        {
            New-LogEntry -LogValue "Unable to locate $VMName on this machine." -Component "SharedScriptLib.ps1:Test-VMConnection" -Severity 3 -Path $WorkingDirectory
            $ReturnResult = $false
        }
        ELSEIF(-not $NicMatched)
        {
            New-LogEntry -LogValue "Unable to find matching NIC between VM and Host." -Component "SharedScriptLib.ps1:Test-VMConnection" -Severity 3 -Path $WorkingDirectory
            $ReturnResult = $false
        }

        ## Unable to find a matching NIC or the connection was disconnected. Returns false.
        New-LogEntry -LogValue "Connection to $VMName VM failed." -Component "SharedScriptLib.ps1:Test-VMConnection" -Severity 3 -Path $WorkingDirectory
        $ReturnResult = $false
    }

    ## Returns the results
    End{
        Return $ReturnResult
    }
}   

Function Test-RMConnection 
{
    <#
    .SYNOPSIS
    Tests connection with Remote Machine.
    .DESCRIPTION
    Attempts a PING test to a remote machine, identifying any dropped packages. If no response is received, then the VM is considered unreachable.
    .PARAMETER RemoteMachineName
    Name of the Remote Machine
    .EXAMPLE
    Test-RMConnection -RemoteMachineName "Client01.contoso.com"
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, Position=0)][ValidateNotNullOrEmpty()][string] $RemoteMachineName,
        [Parameter(Mandatory=$False,Position=1)][string] $JobID = "-",
        [Parameter(Mandatory=$False,Position=2)] $workingDirectory
    )

    Begin{
        ## Sends a network ping request to the Remote Machine
        $FunctionName      = Get-FunctionName
        $LoggingComponent  = "JobID($JobID) - $FunctionName"
        $PingResult        = Test-Connection $RemoteMachineName -ErrorAction SilentlyContinue
        $ReturnResults     = $false
        $WSManTrustedHosts = $(Get-Item WSMan:\localhost\Client\TrustedHosts).Value
        $HostDNSDomain     = $Env:USERDNSDOMAIN
    }

    Process{

        ##################
        ## PING Results ##
        IF($($PingResult.Count) -eq 4)
        {
            ## All Ping Results have returned successfully. Consider this a 100% good VM to work with.
            New-LogEntry -LogValue "Connection to $RemoteMachineName Successful." -Component $LoggingComponent -Path $WorkingDirectory
            $PINGResults = $true
        }
        ELSEIF($($PingResult.Count) -gt 0)
        {
            ## Some Pings were lost, still good, just potential network issue.
            New-LogEntry -LogValue "Connection to $RemoteMachineName successful, Some packets were dropped." -Component $LoggingComponent -Path $WorkingDirectory -Severity 2
            $PINGResults = $true
        }
        ELSE {
            ## Returns false, no network response was available.
            New-LogEntry -LogValue "Unable to Connect to $RemoteMachineName`r    - Ensure Firewall has been configured to allow remote connections and PING requests"  -Component $LoggingComponent -Path $WorkingDirectory -Severity 3
            $PINGResults = $false
        }

        #########################
        ## WSMan Trusted Hosts ##
        IF($WSManTrustedHosts -like "*$RemoteMachineName*")
        {
            ## Verifies that the VM is listed on the host machines WSMan Trusted Hosts
            New-LogEntry -LogValue "Remote Machine is listed in the $($Env:COMPUTERNAME) list of trust hosts." -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory
            $WSManResults = $True
        }
        ELSE {
            New-LogEntry -LogValue "Remote Machine is not listed in the $($Env:COMPUTERNAME) list of trust hosts. Please include the Remote Machine as a member of the Trusted Hosts." -Severity 2 -WriteHost $True -Component $LoggingComponent -Path $WorkingDirectory -Path $WorkingDirectory
            $WSManResults = $True
        }

    }

    End{
        Return $($PINGResults -and $WSManResults)
    }
    
}

#### Retaining for future use: Compress-MSIXAppInstaller ###
# Function Compress-MSIXAppInstaller ($Path, $InstallerPath, $InstallerArgument)
# {
#     <#
#     .SYNOPSIS
#     Compresses the application installation media into a single self extracting file which then triggers the application installation
#     .DESCRIPTION
#     Retrieves all files in the target application installation directory and adds them to a configuration file (*.sed) as well as the PowerShell script which will run the installation post extraction. Then uses the configuration file to create the compressed file.
#     .PARAMETER Path
#     Provided the path to where the compressed file will be created in.
#     .PARAMETER InstallerPath
#     Path to the Installation File
#     .PARAMETER InstallerArgument
#     Arguments used to silently install the application
#     .EXAMPLE
#     Compress-MSIXAppInstaller -Path "C:\Temp\AppOutput" -InstallerPath "C:\Temp\AppInstaller" -InstallerArgument "/Silent"
#     #>
#
#
#     IF($Path[$Path.Length -1] -eq "\")
#         { $Path = $Path.Substring(0, $($Path.Length -1)) }
#
#     ## Identifies the original structure, creating a plan which can be used to restore after extraction
#     $Path               = $(Get-Item $Path).FullName
#     $ContainerPath      = $Path
#     $ExportPath         = "C:\Temp\Output"
#     $CMDScriptFilePath  = "$ContainerPath\MSIXCompressedExport.cmd"
#     $ScriptFilePath     = "$ContainerPath\MSIXCompressedExport.ps1"
#     $templateFilePath   = "$ContainerPath\MSIXCompressedExport.xml"
#     $EXEOutPath         = "$ContainerPath\MSIXCompressedExport.EXE"
#     $SEDOutPath         = "$ContainerPath\MSIXCompressedExport.SED"
#     $EXEFriendlyName    = "MSIXCompressedExport"
#     $EXECmdline         = $CMDScriptFilePath
#     $FileDetails        = @()
#     $XML                = ""
#     $SEDFiles           = ""
#     $SEDFolders         = ""
#     $FileIncrement      = 0
#     $DirectoryIncrement = 0
#
#     IF($(Get-Item $EXEOutPath -ErrorAction SilentlyContinue).Exists -eq $true)
#         { Remove-Item $EXEOutPath -Force }
#
#     New-LogEntry -LogValue "Multiple files required for app install compressing all content into a self-extracting exe" -Component "Compress-MSIXAppInstaller" -Severity 2 -WriteHost $VerboseLogging
#
#     ##############################  PS1  ##################################################################################
#     ## Creates the PowerShell script which will export the contents to proper path and trigger application installation. ##
#     $($ScriptContent = @'
# $XMLData = [xml](Get-Content -Path ".\MSIXCompressedExport.xml")
# Write-Host "`nExport Path" -backgroundcolor Black
# Write-Host "$($XMLData.MSIXCompressedExport.Items.exportpath)"
# Write-Host "`nDirectories" -backgroundcolor Black
# $XMLData.MSIXCompressedExport.Items.Directory | ForEach-Object{Write-Host "$($_.Name.PadRight(40, ' '))$($_.RelativePath)" }
# Write-Host "`nFiles" -backgroundcolor Black
# $XMLData.MSIXCompressedExport.Items.File | ForEach-Object{Write-Host "$($_.Name.PadRight(40, ' '))$($_.RelativePath)" }
#
# IF($(Get-Item $($XMLData.MSIXCompressedExport.Items.exportpath -ErrorAction SilentlyContinue)).Exists -eq $true)
#     { Remove-Item $($XMLData.MSIXCompressedExport.Items.exportpath) -Recurse -Force }
#
# Foreach ($Item in $XMLData.MSIXCompressedExport.Items.Directory) {$Scratch = mkdir "$($XMLData.MSIXCompressedExport.Items.exportpath)$($Item.RelativePath)"}
# Foreach ($Item in $XMLData.MSIXCompressedExport.Items.File) {Copy-Item -Path ".\$($Item.Name)" -Destination "$($XMLData.MSIXCompressedExport.Items.exportpath)$($Item.RelativePath)"}
#
# Write-Host "Start-Process -FilePath ""$($XMLData.MSIXCompressedExport.Items.exportpath)\$($XMLData.MSIXCompressedExport.Installer.Path)"" -ArgumentList ""$($XMLData.MSIXCompressedExport.Installer.Arguments)"" -wait"
# Start-Process -FilePath "$($XMLData.MSIXCompressedExport.Items.exportpath)\$($XMLData.MSIXCompressedExport.Installer.Path)" -ArgumentList "$($XMLData.MSIXCompressedExport.Installer.Arguments)" -wait
# '@)
#
#     ## Exports the PowerShell script which will be used to restructure the content, and trigger the app install.
#     New-LogEntry -LogValue "Creating the PS1 file:`n`nSet-Content -Value ScriptContent -Path $ScriptFilePath -Force `n`r$ScriptContent" -Component "Compress-MSIXAppInstaller" -Severity 1 -WriteHost $false
#     Set-Content -Value $ScriptContent -Path $ScriptFilePath -Force
#
#     ##############################  CMD  ########################################
#     ## Exports the cmd script which will be used to run the PowerShell script. ##
#     New-LogEntry -LogValue "Creating the CMD file:`n`nSet-Content -Value ScriptContent -Path $($CMDScriptFilePath.Replace($ContainerPath, '')) -Force `n`rPowerShell.exe $ScriptFilePath" -Component "Compress-MSIXAppInstaller" -Severity 1 -WriteHost $false
#     Set-Content -Value "Start /Wait powershell.exe -executionpolicy Bypass -file $("$($ScriptFilePath.Replace($("$ContainerPath\"), ''))")" -Path $($CMDScriptFilePath) -Force
#
#     ##############################  XML  ##############################
#     ## Creates entries for each file and folder contained in the XML ##
#     $ChildItems = Get-ChildItem $Path -Recurse
#     $iFiles = 1
#     $iDirs = 1
#     $XMLFiles += "`t`t<File Name=""$($templateFilePath.replace($("$ContainerPath\"), ''))"" ParentPath=""$ContainerPath\"" RelativePath=""$($templateFilePath.replace($ContainerPath, ''))"" Extension=""xlsx"" SEDFile=""FILE0"" />"
#     $XMLDirectories += "`t`t<Directory Name=""root"" FullPath=""$Path"" RelativePath="""" SEDFolder=""SourceFiles0"" />"
#
#     foreach ($Item in $ChildItems) 
#     {
#         If($Item.Attributes -ne 'Directory')
#         { 
#             $XMLFiles += "`n`t`t<File Name=""$($Item.Name)"" ParentPath=""$($Item.FullName.Replace($($Item.Name), ''))"" RelativePath=""$($Item.FullName.Replace($Path, ''))"" Extension=""$($Item.Extension)"" SEDFile=""FILE$($iFiles)"" />" 
#             $iFiles++
#         }
#         Else 
#         { 
#             $XMLDirectories += "`n`t`t<Directory Name=""$($Item.Name)"" FullPath=""$($Item.FullName)"" RelativePath=""$($Item.FullName.Replace($Path, ''))"" SEDFolder=""SourceFiles$($iDirs)"" />" 
#             $iDirs++
#         }
#
#         $FileDetails += $ObjFileDetails
#     }
#
#     $templateFilePath   = "$ContainerPath\MSIXCompressedExport.xml"
#
#     ## Outputs the folder and file structure to an XML file.
#     $($xmlContent = @"
# <MSIXCompressedExport
#     xmlns="http://schemas.microsoft.com/appx/msixpackagingtool/template/2018"
#     xmlns:mptv2="http://schemas.microsoft.com/msix/msixpackagingtool/template/1904">
#     <Items exportpath="$($ExportPath)">
# $XMLDirectories
# $XMLFiles
#     </Items>
#     <Installer Path="$InstallerPath" Arguments="$InstallerArgument" />
# </MSIXCompressedExport>
# "@)
#
#     ## Exports the XML file which contains the original file and folder structure.
#     New-LogEntry -LogValue "Creating the XML file:`n`nSet-Content -Value xmlContent -Path $templateFilePath -Force `n`r$xmlContent" -Component "Compress-MSIXAppInstaller" -Severity 1 -WriteHost $false
#     Set-Content -Value $xmlContent -Path $templateFilePath -Force
#
#     ##############################  SED  ####################
#     ## Extracts the required files and folder information. ##
#     $ChildItems = Get-ChildItem $Path -Recurse
#     $SEDFolders = ""
#     $XMLData = [xml](Get-Content -Path "$templateFilePath")
#     $objSEDFileStructure = ""
#     $SEDFiles = ""
#
#     foreach($ObjFolder in $($XMLData.MSIXCompressedExport.Items.Directory))
#     {
#         If($(Get-ChildItem $($objFolder.FullPath)).Count -ne 0)
#             { 
#                 $objSEDFileStructure += "[$($ObjFolder.SEDFolder)]`n"
#                 $SEDFolders += "$($ObjFolder.SEDFolder)=$($objFolder.FullPath)`n" 
#             }
#        
#         foreach($objFile in $($XMLData.MSIXCompressedExport.Items.File.Where({$_.ParentPath -eq "$($ObjFolder.FullPath)\"})))
#             { $objSEDFileStructure += "%$($ObjFile.SEDFile)%=`n" }
#     }
#
#
#     foreach($objFile in $($XMLData.MSIXCompressedExport.Items.File))
#         { $SEDFiles += "$($ObjFile.SEDFile)=""$($ObjFile.Name)""`n" }
#
#     $($SEDExportTemplate = @"
# [Version]
# Class=IEXPRESS
# SEDVersion=3
# [Options]
# PackagePurpose=InstallApp
# ShowInstallProgramWindow=0
# HideExtractAnimation=1
# UseLongFileName=1
# InsideCompressed=0
# CAB_FixedSize=0
# CAB_ResvCodeSigning=0
# RebootMode=I
# InstallPrompt=%InstallPrompt%
# DisplayLicense=%DisplayLicense%
# FinishMessage=%FinishMessage%
# TargetName=%TargetName%
# FriendlyName=%FriendlyName%
# AppLaunched=%AppLaunched%
# PostInstallCmd=%PostInstallCmd%
# AdminQuietInstCmd=%AdminQuietInstCmd%
# UserQuietInstCmd=%UserQuietInstCmd%
# SourceFiles=SourceFiles
# [Strings]
# InstallPrompt=
# DisplayLicense=
# FinishMessage=
# TargetName=$EXEOutPath
# FriendlyName=$EXEFriendlyName
# AppLaunched=$($EXECmdline.Replace("$ContainerPath\", ''))
# PostInstallCmd=<None>
# AdminQuietInstCmd=
# UserQuietInstCmd=
# $SEDFiles
# [SourceFiles]
# $SEDFolders
# $objSEDFileStructure
# "@)
#
#     ## Exports the XML file which contains the original file and folder structure.
#     New-LogEntry -LogValue "Creating the SED file:`n`nSet-Content -Value xmlContent -Path $SEDOutPath -Force `n`r$SEDExportTemplate" -Component "Compress-MSIXAppInstaller" -Severity 1 -WriteHost $false
#     Set-Content -Value $SEDExportTemplate -Path $SEDOutPath -Force
#
#     ##############################  EXE  #######
#     ## Creates the self extracting executable ##
#
#     Start-Process -FilePath "iExpress.exe" -ArgumentList "/N $SEDOutPath" -wait
#    
#     $ObjMSIXAppDetails = New-Object PSObject
#     $ObjMSIXAppDetails | Add-Member -MemberType NoteProperty -Name "Filename"  -Value $($EXEOutPath.Replace($("$ContainerPath\"), ''))
#     $ObjMSIXAppDetails | Add-Member -MemberType NoteProperty -Name "Arguments" -Value $("/C:$($EXECmdline.Replace("$ContainerPath\", ''))")
#
#     ## Clean-up
#     Remove-Item $CMDScriptFilePath -Force
#     Remove-Item $ScriptFilePath -Force
#     Remove-Item $templateFilePath -Force
#     Remove-Item $SEDOutPath -Force
#
#     Return $ObjMSIXAppDetails
# }
