<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.EXAMPLE
An example

.NOTES
Future Enhancements:
    - Provide AppV Conversion to MSIX Support
    - Filter Applications in ConfigMgr by Folder.
#>



############################
##  Variable Declaration  ##
############################

## Work on AppV
## Selective App conversions
##   - List of Folder
##   - individual, or selective apps


#Script Libraries required to run this script.
. $PSScriptRoot\..\BulkConversion\SharedScriptLib.ps1

$SupportedInstallerType    = @("MSI","Script")
$SupportedConfigMgrVersion = ""
$InitialLocation           = Get-Location
$VerboseLogging            = $true
$__JobID                   = 0

#### This Function can be deleted? ####
Function Test-PSArchitecture
{
    <#
    .SYNOPSIS
    Validates the architecture of the running PowerShell window..
    
    .DESCRIPTION
    This Function will query the architecture of the PowerShell window running the script. By default this function will returning an error if the architecture is no x64.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False,Position=0)][ValidateSet("x64", "x86")][string] $Architecture,
        [Parameter(Mandatory=$False,Position=1)] $workingDirectory
    )

    ## Sets and initialized the variables for use in this function.
    Begin{
        $FunctionName     = Get-FunctionName
        $LoggingComponent = "JobID(-) - $FunctionName"
        $LoggingSeverity  = 1
        $PSArchitecture   = ""
    }

    ## Determins the architecture of the executing PowerShell window
    Process {
        If([intPtr]::size -eq 4) 
        { 
            ## Sets logging Severity level based on target architecture of the executing PowerShell window.
            IF($Architecture -ne "x86")
                { $LoggingSeverity = 3 }

            $PSArchitecture = "x86"
        }
        ELSE 
        { 
            ## Sets logging Severity level based on target architecture of the executing PowerShell window.
            IF($Architecture -ne "x64")
                { $LoggingSeverity = 3 }                

            $PSArchitecture = "x64"
        }
    }

    ## Logs the result appropriatly and returns the current architecture.
    End{
        New-LogEntry "PowerShell Architecture is $PSArchitecture" -Severity $LoggingSeverity -Component $LoggingComponent -Path $WorkingDirectory
        Return $PSArchitecture
    }
    
}

function Connect-CMEnvironment 
{
    <#
    .SYNOPSIS
    Imports ConfigMgr PowerShell cmdlets, and initiates a connection to ConfigMgr through PS Drive.
    .DESCRIPTION
    Imports the the ConfigMgr PowerShell module enabling the use of ConfigMgr PowerShell cmdlets. Then attempts to connect to ConfigMgr using PSDrive. If no location exists in PSDrive, then it is created before connecting to.
    .PARAMETER CMSiteCode
    This is the ConfigMgr 3 character site code belonging to the provided Site Server.
    .PARAMETER CMSiteServer
    This is the ConfigMgr Primary Site, Site Server that will be connected to.
    .EXAMPLE
    Connect-CMEnvrionment -CMSiteServer PRI-SiteServer.contoso.com -CMSiteCode CM1
    #>

    ## Function Parameters Inputs
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True, Position=0 )][ValidateLength(2,4)][String] $CMSiteCode,
        [Parameter(Mandatory=$False,Position=1)][ValidateScript({Test-Input -CMServer $_})][String] $CMSiteServer,
        [Parameter(Mandatory=$False,Position=2)] $workingDirectory
    )

    ## Imports the Module required for connecting to ConfigMgr and using of the ConfigMgr powershell cmdlets.
    Begin {
        ## Sets the Function Name for use in Logging.
        $FunctionName = Get-FunctionName 1
        $LoggingComponent = "JobID(-) - $FunctionName"

        New-LogEntry -LogValue "Connecting to the $($CMSiteCode) ConfigMgr PowerShell Environment..." -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory
    }

    ## Checks for the existence of a ConfigMgr Site in PSDrive, if missing it will create a new reference and attempt to connect.
    Process {
        Import-Module $ENV:SMS_ADMIN_UI_PATH.replace("bin\i386","bin\ConfigurationManager.psd1")

        ## If No Site exists in PS Drive, it will create it.
        if($null -eq (Get-PSDrive -Name $CMSiteCode -PSProvider CMSite -ErrorAction SilentlyContinue))
        {
            $initParams = @{}
            New-PSDrive -Name $CMSiteCode -PSProvider CMSite -Root $CMSiteServer @initParams
        }

        ## Checks that the PS Drive Exists, and then attempts to connect
        $SiteLocation = Get-PSDrive -PSProvider CMSITE | Where-Object {$_.Name -eq $CMSiteCode}

        IF($SiteLocation)
        {
            New-LogEntry -LogValue "Connecting to ($SiteLocation)..." -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory
            Set-Location "$($SiteLocation):"
            
            IF($(Get-Location) -like "$($SiteLocation.Name)*")
            {
                New-LogEntry -LogValue "Connected Successfully to $($CMSiteCode) ConfigMgr PowerShell Environment..." -Component $LoggingComponent -Path $WorkingDirectory
                $ReturnResults = $True
            }
            else
            {
                New-LogEntry -LogValue "Connection Failed..." -Component $LoggingComponent -Path $WorkingDirectory -Severity 2
                $ReturnResults = $False
            }
        }
        ELSE
        {
            New-LogEntry -LogValue "Could not identify ConfigMgr Site using ""$CMSiteCode"" Site Code." -Component $LoggingComponent -Path $WorkingDirectory -Severity 2
            $ReturnResults = $False
        }
    }
    

    ## Logs the results to the log file, and returns boolean based on the identification and conneciton to the ConfigMgr Site
    End {
        Return $ReturnResults
    }
}

function Disconnect-CMEnvironment
{
    <#
    .SYNOPSIS
    Disconnects from the ConfigMgr PSDrive connection
    .DESCRIPTION
    Disconnects from the ConfigMgr PSDrive connection
    .PARAMETER ReturnPreviousLocation
    Boolean, represents whether the previous address should be returned as a string
    .EXAMPLE
    Disconnect-CMEnvironment
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False,Position=0)][boolean] $ReturnPreviousLocation=$false,
        [Parameter(Mandatory=$False,Position=1)] $workingDirectory
    )

    ## Updates the "PreviousLocation" variable with the current location beore exiting the CM Environment.
    Process{
        $PreviousLocation = Get-Location
        Set-Location $InitialLocation
    }
    
    ## If ReturnPreviousLocation is set as True, then this will return the CM Environment location.
    End{
        IF($ReturnPreviousLocation){Return $PreviousLocation}
    }
}

function Format-MSIXAppExportDetails 
{
    <#
    .SYNOPSIS
    Creates the ConversionParamter Class object and populates with information retrieved from a ConfigMgr Source (DB or App Export)
    
    .DESCRIPTION
    Creates the ConversionParamter Class object and populates with information retrieved from a ConfigMgr Source (DB or App Export)
    
    .PARAMETER Application
    [Optional] - Application being filtered for.
    
    .PARAMETER ApplicationDeploymentType
    Contains the Deployment Type information
    
    .PARAMETER CMExportAppPath
    Contains the path to the ConfigMgr App Install Files
    
    .PARAMETER CMAppPath
    Contains the path
    
    .PARAMETER CMServer
    Contains the name of the ConfigMgr Primary Site Site Server
    
    .PARAMETER SigningCertificate
    Contains the Code signing certificate information as class "SigningCertificate" object.
    
    .EXAMPLE
    Format-MSIXAppExportDetails -ApplicationDeploymentType $AppDT -SigningCertificate $AppSigningCertificate -CMServer "CM1-SiteServer.contoso.com"
    #>
    [CmdletBinding(DefaultParameterSetName='CMServer')]
    Param(
        [Parameter(Mandatory=$False)][ValidateScript({Test-Input -CMApplication $_})] $Application, 
        [Parameter(Mandatory=$False)][ValidateScript({Test-Input -CMDeploymentType $_})] $ApplicationDeploymentType,
        [Parameter(Mandatory=$True,ParameterSetName=$('CMExportedApp'),Position=0)] $CMExportAppPath,
        [Parameter(Mandatory=$True,ParameterSetName=$('CMExportedApp'),Position=1)] $CMAppPath,
        [Parameter(Mandatory=$True,ParameterSetName=$('CMServer'))][Switch] $CMServer,
        [Parameter(Mandatory=$False)][CodeSigningCert] $SigningCertificate,
        [Parameter(Mandatory=$False)] $workingDirectory
    )
    
    ## Sets and validates variable inputs.
    Begin {
        ## Sets the Function Name - used in logging.
        $FunctionName     = Get-FunctionName
        $AppDetails       = @()
        $LoggingComponent = "Job($__JobID) - $FunctionName"

        ###############################
        ## Variable input Validation ##
        ###############################

        ## Validate Parameter Set Values
        Switch ($PSCmdlet.ParameterSetName)
        {
            "CMExportedApp" 
            { 
                ##########################
                #### $CMExportAppPath ####
                IF($CMExportAppPath -eq "" -or $null -eq $CMExportAppPath)
                { 
                    $ErrorMessage = "The ConfigMgr export app path can not be null or empty. Please provide a value, and try again."
                    New-LogEntry -LogValue $ErrorMessage -Severity 3 -Component $LoggingComponent -Path $WorkingDirectory
                    Write-Error $ErrorMessage
                }
                
                ####################
                #### $CMAppPath ####
                IF($CMAppPath -eq "" -or $null -eq $CMAppPath)
                { 
                    $ErrorMessage = "The ConfigMgr app path can not be null or empty. Please provide a value, and try again."
                    New-LogEntry -LogValue $ErrorMessage -Severity 3 -Component $LoggingComponent -Path $WorkingDirectory
                    Write-Error $ErrorMessage
                }
            }
            "CMServer"      
            { 
            }
        }

        #############################
        #### $SigningCertificate ####
        IF($SigningCertificate -eq "" -or $null -eq $SigningCertificate)
        { 
            $ErrorMessage = "The code signing certificate can not be null or empty. Please provide a value, and try again."
            New-LogEntry -LogValue $ErrorMessage -Severity 3 -Component $LoggingComponent -Path $WorkingDirectory
            Write-Error $ErrorMessage
        }

        #######################################
        #### $SigningCertificate Publisher ####
        ELSEIF($SigningCertificate.Publisher -eq "" -or $null -eq $SigningCertificate.Publisher)   
        { 
            $ErrorMessage = "The code signing certificate can not be null or empty. Please provide a value, and try again."
            New-LogEntry -LogValue $ErrorMessage -Severity 3 -Component $LoggingComponent -Path $WorkingDirectory
            Write-Error $ErrorMessage
        }

        ######################
        #### $Application ####
        IF($Application -eq "" -or $null -eq $Application)
        { 
            $ErrorMessage = "The application can not be null or empty. Please provide a value, and try again."
            New-LogEntry -LogValue $ErrorMessage -Severity 3 -Component $LoggingComponent -Path $WorkingDirectory
            Write-Error $ErrorMessage
        }

        #################################
        ## Set Initial Variable Values ##
        #################################

        ##################
        #### $AppName ####
        Switch ($PSCmdlet.ParameterSetName)
        {
            "CMExportedApp" 
            { 
                $AppName = $($Application.Instance.Property.Where({$_.Name -eq "LocalizedDisplayName"}).Value)

                ## Variable Validation - Error if null or empty
                IF($AppName -eq "" -or $null -eq $AppName)
                { 
                    $ErrorMessage = "The ConfigMgr export app name can not be null or empty. Please provide a value, and try again." 
                    New-LogEntry -LogValue $ErrorMessage -Severity 3 -Component $LoggingComponent -Path $WorkingDirectory
                    Write-Error $ErrorMessage
                }
            }
            "CMServer"      
            { 
                $AppName = $($Application.LocalizedDisplayName) 

                ## Variable Validation - Error if null or empty
                IF($AppName -eq "" -or $null -eq $AppName)
                {
                    $ErrorMessage = "The ConfigMgr app name can not be null or empty. Please provide a value, and try again."
                    New-LogEntry -LogValue $ErrorMessage -Severity 3 -Component $LoggingComponent -Path $WorkingDirectory
                    Write-Error $ErrorMessage
                }
            }
        }

        ####################################
        #### $ApplicationDeploymentType ####
        IF($($ApplicationDeploymentType.count -le 1))
            { $XML = [XML]$($ApplicationDeploymentType) }
        Else 
            { $XML = [XML]$($ApplicationDeploymentType[0].SDMPackageXML) }
    }

    ## Creates and populates ConversionParam object.
    Process{
        New-LogEntry -LogValue "Parsing through the Deployment Types of $AppName application." -Component $LoggingComponent -Path $WorkingDirectory -WriteHost $true

        Foreach($Deployment IN $($XML.AppMgmtDigest.DeploymentType))
        {
            $LoggingComponent = "JobID($__JobID) - $FunctionName"
            $__JobID ++
            New-LogEntry -LogValue "  Parsing the Application (""$AppName""), currently recording information from Deployment Type:  ""$($Deployment.Title.'#text')""" -Component $LoggingComponent -Path $WorkingDirectory -WriteHost $true -textcolor "Cyan"

            $MSIXAppDetails           = [ConversionParam]::New()
            $InstallerArgument        = ""
            $objContentPath           = ""

            #############################
            ## Application Information ##
            $_AppInstallerType        = $Deployment.Installer.Technology
            $_ExecutionContext        = $Arg.'#text'
            $_AppFolderPath           = $Deployment.Installer.Contents.Content.Location
            $_PublisherName           = $SigningCertificate.Publisher
            $_ContentID               = $($Deployment.Installer.Contents.Content.ContentID)
            $_DeploymentType          = $Deployment.Title.'#text'

            #########################
            ## Install Information ##
            $objInstallerAction       = Get-MSIXConnectInstallInfo -DeploymentAction $($Deployment.Installer.InstallAction) -InstallerTechnology $($Deployment.Installer.Technology) -WorkingDirectory $WorkingDirectory
            $_AppFileName             = $objInstallerAction.Filename
            $_InstallerArgument       = Format-MSIXPackageInfo -AppArgument $($objInstallerAction.Argument) -ErrorAction SilentlyContinue -ErrorVariable Err -WorkingDirectory $WorkingDirectory
            
            New-LogEntry -LogValue "    $($("Install String:").PadRight(22))  $($Deployment.Installer.InstallAction.Args.Arg.Where({$_.Name -eq "InstallCommandLine"}).'#text')" -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory
            New-LogEntry -LogValue "    $($("Install Filename:").PadRight(22))  |$_AppFileName| |$_InstallerArgument|" -Severity 1 -Component $LoggingComponent -Path $WorkingDirectory

            ###########################
            ## Uninstall Information ##
            $objUninstallerAction     = Get-MSIXConnectInstallInfo -DeploymentAction $($Deployment.Installer.UninstallAction) -InstallerTechnology $($Deployment.Installer.Technology) -WorkingDirectory $WorkingDirectory
            $_UninstallerPath         = $objUninstallerAction.Filename
            $_UninstallerArgument     = Format-MSIXPackageInfo -AppArgument $($objUninstallerAction.Argument) -ErrorAction SilentlyContinue -ErrorVariable Err -WorkingDirectory $WorkingDirectory

            Switch($PSCmdlet.ParameterSetName)
            {
                "CMExportedApp"
                {
                    $_PackageName            = $($(Format-MSIXPackageInfo -AppName "$($Application.Instance.Property.Where({$_.Name -eq "LocalizedDisplayName" }).Value)-$($_ContentID.Substring($_ContentID.Length-6, 6))" -WorkingDirectory $WorkingDirectory ))
                    $_PackageDisplayName     = $Application.Instance.Property.Where({$_.Name -eq "LocalizedDisplayName"}).Value
                    $_PublisherDisplayname   = $Application.Instance.Property.Where({$_.Name -eq "Manufacturer"}).Value
                    $_ApplicationDescription = $Application.Instance.Property.Where({$_.Name -eq "LocalizedDescription"}).Value
                    $_CMAppPackageID         = $Application.Instance.Property.Where({$_.Name -eq "PackageID"}).Value
                    $_ContentParentRoot      = $($CMAppPath.Directory.Parent.Parent.Name)
                    $_AppInstallerFolderPath = $("$(Get-Item -Path $($CMExportAppPath.Where({$_.FullName -like "*$($_ContentParentRoot)*$($Deployment.Installer.Contents.Content.ContentID)"})).FullName)\")
                    $_InstallerPath          = $(Get-Item -Path $("$_AppInstallerFolderPath\$_AppFileName")).FullName
                    $_InstallerFolderPath    = $($(Get-Item -Path $("$_AppInstallerFolderPath")).FullName)
                    $_UninstallerPath        = $(Get-Item -Path $("$_AppInstallerFolderPath\$_UninstallerPath") -ErrorAction SilentlyContinue).FullName
                    $_PackageVersion         = Format-MSIXPackageInfo -AppVersion $($Application.Instance.Property.Where({$_.Name -eq "SoftwareVersion"}).Value) -WorkingDirectory $WorkingDirectory
                }
                "CMServer"
                {
                    $_PackageName            = $($(Format-MSIXPackageInfo -AppName "$($Application.LocalizedDisplayName)-$($_ContentID.Substring($_ContentID.Length-6, 6))" -WorkingDirectory $WorkingDirectory ))
                    $_PackageDisplayName     = $Application.LocalizedDisplayName
                    $_PublisherDisplayname   = $Application.Manufacturer
                    $_ApplicationDescription = $Application.LocalizedDescription
                    $_CMAppPackageID         = $Application.PackageID
                    $_AppInstallerFolderPath = $(Get-Item -Path $($Deployment.Installer.Contents.Content.Location)).FullName
                    $_CMInstallerFolderPath  = $(Get-Item -Path $($Deployment.Installer.Contents.Content.Location)).FullName
                    $_CMInstallerPath        = $($_CMInstallerFolderPath + $_AppFileName)
                    $_InstallerFolderPath    = $("C:\Temp\" + $($_AppInstallerFolderPath.TrimStart("\")))
                    $_InstallerPath          = $($_InstallerFolderPath + $_AppFileName)
                    $_UninstallerPath        = $($_UninstallerPath)
                    $_ContentParentRoot      = $("")
                    $_PackageVersion         = Format-MSIXPackageInfo -AppVersion $($Application.SoftwareVersion) -WorkingDirectory $WorkingDirectory
                }
            }

            ############################################
            ## Setting Conversion Param Object values ##
            $MSIXAppDetails.PackageDisplayName      = $_PackageDisplayName
            $MSIXAppDetails.PublisherDisplayName    = $_PublisherDisplayname
            $MSIXAppDetails.AppDescription          = $_ApplicationDescription
            $MSIXAppDetails.CMAppPackageID          = $_CMAppPackageID
            $MSIXAppDetails.PackageName             = $_PackageName
            $MSIXAppDetails.PublisherName           = $_PublisherName
            $MSIXAppDetails.PackageVersion          = $_PackageVersion
            $MSIXAppDetails.RequiresUserInteraction = $_RequiresUserInteraction
            $MSIXAppDetails.AppFolderPath           = $_AppFolderPath
            $MSIXAppDetails.AppInstallerFolderPath  = $_AppInstallerFolderPath
            $MSIXAppDetails.AppFileName             = $_AppFileName
            $MSIXAppDetails.AppIntallerType         = $_AppInstallerType
            $MSIXAppDetails.ContentID               = $_ContentID
            $MSIXAppDetails.InstallerArguments      = $_InstallerArgument
            $MSIXAppDetails.ExecutionContext        = $_ExecutionContext
            $MSIXAppDetails.ContentParentRoot       = $_ContentParentRoot
            $MSIXAppDetails.InstallerPath           = $_InstallerPath
            $MSIXAppDetails.InstallerFolderPath     = $_InstallerFolderPath
            $MSIXAppDetails.UninstallerPath         = $_UninstallerPath
            $MSIXAppDetails.UninstallerArgument     = $_UninstallerArgument
            $MSIXAppDetails.DeploymentType          = $_DeploymentType
            $MSIXAppDetails.CMInstallerPath         = $_CMInstallerPath
            $MSIXAppDetails.CMInstallerFolderPath   = $_CMInstallerFolderPath

            # SupportedInstallerType is set at the top of this script. More file types will need to be included.
            IF ($SupportedInstallerType.Contains($($Deployment.Installer.Technology)))
                { [ConversionParam[]]$AppDetails += $MSIXAppDetails }
            ELSE
                { New-LogEntry -LogValue "The ""$($Application.LocalizedDisplayName)"" application type is currently unsupported." -Component $LoggingComponent -Path $WorkingDirectory -Severity 3 }

            Write-Host ""
        }
    }

    ## Returns the ConversionParam object.
    End{
        Return $AppDetails
    }
}

Function Get-MSIXConnectInstallInfo 
{
    <#
    .SYNOPSIS
    Returns the Application File Name and Installation Arguments.
    
    .DESCRIPTION
    Parses through the application installation string, identify the file name and install arguments that are used. Returns just those values.
    
    .PARAMETER DeploymentAction
    This is the Deployment Action.
    
    .PARAMETER InstallerTechnology
    Deployment Type Installer Technology (Script, MSI, AppV, etc...)
    
    .EXAMPLE
    $Variable = Get-MSIXConnectInstallInfo -DeploymentAction $DeploymentAction -InstallerTechnology $DeploymentType.InstallerTechnology
    
    .NOTES
    General notes
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True,Position=0)]         $DeploymentAction,
        [Parameter(Mandatory=$True,Position=1)][string] $InstallerTechnology,
        [Parameter(Mandatory=$False)] $workingDirectory
    )

    ## Verifies variable inputs, and sets function required variables.
    Begin {
        ###############################
        ## Variable input Validation ##
        ###############################

        ###########################
        #### $DeploymentAction ####
        IF($null -eq $DeploymentAction -or "" -eq $DeploymentAction)
            { Write-Error "The deployment action can not be null or empty. Please provide a value, and try again."}

        ################################################
        #### $DeploymentAction...InstallCommandLine ####
        IF($null -eq $($DeploymentAction.Args.Arg.Where({$_.Name -eq "InstallCommandLine"}).'#text'))
            { Return }

        #############################
        #### InstallerTechnology ####
        IF($null -eq $InstallerTechnology -or "" -eq $InstallerTechnology)
            { Write-Error "The deployment action can not be null or empty. Please provide a value, and try again."}


        #################################
        ## Set Initial Variable Values ##
        #################################

        
        $FunctionName             = Get-FunctionName
        $LoggingComponent         = "Job($__JobID) - $FunctionName"
        $objInstallerAction       = $DeploymentAction.Args.Arg.Where({$_.Name -eq "InstallCommandLine"}).'#text'
        $objInstallerFileName     = $objInstallerAction
        $objInstallerArgument     = ""
        $objTempInstallerArgument = $objInstallerAction
        $AppTypes                 = @( ".exe", ".msi" )
        $objInstallerActions      = New-Object PSObject
    }

    ## Identifies the Filename and Arguments used in the installation of the application
    Process{
        ########################
        ## Installer FileName ##
        ########################
        
        ## Checks for end of line space, and removes.
        IF($objInstallerFileName.EndsWith(" "))
            { $objInstallerFileName = $objInstallerFileName.Substring(0, $($objInstallerFileName.Length - 1)) }

        
        foreach($Extension in $AppTypes)
        {
            ## Confirms the installation media is of a supported installer type.
            IF( $($objInstallerFileName.IndexOf($Extension)) -gt 0 )
            { 
                IF($($objInstallerFileName.Length) -gt $($objInstallerFileName.IndexOf($Extension) + 5))
                    { $objInstallerFileName = $objInstallerFileName.Substring(0, $($objInstallerFileName.IndexOf($Extension) + 5)) }
            }
        }

        #########################
        ## Installer Arguments ##
        #########################

        ## Only retrieves the installation arguments if ConfigMgr Deployment Type is of type "Script"
        IF($InstallerTechnology -eq "Script")
        {
            ## Determines if the installer contains any install arguments
            IF($($objTempInstallerArgument.Length) -gt $($objInstallerFileName.Length))
                { $objInstallerArgument = $objTempInstallerArgument.Substring($($objInstallerFileName.Length), $($objTempInstallerArgument.Length)-$($objInstallerFileName.Length)) }
            else 
                { $objInstallerArgument = "" }
        }

        ## Removes the double quotes from the string
        $objInstallerFileName = $objInstallerFileName -replace '"', ''
        $objInstallerFileName = $objInstallerFileName -replace ' ', ''
        $objInstallerArgument = $objInstallerArgument -replace '"', ''''

        ## Creates and populates the custom object with the Filename and Arugments.
        $objInstallerActions | Add-Member -MemberType NoteProperty -Name "FileName" -Value $($objInstallerFileName)
        $objInstallerActions | Add-Member -MemberType NoteProperty -Name "Argument" -Value $($objInstallerArgument)
    }

    ## Returns a custom object containing the File Name and Argument
    End{
        Return $objInstallerActions
    }
    
}

Function Format-MSIXPackageInfo 
{
    <#
    .SYNOPSIS
    Ensures the MSIX Packaging information adhering to MSIX Packaging Tool requirements
    
    .DESCRIPTION
    Ensures the MSIX Packaging information adhering to MSIX Packaging Tool requirements
    
    .PARAMETER AppVersion
    Version of the application which will be used in the MSIX metadata
    
    .PARAMETER AppArgument
    Application installation argument which will be added to the MPT Template
    
    .PARAMETER AppName
    Application Name which will be added to the MPT Template
    
    .PARAMETER JobID
    Identifies which job in the sequence is being worked on
    
    .EXAMPLE
    Format-MSIXPackageInfo -AppName "This is a demonstration" -JobID 1
    
    .NOTES
    General notes
    #>
    [CmdletBinding(DefaultParameterSetName='PackageName')]
    Param(
        [Parameter(Mandatory=$True, ParameterSetName=$('PackageVersion'), Position=0)][AllowEmptyString()][AllowNull()][string] $AppVersion,
        [Parameter(Mandatory=$True, ParameterSetName=$('PackageArgument'),Position=0)][AllowEmptyString()][AllowNull()][string] $AppArgument,
        [Parameter(Mandatory=$True, ParameterSetName=$('PackageName'),    Position=0)][AllowEmptyString()][AllowNull()][string] $AppName,
        [Parameter(Mandatory=$False,Position=1)][string] $JobID="-",
        [Parameter(Mandatory=$False)] $workingDirectory
    )
    
    ## Paramter input validation, and setting variables required by function
    Begin{
        $FunctionName = Get-FunctionName
        $LoggingComponent = "JobID($JobID) - $FunctionName"
        $LoggingWriteHost = $($ErrorActionPreference -ne "SilentlyContinue")

        ###############################
        ## Variable input Validation ##
        ###############################

        ## Validate Parameter Set Values
        switch ($PSCmdlet.ParameterSetName) 
        {
            "PackageName"     
            {
                IF($null -eq $AppName -or "" -eq $AppName)
                {
                    $ErrorMessage = "    The application name can not be null or empty. Please provide a value, and try again."
                    New-LogEntry -LogValue $ErrorMessage -Severity 3 -Component $LoggingComponent -Path $WorkingDirectory -WriteHost $LoggingWriteHost
                    Return
                }
            }
            "PackageArgument" 
            {
                ## Variable Validation - Error if null or empty
                IF($null -eq $AppArgument -or "" -eq $AppArgument)
                { 
                    $ErrorMessage = "    The application argument can not be null or empty. Please provide a value, and try again."
                    New-LogEntry -LogValue $ErrorMessage -Severity 3 -Component $LoggingComponent -Path $WorkingDirectory -WriteHost $LoggingWriteHost
                    Return
                }
            }
            "PackageVersion"  
            {
                ## Variable Validation - Error if null or empty
                IF($null -eq $AppVersion -or "" -eq $AppVersion)
                { 
                    $ErrorMessage = "    The application version can not be null or empty. Please provide a value, and try again."
                    New-LogEntry -LogValue $ErrorMessage -Severity 3 -Component $LoggingComponent -Path $WorkingDirectory -WriteHost $LoggingWriteHost
                    Return
                }
            }
        }
        
        $ReturnResults = ""
    }

    ## Ensures that the information provided aligns with MSIX Packaging Tool requirements
    Process{
        switch ($PSCmdlet.ParameterSetName) 
        {
            "PackageName"     
            {    
                New-LogEntry -LogValue "    Removing Special Characters from the Application Package Name." -Component $LoggingComponent -Path $WorkingDirectory -Severity 1 -WriteHost $VerboseLogging
                $MSIXPackageName = $AppName -replace '[!,@,#,$,%,^,&,*,(,),+,=,~,`]',''
                $MSIXPackageName = $MSIXPackageName -replace '_','-'
                $MSIXPackageName = $MSIXPackageName -replace ' ','-'
            
                IF($MSIXPackageName.Length -gt 43)
                    { $MSIXPackageName = $MSIXPackageName.Substring(0,43) }
            
                $ReturnResults = $MSIXPackageName
            }
            "PackageArgument" 
            {
                IF($AppArgument.StartsWith(" "))
                    { $AppArgument = Format-MSIXPackageInfo -AppArgument $AppArgument.Substring(1, $AppArgument.Length -1) -ErrorAction SilentlyContinue -WorkingDirectory $WorkingDirectory }
    
                $ReturnResults = $AppArgument
            }
            "PackageVersion"  
            {
                ## Removes the less-desirable characters.
                $MSIXPackageVersion = $AppVersion -replace '[!,@,#,$,%,^,&,*,),+,=,~,`]',''
                $MSIXPackageVersion = $MSIXPackageVersion -replace '[_,(]','.'
                $MSIXPackageVersion = $MSIXPackageVersion -replace ' ',''
                $MSIXPackageVersion = $MSIXPackageVersion -replace '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z]',''
            
                $Index = 0
                $NewPackageVersion = ""
                
                ## Ensures the version is 4 octets.
                Foreach ($VerIndex in $($MSIXPackageVersion.Split('.')))
                {
                    ## By declaring this as Int, removes leading zeros.
                    [int]$Version = $VerIndex
            
                    ## Adds the values for each octet into its octet.
                    If($Index -le 2)
                        { $NewPackageVersion += $("$Version.") }
                    If($Index -eq 3)
                        { $NewPackageVersion += $("$Version") }
            
                    ## Incremets the octet counter.
                    $Index++
                }
            
                ## Appends the correct number of 0's to tne end of the version.
                switch ($Index) {
                    3 { $NewPackageVersion += "0" }
                    2 { $NewPackageVersion += "0.0" }
                    1 { $NewPackageVersion += "0.0.0" }
                    0 { $NewPackageVersion += "0.0.0.0" }
                    Default {}
                }
            
                ## Returns the newly updated version octet adhereing to the specified requirements.
                $ReturnResults = $NewPackageVersion
            }
            Default {}
        }
    }

    ## Returns the updated value
    End{
        Return $ReturnResults
    }

}

Function Get-CMExportAppData 
{
    <#
    .SYNOPSIS
    Retrieves information from ConfigMgr (DB or Exported Apps) creating a ConversionParamter class object for use in conversion
    .DESCRIPTION
    Retrieves information from ConfigMgr (DB or Exported Apps) creating a ConversionParamter class object for use in conversion
    .PARAMETER SigningCertificate
    This is the SigningCertificate class object which contains the information for the code signing certificate which will be used for signing the completed converted app.
    .PARAMETER AppName
    [Optional] This is the name of the app which will be filtered for.
    .PARAMETER CMAppContentPath
    File Path to the ConfigMgr App export (_Files).
    .PARAMETER CMAppMetaDataPath
    File Path to the ConfigMgr App Export (MetaData)
    .PARAMETER CMAppParentPath
    File Path to the folder which contains both the App Export MetaData, and application files.
    .PARAMETER CMSiteCode
    This is the ConfigMgr 3 character site code.
    .PARAMETER CMSiteServer
    This is the ConfigMgr Primary Site Site Server which holds the application installation information
    .EXAMPLE
    Get-CMExportAppData -SigningCertificate $CodeSigningCertificate -CMSiteCode CM1 -CMSiteServer "CM1-SiteServer.contoso.com"
    #>

    [CmdletBinding(DefaultParameterSetName='CMServer')]
    param (
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][CodeSigningCert] $SigningCertificate,
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]          $AppName="*",
        [Parameter(Mandatory=$True,ParameterSetName=$('CMExportPathTarget'),Position=0)][string] $CMAppContentPath,
        [Parameter(Mandatory=$True,ParameterSetName=$('CMExportPathTarget'),Position=1)][string] $CMAppMetaDataPath,
        [Parameter(Mandatory=$True,ParameterSetName=$('CMExportPathParent'),Position=0)][string] $CMAppParentPath,
        [Parameter(Mandatory=$True,ParameterSetName=$('CMServer'), Position=0)][string] $CMSiteCode,
        [Parameter(Mandatory=$True,ParameterSetName=$('CMServer'), Position=1)][string] $CMSiteServer,
        [Parameter(Mandatory=$False)] $workingDirectory
    )

    ## Verify user input parameters and sets varaibles required by function.
    Begin{
        $FunctionName = Get-FunctionName
        $LoggingComponent = "JobID(-) - $FunctionName"

        ###############################
        ## Variable input Validation ##
        ###############################

        #############################
        #### $SigningCertificate ####
        IF($null -eq $SigningCertificate)
            { New-LogEntry -LogValue "Signing Certificate provided is null." -Severity 2 -Component $LoggingComponent -Path $WorkingDirectory }
        ELSEIF($($SigningCertificate.Publisher) -eq "" -or $null -eq $($SigningCertificate.Publisher))
            { New-LogEntry -LogValue "Signing Certificate provided does not have a Publisher specified" -Severity 2 -WriteHost $True -Component $LoggingComponent -Path $WorkingDirectory}

        ## Validate Parameter Set Values
        Switch ($PSCmdlet.ParameterSetName)
        {
            "CMExportPathTarget" 
            {
                ###########################
                #### $CMAppContentPath ####
                $TestPath = Get-Item $CMAppContentPath -ErrorAction SilentlyContinue
                IF(-not $TestPath.Exists)
                {
                    ## If Value does not resolve to a location fail, and exit
                    New-LogEntry -LogValue "" -Severity 3 -WriteHost $True -Component $LoggingComponent -Path $WorkingDirectory
                    Return
                }

                ############################
                #### $CMAppMetaDataPath ####
                $TestPath = Get-Item $CMAppMetaDataPath -ErrorAction SilentlyContinue
                IF(-not $TestPath.Exists)
                {
                    ## If Value does not resolve to a location fail, and exit
                    New-LogEntry -LogValue "" -Severity 3 -WriteHost $True -Component $LoggingComponent -Path $WorkingDirectory
                    Return
                }
            }
            "CMExportPathParent"
            {
                ##########################
                #### $CMAppParentPath ####
                $TestPath = Get-Item $CMAppParentPath -ErrorAction SilentlyContinue
                IF(-not $TestPath.Exists)
                {
                    ## If Value does not resolve to a location fail, and exit
                    New-LogEntry -LogValue "" -Severity 3 -WriteHost $True -Component $LoggingComponent -Path $WorkingDirectory
                    Return
                }
            }
            "CMServer"
            {
                #################################
                #### PowerShell Architecture ####
                IF("x86" -ne $(Test-PSArchitecture -Architecture "x86"))
                {
                    ## If PowerShell window executing script is not x86 fail and exit.
                    New-LogEntry -LogValue "Executing PowerShell Window is not x86 architecture, please launch Administrative PowerShell (x86) and re-run script." -Severity 3 -WriteHost $true -Component "JobID(-) - Get-CMExportAppData" -Path $WorkingDirectory
                    Return 
                }

                #######################
                #### $CMSiteServer ####
                $ValidationResult = [boolean]$(Test-Connection -ComputerName $CMSiteServer)
                IF(-Not $ValidationResult)
                { 
                    ## If unable to connect to ConfigMgr Site Server fail and exit.
                    New-LogEntry -LogValue "$($Env:ComputerName) was unable to contact ConfigMgr Server $CMSiteServer. Please verify the name of the server and try again." -Severity 3 -WriteHost $True -Component $LoggingComponent -Path $WorkingDirectory
                    Return
                }
                
                #####################
                #### $CMSiteCode ####
                IF($($CMSiteCode.Length) -ne 3)
                {
                    ## If missing or incorrectly entered Site Code, fail and exit.
                    New-LogEntry -LogValue "Invalid Site Code: $CMSiteCode. Please update the site code and re-run script." -Severity 3 -WriteHost $True -Component $LoggingComponent -Path $WorkingDirectory
                    Return
                }
            }
        }
        
        #################################
        ## Set Initial Variable Values ##
        #################################
        [ConversionParam[]]$AppDetails = @()
        $CMApplication                 = @()
    }

    ## Retrieves the application installation information, formatting into a single object for conversion.
    Process{
        Switch ($PSCmdlet.ParameterSetName)
        {
            "CMExportPathTarget" 
            {
                ## If querying a single exported source.
                New-LogEntry -LogValue "Identified source is targetting a single export directory" -Severity 1 -Component "Get-CMExportAppData" -Path $WorkingDirectory

                $CMAppMetaData = Get-ChildItem -Recurse -Path $CMAppMetaDataPath
                $CMAppContent  = Get-ChildItem -Recurse -Path $CMAppContentPath
                $CMApplication = $($CMAppMetaData.Where({$_.FullName -like "*SMS_Application*object.xml"}))
            }
            "CMExportPathParent"
            {
                ## If querying multiple exported sources all at once
                New-LogEntry -LogValue "Identied source is targetting parent directory" -Severity 1 -Component "Get-CMExportAppData" -Path $WorkingDirectory

                $CMAppMetaData = Get-ChildItem -Recurse -Path $CMAppParentPath
                $CMAppContent  = Get-ChildItem -Recurse -Path $CMAppParentPath
                $CMApplication = $($CMAppMetaData.Where({$_.FullName -like "*SMS_Application*object.xml"}))
            }
            "CMServer"
            {
                ## If the PowerShell script is run with the wrong architecture, alert the executing user and exit.
                New-LogEntry -LogValue "Collecting information from ConfigMgr for application: $AppName" -Component "Get-CMAppMetaData" -Path $WorkingDirectory

                ## Attempts to connect to ConfigMgr environment, if fails, returns zero conversion results.
                IF(!$(Connect-CMEnvironment $CMSiteCode $CMSiteServer -WorkingDirectory $WorkingDirectory)) 
                    {Return}

                $CMApplication = Get-CMApplication -Name $AppName
                Write-Host $($CMApplication.LocalizedDisplayName) -ForegroundColor Yellow

                Disconnect-CMEnvironment -WorkingDirectory $WorkingDirectory
            }
        }

        ## Collects app Details
        foreach($CMApp in $CMApplication)
        {
            IF($PSCmdlet.ParameterSetName -like "CMExportPath*")
            {
                $CMAppPath = $CMApp
                $CMApp     = [xml](Get-Content -Path $($CMApp.FullName))
                $XMLAppName   = $($Application.Instance.Property.Where({$_.Name -eq "LocalizedDisplayName"}).Value)

                IF($XMLAppName -like $AppName)
                {
                    ## App Content was exported.
                    $CMAppDeploymentType = [xml]($CMApp.Instance.Property.Where({$_.Name -eq "SDMPackageXML"}).Value.'#cdata-section')
                    $AppDetails += Format-MSIXAppExportDetails -Application $CMApp -ApplicationDeploymentType $CMAppDeploymentType -CMExportAppPath $CMAppContent -CMAppPath $CMAppPath -SigningCertificate $SigningCertificate -WorkingDirectory $WorkingDirectory
                }
            }
            ELSEIF($PSCmdlet.ParameterSetName -eq "CMServer")
            {
                ## App Content was sourced from ConfigMgr Server.
                $CMAppDeploymentType = [xml]($CMApp.SDMPackageXML)
                $AppDetails += Format-MSIXAppExportDetails -Application $CMApp -ApplicationDeploymentType $CMAppDeploymentType -SigningCertificate $SigningCertificate -CMServer -WorkingDirectory $WorkingDirectory
            }
        }
    }

    ## Returns the application installation information as a ConversionParamter object.
    End{
        Return $AppDetails
    }
}
