############################
##  Variable Declaration  ##
############################

#Script Libraries required to run this script.
. $PSScriptRoot\..\BulkConversion\bulk_convert.ps1
. $PSScriptRoot\..\BulkConversion\sign_deploy_run.ps1
. $PSScriptRoot\..\BulkConversion\SharedScriptLib.ps1

$SupportedInstallerType = @("MSI","Script")
$SupportedConfigMgrVersion = ""
$InitialLocation = Get-Location
$VerboseLogging = $true


##################################################################################
## Function: LogEntry
##
## Description:
##    Processes the information that it receives and translates it into a Trace32
##    style log file configured with the appropriate values
##################################################################################
# Function New-LogEntry
# {
# Param(
#     [Parameter(Position=0)] [string]$LogValue,
#     [Parameter(Position=1)] [string]$Component = "",
#     [Parameter(Position=2)] [int]$Severity = 1,
#     [Parameter(Position=3)] [boolean]$WriteHost = $true,
#     [string]$Path = $InitialLocation
# )
#     #Records previously existing execution location to return back afterwards.
#     #$PreviousLocation = Get-Location
#
#     #Sets the execution location to the FileSystem to allow for log entries to be made
#     $PreviousLocation = Disconnect-CMEnvironment -ReturnPreviousLocation $true
#    
#     #Formats the values required to enter for Trace32 Format
#     $TimeZoneBias = Get-WmiObject -Query "Select Bias from Win32_TimeZone"
#     [string]$Time = Get-Date -Format "HH:mm:ss.ffff"
#     [string]$Date = Get-Date -Format "MM-dd-yyyy"
#
#     #Appends the newest log entry to the end of the log file in a Trace32 Formatting
#     $('<![LOG['+$LogValue+']LOG]!><time="'+$Time+'" date="'+$Date+'" component="'+$component+'" context="Empty" type="'+$severity+'" thread="Empty" file="'+"Empty"+'">') | out-file -FilePath $($Path+"\MSIXConnect.log") -Append -NoClobber -encoding default
#
#     IF($WriteHost)
#     {
#         Write-Host $LogValue -ForegroundColor $(switch ($Severity) {3 {"Red"} 2 {"Yellow"} 1 {"White"}})
#     }
#
#     #Returns to the original execution location
#     Set-Location $PreviousLocation
# }

Function Test-PSArchitecture
{
    If([intPtr]::size -eq 4) { New-LogEntry "PowerShell Architecture matches." -Component Test-PSArchitecture }
    ELSE { Throw "Incorrect PowerShell Architecture, please review ReadMe for requirements." }
}

function Connect-CMEnvironment ([Parameter(Mandatory=$True,HelpMessage="Please Enter CM SiteCode.",ParameterSetName=$('Execution'),Position=0)] [String]$CMSiteCode)
{
    Import-Module $ENV:SMS_ADMIN_UI_PATH.replace("bin\i386","bin\ConfigurationManager.psd1")
    New-LogEntry -LogValue "Connecting to the $($CMSiteCode) ConfigMgr PowerShell Environment..." -Component "Connect-CMEnvironment"

    $SiteLocation = Get-PSDrive -PSProvider CMSITE | Where-Object {$_.Name -eq $CMSiteCode}
    IF($SiteLocation)
    {
        Set-Location "$($SiteLocation):"
        IF($(Get-Location) -like "$($SiteLocation.Name)*") 
        {
            New-LogEntry -LogValue "Connected Successfully to $($CMSiteCode) ConfigMgr PowerShell Environment..." -Component "Connect-CMEnvironment"
            Return $True
        }
        else 
        {
            New-LogEntry -LogValue "Connection Failed..." -Component "Connect-CMEnvironment" -Severity 2
            Return $False
        }
    } 
    ELSE 
    { 
        New-LogEntry -LogValue "Could not identify ConfigMgr Site using ""$CMSiteCode"" Site Code." -Component "Connect-CMEnvironment" -Severity 2
        Return $False
    }
}

function Disconnect-CMEnvironment ([boolean]$ReturnPreviousLocation=$false)
{
    $PreviousLocation = Get-Location
    Set-Location $InitialLocation

    IF($ReturnPreviousLocation){Return $PreviousLocation}
}

Function Get-CMAppMetaData ([Parameter(Mandatory=$True, HelpMessage="Please provide the Name of the CM Application.", ParameterSetName=$('Execution'), Position=0)] [string]$AppName)
{
    New-LogEntry -LogValue "Collecting information from ConfigMgr for application: $AppName" -Component "Get-CMAppMetaData"
    $CMApplication = Get-CMApplication -Name $AppName
    $CMApplicationDeploymentTypes = Get-CMDeploymentType -InputObject $CMApplication
    $AppDetails = @()

    $AppDetails = Format-MSIXAppDetails -Application $CMApplication -ApplicationDeploymentType $CMApplicationDeploymentTypes
    
    Return $AppDetails
}

<#
Requirements
    - Name must be 3 Characters long
    - No Special Charachters
#>

function Format-MSIXAppExportDetails ($Application, $ApplicationDeploymentType, $CMExportAppPath="") 
{
    $AppDetails = @()
    $AppName = $($Application.Instance.Property.Where({$_.Name -eq "LocalizedDisplayName"}).Value)

    IF($($ApplicationDeploymentType.count -le 1))
         { $XML = [XML]$($ApplicationDeploymentType) }
    Else 
         { $XML = [XML]$($ApplicationDeploymentType[0].SDMPackageXML) }

    ## Needs to be tested. Could improve the usage of this script by allowing it to work with ConfigMgr Live, and Exported app information.
    $CmdP1 = '$Application.Instance.Property.Where({$_.Name -eq "'
    $CmdP2 = '"}).Value)'
    
    Foreach($Deployment IN $($XML.AppMgmtDigest.DeploymentType))
    {
        New-LogEntry -LogValue "Parsing through the Deployment Types of $AppName application." -Component "Format-MSIXAppDetails" -WriteHost $VerboseLogging

        $XML                = [XML]$($DeploymentType.SDMPackageXML)  ## Not sure if this should be here or not.. needs to be tested with it removed.
        $MSIXAppDetails     = New-Object PSObject
        # $AppTypes           = @( ".exe", ".msi" )
        $InstallerArgument  = ""

        $objInstallerAction      = Get-MSIXConnectInstallInfo -DeploymentAction $($Deployment.Installer.InstallAction) -InstallerTechnology $($Deployment.Installer.Technology)
        $objUninstallerAction    = Get-MSIXConnectInstallInfo -DeploymentAction $($Deployment.Installer.UninstallAction) -InstallerTechnology $($Deployment.Installer.Technology)
        $objInstallerFileName    = $objInstallerAction.Filename
        $objInstallerArgument    = $objInstallerAction.Argument
        $objUninstallerFileName  = $objUninstallerAction.Filename
        $objUninstallerArgument  = $objUninstallerAction.Argument

        Write-Host "Fulled from the horses mouth: $($objUninstallerAction.Filename)"
        Write-Host "Fulled from the horses mouth: $($objUninstallerAction.Argument)"

        $InstallerFileName = $objInstallerFileName
        $InstallerArgument = $objInstallerArgument

         ## Will want to change this out with Parameter Set Name, will need to set Parameter Set Names for this Function.
        $objContentPath = ""

        IF($CMExport -eq "")
            { $objContentPath = (Get-Item -Path $($Deployment.Installer.Contents.Content.Location)).FullName }
        else 
            { $objContentPath = (Get-Item -Path "$CMExportAppPath\$($Deployment.Installer.Contents.Content.ContentID)\").FullName }

        $objTempInstallerFileName = $( Get-Item -Path $("$objContentPath\$InstallerFileName")).FullName
        $objTempUninstallerFileName = $( Get-Item -Path $("$objContentPath\$objUninstallerFileName")).FullName

        Write-Host "  Installer Filename:   |$InstallerFileName| |$InstallerArgument|" -ForegroundColor Yellow
        
        $msixAppContentID   = $($Deployment.Installer.Contents.Content.ContentID)
        $msixAppPackageName = $($(Format-MSIXPackagingName -AppName "$($Application.Instance.Property.Where({$_.Name -eq "LocalizedDisplayName" }).Value)-$($msixAppContentID.Substring($msixAppContentID.Length-6, 6))" ))
        
        ## Needs to be tested. Could improve the usage of this script by allowing it to work with ConfigMgr Live, and Exported app information.
        Invoke-Expression $('$MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PackageDisplayName"   -Value $(' + $CmdP1 + "LocalizedDisplayName"   + $CmdP2)
        Invoke-Expression $('$MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PublisherDisplayName" -Value $(' + $CmdP1 + "Manufacturer"           + $CmdP2)
#        Invoke-Expression $('$MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PackageVersion"       -Value $(' + $CmdP1 + "SoftwareVersion"        + $CmdP2)
        Invoke-Expression $('$MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppDescription"       -Value $(' + $CmdP1 + "LocalizedDescription"   + $CmdP2)
        Invoke-Expression $('$MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "CMAppPackageID"       -Value $(' + $CmdP1 + "PackageID"              + $CmdP2)
#        Invoke-Expression $('$MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PublisherName"        -Value $("CN=" + ' + $CmdP1 + "Manufacturer"   + $CmdP2)
        #Invoke-Expression $('$MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PackageName"          -Value $($(Format-MSIXPackagingName -AppName $(' + $CmdP1 + "LocalizedDisplayName" + $CmdP2 + ')')

        #$MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PackageDisplayName"      -Value $($Application.Instance.Property.Where({$_.Name -eq "LocalizedDisplayName"}).Value)
        #$MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PackageName"             -Value $(Format-MSIXPackagingName -AppName $($Application.Instance.Property.Where({$_.Name -eq "LocalizedDisplayName"}).Value))
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PackageName"             -Value $($msixAppPackageName)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PublisherName"           -Value $("CN=Contoso Software (FOR LAB USE ONLY), O=Contoso Corporation, C=US")
        #$MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PublisherDisplayName"    -Value $($Application.Instance.Property.Where({$_.Name -eq "Manufacturer"}).Value)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PackageVersion"          -Value $(Format-MSIXPackagingVersion $($Application.Instance.Property.Where({$_.Name -eq "SoftwareVersion"}).Value))
        #$MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppDescription"          -Value $($Application.Instance.Property.Where({$_.Name -eq "LocalizedDescription"}).Value)
        #$MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "CMAppPackageID"          -Value $($Application.Instance.Property.Where({$_.Name -eq "PackageID"}).Value)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "RequiresUserInteraction" -Value $($XML.AppMgmtDigest.DeploymentType.Installer.CustomData.RequiresUserInteraction)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppFolderPath"           -Value $($Deployment.Installer.Contents.Content.Location)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppFileName"             -Value $($InstallerFileName)
        #$MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppFileName"             -Value $($Deployment.Installer.Contents.Content.File.Name)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppIntallerType"         -Value $($Deployment.Installer.Technology)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "ContentID"               -Value $($msixAppContentID)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "InstallerArguments"      -Value $("$InstallerArgument")
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "ExecutionContext"        -Value $($Arg.'#text')
        
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "InstallerPath"           -Value $($objTempInstallerFileName)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "UninstallerPath"         -Value $($objTempUninstallerFileName)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "UninstallerArgument"     -Value $($objUninstallerArgument)
        
        New-LogEntry -LogValue "Parsing Application: ""$($Application.Instance.Property.Where({$_.Name -eq "LocalizedDisplayName"}).Value)"", currently recording information from ""$($Deployment.Title.'#text')"" Deployment Type." -Component "Format-MSIXAppDetails" -WriteHost $VerboseLogging
     
        # SupportedInstallerType is at the top of this file. More file types will need to be included.
        IF ($SupportedInstallerType.Contains($($Deployment.Installer.Technology)))
            { $AppDetails += $MSIXAppDetails }
        ELSE
            { New-LogEntry -LogValue "The ""$($Application.LocalizedDisplayName)"" application type is currently unsupported." -Component "Format-MSIXAppDetails" -Severity 3 }
    }
    
    Return $AppDetails
}

Function Get-MSIXConnectInstallInfo ($DeploymentAction, $InstallerTechnology)
{
    $objInstallerAction   = $DeploymentAction.Args.Arg.Where({$_.Name -eq "InstallCommandLine"}).'#text'
    $objInstallerFileName = $objInstallerAction
    $objInstallerArgument = ""
    $objTempInstallerArgument = $objInstallerAction
    $AppTypes             = @( ".exe", ".msi" )
    $objInstallerActions  = New-Object PSObject

    IF($null -eq $objInstallerAction)
        { Return }

    Write-Host "Start" -ForegroundColor Yellow -BackgroundColor Black
    Write-Host "InstallerAction $objInstallerAction" -ForegroundColor Green -BackgroundColor Black
    Write-Host "InstallerFileName $objInstallerAction" -ForegroundColor Green -BackgroundColor Black

    ## Installer FileName
    IF($objInstallerFileName.EndsWith(" "))
        { $objInstallerFileName = $objInstallerFileName.Substring(0, $($objInstallerFileName.Length - 1)) }

    foreach($Extension in $AppTypes)
    {
        IF( $($objInstallerFileName.IndexOf($Extension)) -gt 0 )
        { 
            IF($($objInstallerFileName.Length) -gt $($objInstallerFileName.IndexOf($Extension) + 5))
                { $objInstallerFileName = $objInstallerFileName.Substring(0, $($objInstallerFileName.IndexOf($Extension) + 5)) }
        }
    }

    ## Installer Arguments
    IF($InstallerTechnology -eq "Script")
    {
        IF($($objTempInstallerArgument.Length) -gt $($objInstallerFileName.Length))
            { $objInstallerArgument = $objTempInstallerArgument.Substring($($objInstallerFileName.Length)+1, $($objTempInstallerArgument.Length)-$($objInstallerFileName.Length)-1) }
#        $objInstallerArgument = $objInstallerArgument.Substring($($objInstallerFileName.Length)+1, $($objInstallerArgument.Length)-$($objInstallerFileName.Length)-1)
    }

    ## Removes the double quotes from the string
    $objInstallerFileName = $objInstallerFileName -replace '"', ''
    $objInstallerFileName = $objInstallerFileName -replace ' ', ''
    $objInstallerArgument = $objInstallerArgument -replace '"', ''''

    $objInstallerActions | Add-Member -MemberType NoteProperty -Name "FileName" -Value $($objInstallerFileName)
    $objInstallerActions | Add-Member -MemberType NoteProperty -Name "Argument" -Value $($objInstallerArgument)

    Return $objInstallerActions
}

function Format-MSIXAppDetails ($Application, $ApplicationDeploymentType, $CMExportAppPath="") 
{
    $AppDetails = @()

     IF($($ApplicationDeploymentType.count -le 1))
         { $XML = [XML]$($ApplicationDeploymentType) }
     else 
         { $XML = [XML]$($ApplicationDeploymentType[0].SDMPackageXML) }
    
    Foreach($Deployment IN $($XML.AppMgmtDigest.DeploymentType))
    {
        New-LogEntry -LogValue "Parsing through the Deployment Types of $AppName application." -Component "Format-MSIXAppDetails" -WriteHost $VerboseLogging

        $MSIXAppDetails = New-Object PSObject
        $XML = [XML]$($DeploymentType.SDMPackageXML)

        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PackageDisplayName" -Value $($Application.LocalizedDisplayName)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PackageName" -Value $(Format-MSIXPackagingName -AppName $($Application.LocalizedDisplayName))
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PublisherName" -Value $("CN=" + $Application.Manufacturer)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PublisherDisplayName" -Value $($Application.Manufacturer)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PackageVersion" -Value $($Application.SoftwareVersion)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppDescription" -Value $($Application.LocalizedDescription)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "CMAppPackageID" -Value $($Application.PackageID)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "RequiresUserInteraction" -Value $($XML.AppMgmtDigest.DeploymentType.Installer.CustomData.RequiresUserInteraction)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppFolderPath" -Value $($Deployment.Installer.Contents.Content.Location)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppFileName" -Value $($Deployment.Installer.Contents.Content.File.Name)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppIntallerType" -Value $($Deployment.Installer.Technology)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "ContentID" -Value $($Deployment.Installer.Contents.Content.ContentID)

        IF($CMExport -eq "")
            { $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "InstallerPath" -Value $("$($Deployment.Installer.Contents.Content.Location)" + "$($Deployment.Installer.Contents.Content.File.Name)") }
        else 
            { $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "InstallerPath" -Value $("$CMExportAppPath\" + "$($Deployment.Installer.Contents.Content.File.Name)") }
        
        New-LogEntry -LogValue "Parsing Application: ""$($Application.LocalizedDisplayName)"", currently recording information from ""$($DeploymentType.LocalizedDisplayName)"" Deployment Type." -Component "Format-MSIXAppDetails" -WriteHost $VerboseLogging
     
        Foreach($Arg IN $($DeploymentInstaller.InstallAction.Args.Arg))
        {
            IF($Arg.Name -eq "InstallCommandLine") { $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppInstallString" -Value $($Arg.'#text') }
            IF($Arg.Name -eq "ExecutionContext")   { $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "ExecutionContext" -Value $($Arg.'#text') }
        }

        New-LogEntry -LogValue "Adding the following information to the App XML:`n`n$MSIXAppDetails" -Component "Format-MSIXAppDetails" -WriteHost $VerboseLogging
        
        IF ($SupportedInstallerType.Contains($($Deployment.Installer.Technology)))
        {
            $AppDetails += $MSIXAppDetails
        }
        ELSE
        {
            New-LogEntry -LogValue "The ""$($Application.LocalizedDisplayName)"" application type is currently unsupported." -Component "Format-MSIXAppDetails" -Severity 3
        }
    }
    
    Return $AppDetails
}

Function Format-MSIXPackagingName ([Parameter(Mandatory=$True,Position=0)] [string]$AppName)
{
    New-LogEntry -LogValue "Removing Special Characters from the Application Package Name.
    " -Component "Format-MSIXPackagingName" -Severity 1 -WriteHost $VerboseLogging
    $MSIXPackageName = $AppName -replace '[!,@,#,$,%,^,&,*,(,),+,=,~,`]',''
    $MSIXPackageName = $MSIXPackageName -replace '_','-'
    $MSIXPackageName = $MSIXPackageName -replace ' ','-'

    Return $MSIXPackageName
}

Function Format-MSIXPackagingArgument ([Parameter(Mandatory=$True,Position=0)] [string]$AppArgument)
{
#    New-LogEntry -LogValue "Removing Special Characters from the Application Package Name.
#    " -Component "Format-MSIXPackagingName" -Severity 1 -WriteHost $VerboseLogging
#    $MSIXPackageArguement = $AppArgument -replace '[!,@,#,$,%,^,&,*,(,),+,=,~,`]',''
#    $MSIXPackageArguement = $MSIXPackageArguement -replace '_','-'
#    $MSIXPackageArguement = $MSIXPackageArguement -replace ' ','-'

#    Return $MSIXPackageArguement
}

Function Format-MSIXPackagingVersion ([Parameter(Mandatory=$True,Position=0)] [string]$AppVer)
{
    ## Removes the less-desirable characters.
    $MSIXPackageVersion = $AppVer -replace '[!,@,#,$,%,^,&,*,),+,=,~,`]',''
    $MSIXPackageVersion = $MSIXPackageVersion -replace '[_,(]','.'
    $MSIXPackageVersion = $MSIXPackageVersion -replace ' ',''
    $MSIXPackageVersion = $MSIXPackageVersion -replace '[a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z]',''

    $Index = 0
    $NewPackageVersion = ""
    
    ## Ensures the version is 4 octets.
    Foreach ($VerIndex in $($MSIXPackageVersion.Split('.')))
    {
        ## Adds the values for each octet into its octet.
        If($Index -le 2)
            { $NewPackageVersion += $($VerIndex + ".") }
        If($Index -eq 3)
            { $NewPackageVersion += $($VerIndex) }

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
    Return $NewPackageVersion
}

Function Validate-MSIXPackagingName ([Parameter(Mandatory=$True,Position=0)] [string]$AppName)
{
    New-LogEntry -LogValue "Validating that the name of the application does not contain any special characters. Special Characters include:`n`t!,@,#,$,%,^,&,*,(,),+,=,~,`, ,_" -Component "Validate-MSIXPackaingName" -WriteHost $VerboseLogging
    $SpecialCharacters = $($MSIXPackageName = $AppName -match '[!,@,#,$,%,^,&,*,(,),+,=,~,`, ,_]')

    IF($SpecialCharacters)
    {
        New-LogEntry -LogValue "The name does not contain any special characters." -Component "Validate-MSIXPackagingName" -WriteHost $VerboseLogging
        Return $SpecialCharacters
    }
    else
    {
        New-LogEntry -LogValue "Error: Name contains special characters - MSIX App Name does not support the use of special characters." -Component "Validate-MSIXPackagingName" -Severity 3
        Return $SpecialCharacters
    }

    Return $($MSIXPackageName = $AppName -match '[!,@,#,$,%,^,&,*,(,),+,=,~,`, ,_]')
}

Function New-MSIXConnectMakeApp ([Parameter(Mandatory=$True)] $SiteCode = "CM1", 
                                 [Parameter(Mandatory=$True)] $SiteServerServerName = "CL-CM01",
                                 [Parameter(Mandatory=$True)] $ApplicationName = "Notepad++")
{
    $VMcredential = Get-Credential
    IF(!$VMcredential)
    {
        New-LogEntry -LogValue "Failed to retrieve Credentials, exiting script..." -Component "New-MSIXConnectMakeApp" -Severity 3
        Return
    }

#    $virtualMachines = @( @{ Name = "MSIX Packaging Tool Environment1"; credential = $VMcredential } )
#    $remoteMachines =  @( @{ ComputerName = "YourVMNameHere.westus.cloudapp.azure.com"; Credential = $VMcredential } )

    Test-PSArchitecture
    IF(!$(Connect-CMEnvironment $SiteCode)) {Return}
    $MSIXAppMetaData = Get-CMAppMetaData $ApplicationName
    Disconnect-CMEnvironment

    $workingDirectory = [System.IO.Path]::Combine($PSScriptRoot, "out")

    RunConversionJobs -conversionsParameters $MSIXAppMetaData -virtualMachines $virtualMachines -remoteMachines $remoteMachines $workingDirectory

    SignAndDeploy "$workingDirectory\MSIX"

}

Function Get-CMExportAppData ($CMAppContentPath="C:\Temp\ConfigMgrOutput_files", $CMAppMetaDataPath="C:\Temp\ConfigMgrOutput")
{
    # Identify the files exported from ConfigMgr
    $CMAppMetaData = Get-Item -Path "$CMAppMetaDataPath\SMS_Application\*"
    
    $AppDetails = @()

    Foreach($CMAppPath in $CMAppMetaData)
    {
        $CMApp = [xml](Get-Content -Path "$($CMAppPath.FullName)\object.xml")
        $CMAppDeploymentType = [xml]($CMApp.Instance.Property.Where({$_.Name -eq "SDMPackageXML"}).Value.'#cdata-section')

        $AppDetails += Format-MSIXAppExportDetails -Application $CMApp -ApplicationDeploymentType $CMAppDeploymentType -CMExportAppPath $CMAppContentPath
    }

    Return $AppDetails
}

# Function Compress-MSIXAppInstaller ($Path, $InstallerPath, $InstallerArgument)
# {
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
# #    Set-Content -Value "PowerShell.exe $("$ExportPath\$($ScriptFilePath.Replace($("$ContainerPath\"), ''))")" -Path $($CMDScriptFilePath) -Force
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
#             { 
#                 $XMLFiles += "`n`t`t<File Name=""$($Item.Name)"" ParentPath=""$($Item.FullName.Replace($($Item.Name), ''))"" RelativePath=""$($Item.FullName.Replace($Path, ''))"" Extension=""$($Item.Extension)"" SEDFile=""FILE$($iFiles)"" />" 
#                 $iFiles++
#             }
#         Else 
#             { 
#                 $XMLDirectories += "`n`t`t<Directory Name=""$($Item.Name)"" FullPath=""$($Item.FullName)"" RelativePath=""$($Item.FullName.Replace($Path, ''))"" SEDFolder=""SourceFiles$($iDirs)"" />" 
#                 $iDirs++
#             }
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
#     #Invoke-Expression "iexpress.exe /N $SEDOutPath"
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
