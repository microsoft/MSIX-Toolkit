Class ConversionParam{
    [ValidateNotNullOrEmpty()][String] $PackageDisplayName      ## MSIX App Display Name.
    [ValidateNotNullOrEmpty()][String] $PublisherDisplayName    ## MSIX App Publisher Display Name.
    [ValidateNotNullOrEmpty()][String] $PackageName             ## MSIX Application Package Name.
    [ValidateNotNullOrEmpty()][String] $PublisherName           ## MSIX Canonical Publisher Name.
    [ValidateNotNullOrEmpty()][String] $PackageVersion          ## MSIX App Package Version (#.#.#.#).
    [ValidateNotNullOrEmpty()][String] $InstallerPath           ## Path to App Installer used for Conversion.
    [String]$InstallerFolderPath        ## Used with ConfigMgr sourced app conversions, points to the install folder used for conversion on remote machine
    [String]$UninstallerPath            ## Used with ConfigMgr sourced app conversions, points to the uninstall folder. (Used only when installing with compression)
    [String]$UninstallerArgument        ## Used with ConfigMgr sourced app conversions, arguments to silently uninstall app.
    [String]$AppDescription             ## MSIX App description.
    [String]$CMAppPackageID             ## Used with ConfigMgr sourced app conversions, identifies the ConfigMgr Application Package ID.
    [String]$RequiresUserInteraction    ## Used with ConfigMgr sourced app conversions, identifies if the app installer is silent or interactive.
    [String]$AppFolderPath              ## Used with ConfigMgr sourced app conversions, identifies the UNC path to the ConfigMgr Application installer.
    [String]$AppInstallerFolderPath     ## Used with ConfigMgr sourced app conversions, identifies the app installer UNC folder path
    [String]$AppFileName                ## Used with ConfigMgr sourced app conversions, identifies the app file name.
    [String]$AppIntallerType            ## Used with ConfigMgr sourced app conversions, identifies the type of installation media used for app install.
    [String]$ContentID                  ## Used with ConfigMgr sourced app conversions, identifies which child folder (exported apps only) the app install exists.
    [String]$InstallerArguments         ## App installer arguments used for silent app installation.
    [String]$ExecutionContext           ## Used with ConfigMgr sourced app conversions, identifies if the app installs for User or Device.
    [String]$ContentParentRoot          ## Used with ConfigMgr sourced app conversions, identifies where the root app export folder exists.
    [String]$DeploymentType             ## Used with ConfigMgr sourced app conversions, identifies the name of the Deployment Type.
    $SavePackagePath                    ## Location where the newly created MSIX app will be saved to.
    $SaveTemplatePath                   ## Location of the Template.
}

Class TargetMachine{
    [String]$Name                       ## Name of the Virtual Machine (As seen in Hyper-V Console) being used to convert MSIX Applications.
    [String]$ComputerName               ## Computer name of the remote machine being used to convert MSIX Applications.
    $Credential                         ## Credentials used to connect to the virtual/remote machine.
    $ConversionJob                      ## Represents the conversion Job being executed on this virtual/remote machine.
}

Class CodeSigningCert{
    [string]$Password                   ## Password for the Code Signing Certificate being used to sign the MSIX app.
    [string]$Path                       ## Path to the Code Signing Certificate.
    $Publisher                  ## Canonical name of the Certificate Publisher.
}

Function New-LogEntry ([Parameter(Mandatory=$True,Position=0)][string] $LogValue,
                       [Parameter(Mandatory=$True,Position=1)][string] $Component,
                       [Parameter(Mandatory=$False,Position=2)][ValidateSet("1","2","3")][int] $Severity  = 1,
                       [Parameter(Mandatory=$False,Position=3)][boolean] $WriteHost = $true,
                       [Parameter(Mandatory=$False,Position=4)][string]  $Path      = $("C:\Temp\Projects\Test\Out\Log"),
                       [Parameter(Mandatory=$False,Position=5)][ValidateSet("white","black","Cyan")] [string]  $textcolor = "White")
{
    <#
    .SYNOPSIS
    Creates an entry into a log file, and optionally displays to console window.
    .DESCRIPTION
    This function will create a log file in the target path if non-existent, or will add to an existing log file. Entries created using this funciton will adhere to Trace32 log entry formatting. Optional outputting of information to the screen, allows for alternate text colours.
    .PARAMETER LogValue
    The string of text which will be added to the log file.    
    .PARAMETER Component
    A string representing where the logged entry originated from.
    .PARAMETER Severity
    An integer 1-3 which represents the severity of the log entry. 1 = Informational, 2 = Warning, and 3 = Error.
    .PARAMETER WriteHost
    A boolean flag which represents the output of logged entries to the screen.
    .PARAMETER Path
    Optional full path to the Log file to be written to.
    .PARAMETER textcolor
    The assigned text colour which will be used when displaying information to the screen. Default colour is White.
    .EXAMPLE
    New-LogEntry -LogValue "Message to be included in Log file." -Severity 1 -Component "[Function Name or Script File]"
    #>

    IF(!(Test-path -Path $Path)) {$Scratch = mkdir $Path}
    $Error.Clear()

    ## Formats the values required to enter for Trace32 Format
    [string]$Time = Get-Date -Format "HH:mm:ss.ffff"
    [string]$Date = Get-Date -Format "MM-dd-yyyy"

    ## Appends the newest log entry to the end of the log file in a Trace32 Formatting
    $('<![LOG['+$LogValue+']LOG]!><time="'+$Time+'" date="'+$Date+'" component="'+$component+'" context="Empty" type="'+$severity+'" thread="Empty" file="'+"Empty"+'">') | out-file -FilePath $($Path+"\BulkConversion.log") -Append -NoClobber -encoding default -ErrorAction SilentlyContinue -ErrorVariable LogError

    ## If Writing to log file fails try again.
    While ($Error.count -gt 0)
    {
        ## Gives a random amount of time to wait until next write attempt.
        $Error.Clear()
        Sleep($(get-random -Maximum 0.5 -Minimum 0.0))

        ## Appends the newest log entry to the end of the log file in a Trace32 Formatting
        $('<![LOG['+$LogValue+']LOG]!><time="'+$Time+'" date="'+$Date+'" component="'+$component+'" context="Empty" type="'+$severity+'" thread="Empty" file="'+"Empty"+'">') | out-file -FilePath $($Path+"\BulkConversion.log") -Append -NoClobber -encoding default -ErrorAction SilentlyContinue -ErrorVariable LogError
    }

    $LogValue | Out-File -Append -FilePath "$Path\BulkConversion-Log.txt"
    IF($WriteHost)
    {
        $LogValue | Out-File -Append -FilePath "$Path\BulkConversion-Display.txt"
        Write-Host $("" + $LogValue) -ForegroundColor $(switch ($Severity) {1 {$textcolor} 2 {"Yellow"} 3 {"Red"}})
    }
}

Function New-InitialSnapshot
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,Position=0 )] $VMName,
        [Parameter(Mandatory=$True,Position=1 )] $SnapshotName,
        [Parameter(Mandatory=$False,Position=2)] $jobId="--")

    <#
    .SYNOPSIS
    Creates a snapshot of the Virtual Machine.
    .DESCRIPTION
    Creates a snapshot using the name provided, of the target virtual machine.
    .PARAMETER SnapshotName
    String containing the name of the Hyper-V Snapshot to be created for the Virtual Machine.
    .PARAMETER VMName
    String containing the name of the Hyper-V VM which will have the snapshot created.
    .PARAMETER jobId
    Job counter used in the logging of events
    .EXAMPLE
    New-InitialSnapshot -SnapshotName "New Snapshot" -VMName "MSIX Conversion Environment" -JobID 1
    #>

    $FunctionName = Get-FunctionName
    ## Verifies if the script snapshot exists, if not exists snapshot is created.
    IF ($SnapshotName -cnotin $(Get-VMSnapshot -VMName $vmName).Name)
    {
        New-LogEntry -LogValue "Creating VM Snap for VM ($VMName): $SnapshotName" -Component "JobID($JobID) - $FunctionName" 
        $Scratch = Checkpoint-VM -Name $vmName -SnapshotName "$SnapshotName"
    }
    Else
    {
        New-LogEntry -LogValue "Snapshot ($SnapshotName) for VM ($VMName) already exists. " -Component "JobID($JobID) - $FunctionName"
    }
}

Function Restore-InitialSnapshot
{
    <#
    .SYNOPSIS
    Restores Hyper-V Virtual Machine to pre-existing snapshot.
    .DESCRIPTION
    Restores a snapshot using the provided name of the target virtual machine. 
    .PARAMETER SnapshotName
    String containing the name of the Hyper-V Snapshot to be created for the Virtual Machine.
    .PARAMETER VMName
    String containing the name of the Hyper-V VM which will have the snapshot created.
    .PARAMETER jobId
    Job counter used in the logging of events
    .EXAMPLE
    Restore-InitialSnapshot -SnapshotName "New Snapshot" -VMName "MSIX Conversion Environment" -JobID 1
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True, Position=0)][string] $VMName,
        [Parameter(Mandatory=$True, Position=1)][string] $SnapshotName,
        [Parameter(Mandatory=$False,Position=2)][string] $jobId="--")

    $FunctionName = Get-FunctionName

    IF ($SnapshotName -in $(Get-VMSnapshot -VMName $vmName).Name)
    {
        New-LogEntry -LogValue "Reverting Virtual Machine to earlier snapshot ($initialSnapshotName)" -Component "JobID($jobId) - $FunctionName"
        $Scratch = Restore-VMSnapshot -Name "$SnapshotName" -VMName $vmName -Confirm:$false

        Start-Sleep -Seconds 10
    }
}

Function Set-JobProgress 
{
    <#
    .SYNOPSIS
    Updates the PowerShell Progress bar status.
    .DESCRIPTION
    Calculates the script application conversion progression by dividing the in-progress and completed work with the total workload.
    .PARAMETER ConversionJobs
    Provides the list of jobs currently in progression or have been completed.
    .PARAMETER TotalTasks
    Provides the total number of jobs which need to be compelted.
    .EXAMPLE
    Set-JobProgress -ConversionJobs $ConversionJobs -TotalTasks 100
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True,Position=0)]      $ConversionJobs,
        [Parameter(Mandatory=$True,Position=1)][int] $TotalTasks)

    # Sets the Valiables
    $RunningJobs   = $($($ConversionJobs | where-object State -eq "Running").count)/2     ## Inprogress jobs are represented as 0.5/job
    $CompletedJobs = $($($ConversionJobs | where-object State -ne "Running").count)     ## Completed jobs are represented as 1/job

    # Updates the progression of each child job.
    foreach ($job in $ConversionJobs)
    {
        If($job.State -ne "Running")
            { Write-Progress -ID $job.id -Activity $job.Name -Completed -ParentID 0 }
        Else
            { Write-Progress -ID $job.id -Activity $job.Name -PercentComplete -1 -ParentID 0 }
    }

    # Updates the progression of the parent job
    If($($ConversionJobs | Where-object State -ne "Running").Count -eq $TotalTasks)
        { Write-Progress -ID 0 -Status "Completed" -Completed -Activity "Capture" }
    Else
        { Write-Progress -ID 0 -Status "Converting Applications..." -PercentComplete $($($($RunningJobs + $CompletedJobs)/$TotalTasks)*100) -Activity "Capture" }
}

function Get-FunctionName 
{
    <#
    .SYNOPSIS
    Retrieves the Name of the Function calling this Function.
    .DESCRIPTION
    Retrieves the Name of the Function calling this Function.
    .PARAMETER StackNumber
    How far back in the stack (chain) of parent calls to return the name of.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False,Position=0)][int]  $StackNumber = 1) 

    return [string]$(Get-PSCallStack)[$StackNumber].FunctionName
}

Function Test-Input 
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True,ParameterSetName="VMName-Exists"  )][ValidateNotNullOrEmpty()][string] $VMName,
        [Parameter(Mandatory=$True,ParameterSetName="VMSnapshot-Exists")][ValidateNotNullOrEmpty()][string] $SnapShotName,
        [Parameter(Mandatory=$True,ParameterSetName="CMApplication-Valid")][ValidateNotNullOrEmpty()] $CMApplication,
        [Parameter(Mandatory=$True,ParameterSetName="CMDeploymentType-Valid")][ValidateNotNullOrEmpty()] $CMDeploymentType,
        [Parameter(Mandatory=$True,ParameterSetName="CMServer-Exists")][ValidateNotNullOrEmpty()][string] $CMServer)

    ## If no validation tests can be found, default to failure.
    $ValidationResult = $false

    ## Validates an individual PowerShell Function Parameter input to ensure it meets requirements.
    Switch($PSCmdlet.ParameterSetName)
    {
        "VMName-Exists"
        {
            ## Validates that the VM Name exists, if so returns a passing value, otherwise throws an error message which will be displayed to the executing user.
            $ValidationResult = $(Get-VM).Name -contains $VMName
            IF(-not $ValidationResult)
                { Throw "$($Env:ComputerName) does not contain a VM with the name: $VMName. Please update the name and try again." }
        }
        "VMSnapshot-Exists"
        {
            ## Validates that the Snapshot Name exists, if so returns a passing value, otherwise throws an error message which will be displayed to the executing user.
            $ValidationResult = $(Get-VMSnapshot -VMName *).Name -contains $SnapShotName
            IF(-Not $ValidationResult)
                { Throw "$($Env:ComputerName) does not contain a VM with a snapshot labeled as: $SnapShotName. Please update the name and try again." }
        }
        "CMApplication-Valid"
        {
            ## Validates that the application contains an Application Name.
            $ValidationResult = [Boolean]$([Boolean]$($CMApplication.LocalizedDisplayName.Length -gt 0) -or [Boolean]$($CMApplication.Instance.Property.Where({$_.Name -eq "LocalizedDisplayName"}).Value.Length -gt 0))
            IF(-Not $ValidationResult)
                { Throw "The application provided was unable to be identified. There appears to be missing information" }
        }
        "CMServer-Exists"
        {
            ## Validates that the ConfigMgr Server is accessible.
            $ValidationResult = [boolean]$(Test-Connection -ComputerName $CMServer)
            IF(-Not $ValidationResult)
                { Throw "$($Env:ComputerName) was unable to contact ConfigMgr Server $CMServer. Please verify the name of the server and try again." }
        }
        "CMDeploymentType-Valid"
        {
            $XML = ""
            IF($($CMDeploymentType.count -le 1))
                { $XML = [XML]$($CMDeploymentType) }
            Else 
                { $XML = [XML]$($CMDeploymentType[0].SDMPackageXML) }

            ## Validates that the ConfigMgr Application Deployment Type has a name.
            $ValidationResult = [Boolean]$($xml.AppMgmtDigest.DeploymentType.Installer.Contents.Content.ContentID)
            IF(-Not $ValidationResult)
                { Throw "The Deployment Type [XML] provided was unable to be identified. There appears to be missing information." }

        }
    }

    Return $ValidationResult
}