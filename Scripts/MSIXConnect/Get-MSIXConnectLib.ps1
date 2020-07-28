############################
##  Variable Declaration  ##
############################

## Work on AppV
## Selective App conversions
##   - List of Folder
##   - individual, or selective apps


#Script Libraries required to run this script.
. $PSScriptRoot\..\BulkConversion\bulk_convert.ps1
. $PSScriptRoot\..\BulkConversion\sign_deploy_run.ps1
. $PSScriptRoot\..\BulkConversion\SharedScriptLib.ps1

$SupportedInstallerType = @("MSI","Script")
$SupportedConfigMgrVersion = ""
$InitialLocation = Get-Location
$VerboseLogging = $true



#Function Get-CMAppConversionData ([Parameter(Mandatory=$True,HelpMessage="Please Enter CM SiteCode.",ParameterSetName=$('CMServer'),Position=0)] [String]$CMSiteCode,
#                                  [Parameter(Mandatory=$True,HelpMessage="Please Enter CM SiteCode.",ParameterSetName=$('Execution'),Position=0)] [String]$CMSiteCode)
#{
#
#}

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

function Format-MSIXAppExportDetails ($Application, $ApplicationDeploymentType, $CMExportAppPath="", $CMAppPath="", $SigningCertificatePublisher) 
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

    New-LogEntry -LogValue "Parsing through the Deployment Types of $AppName application." -Component "Format-MSIXAppDetails" -WriteHost $true

    Foreach($Deployment IN $($XML.AppMgmtDigest.DeploymentType))
    {
        New-LogEntry -LogValue "  Parsing the Application (""$AppName""), currently recording information from Deployment Type:  ""$($Deployment.Title.'#text')""" -Component "Format-MSIXAppDetails" -WriteHost $true -textcolor "Cyan"

        $XML                = [XML]$($DeploymentType.SDMPackageXML)  ## Not sure if this should be here or not.. needs to be tested with it removed.
        $MSIXAppDetails     = New-Object PSObject
        $InstallerArgument  = ""

        New-LogEntry -LogValue "    $($("Install String:").PadRight(22))  $($Deployment.Installer.InstallAction.Args.Arg.Where({$_.Name -eq "InstallCommandLine"}).'#text')" -Severity 1 -Component "Format-MSIXAppDetails"

        $objInstallerAction      = Get-MSIXConnectInstallInfo -DeploymentAction $($Deployment.Installer.InstallAction) -InstallerTechnology $($Deployment.Installer.Technology)
        $objUninstallerAction    = Get-MSIXConnectInstallInfo -DeploymentAction $($Deployment.Installer.UninstallAction) -InstallerTechnology $($Deployment.Installer.Technology)
        $objInstallerFileName    = $objInstallerAction.Filename
        $objInstallerArgument    = $objInstallerAction.Argument
        $objUninstallerFileName  = $objUninstallerAction.Filename
        $objUninstallerArgument  = $objUninstallerAction.Argument

        $InstallerFileName = $objInstallerFileName
        $InstallerArgument = $objInstallerArgument

        ## Will want to change this out with Parameter Set Name, will need to set Parameter Set Names for this Function.
        $objContentPath = ""

        IF($CMExport -eq "")
            { $objContentPath = (Get-Item -Path $($Deployment.Installer.Contents.Content.Location)).FullName }
        else 
            { $objContentPath = (Get-Item -Path $($CMExportAppPath.Where({$_.FullName -like "*$($CMAppPath.Directory.Parent.Parent.Name)*$($Deployment.Installer.Contents.Content.ContentID)"})).FullName) }

        $objTempInstallerFileName = $( Get-Item -Path $("$objContentPath\$InstallerFileName")).FullName
        $objTempUninstallerFileName = $( Get-Item -Path $("$objContentPath\$objUninstallerFileName") -ErrorAction SilentlyContinue).FullName

        New-LogEntry -LogValue "    $($("Installer Filename:").PadRight(22))  |$InstallerFileName| |$InstallerArgument|" -Severity 1 -Component "Format-MSIXAppExportDetails"
        
        $msixAppContentID   = $($Deployment.Installer.Contents.Content.ContentID)
        $msixAppPackageName = $($(Format-MSIXPackagingName -AppName "$($Application.Instance.Property.Where({$_.Name -eq "LocalizedDisplayName" }).Value)-$($msixAppContentID.Substring($msixAppContentID.Length-6, 6))" ))
        
        ## Needs to be tested. Could improve the usage of this script by allowing it to work with ConfigMgr Live, and Exported app information.
        Invoke-Expression $('$MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PackageDisplayName"   -Value $(' + $CmdP1 + "LocalizedDisplayName"   + $CmdP2)
        Invoke-Expression $('$MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PublisherDisplayName" -Value $(' + $CmdP1 + "Manufacturer"           + $CmdP2)
        Invoke-Expression $('$MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppDescription"       -Value $(' + $CmdP1 + "LocalizedDescription"   + $CmdP2)
        Invoke-Expression $('$MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "CMAppPackageID"       -Value $(' + $CmdP1 + "PackageID"              + $CmdP2)

        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PackageName"             -Value $($msixAppPackageName)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PublisherName"           -Value $($SigningCertificatePublisher)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PackageVersion"          -Value $(Format-MSIXPackagingVersion $($Application.Instance.Property.Where({$_.Name -eq "SoftwareVersion"}).Value))
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "RequiresUserInteraction" -Value $($XML.AppMgmtDigest.DeploymentType.Installer.CustomData.RequiresUserInteraction)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppFolderPath"           -Value $($Deployment.Installer.Contents.Content.Location)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppInstallerFolderPath"  -Value $("$objContentPath\")
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppFileName"             -Value $($InstallerFileName)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppIntallerType"         -Value $($Deployment.Installer.Technology)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "ContentID"               -Value $($msixAppContentID)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "InstallerArguments"      -Value $("$InstallerArgument")
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "ExecutionContext"        -Value $($Arg.'#text')
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "ContentParentRoot"       -Value $($CMAppPath.Directory.Parent.Parent.Name)

        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "InstallerPath"           -Value $($objTempInstallerFileName)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "UninstallerPath"         -Value $($objTempUninstallerFileName)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "UninstallerArgument"     -Value $($objUninstallerArgument)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "DeploymentType"          -Value $($Deployment.Title.'#text')
     
        # SupportedInstallerType is at the top of this file. More file types will need to be included.
        IF ($SupportedInstallerType.Contains($($Deployment.Installer.Technology)))
            { $AppDetails += $MSIXAppDetails }
        ELSE
            { New-LogEntry -LogValue "The ""$($Application.LocalizedDisplayName)"" application type is currently unsupported." -Component "Format-MSIXAppDetails" -Severity 3 }

        Write-Host ""
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
            { $objInstallerArgument = $objTempInstallerArgument.Substring($($objInstallerFileName.Length), $($objTempInstallerArgument.Length)-$($objInstallerFileName.Length)) }
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
    New-LogEntry -LogValue "    Removing Special Characters from the Application Package Name." -Component "Format-MSIXPackagingName" -Severity 1 -WriteHost $VerboseLogging
    $MSIXPackageName = $AppName -replace '[!,@,#,$,%,^,&,*,(,),+,=,~,`]',''
    $MSIXPackageName = $MSIXPackageName -replace '_','-'
    $MSIXPackageName = $MSIXPackageName -replace ' ','-'

    IF($MSIXPackageName.Length -gt 43)
    {
        $MSIXPackageName = $MSIXPackageName.Substring(0,43)
    }

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

    Test-PSArchitecture
    IF(!$(Connect-CMEnvironment $SiteCode)) {Return}
    $MSIXAppMetaData = Get-CMAppMetaData $ApplicationName
    Disconnect-CMEnvironment

    $workingDirectory = [System.IO.Path]::Combine($PSScriptRoot, "out")

    RunConversionJobs -conversionsParameters $MSIXAppMetaData -virtualMachines $virtualMachines -remoteMachines $remoteMachines $workingDirectory

    SignAndDeploy "$workingDirectory\MSIX"

}

Function Get-CMExportAppData ($CMAppContentPath="C:\Temp\ConfigMgrOutput_files", $CMAppMetaDataPath="C:\Temp\ConfigMgrOutput", $CMAppParentPath="", $SigningCertificatePublisher)
{
    
    #Sets Variables based on provided details
    IF($CMAppParentPath -ne "")
    { 
        ## If querying multiple exported sources all at once
        New-LogEntry -LogValue "Identied source is targetting parent directory" -Severity 1 -Component "Get-CMExportAppData"

        $CMAppMetaData = Get-ChildItem -Recurse -Path $CMAppParentPath
        $CMAppContent  = Get-ChildItem -Recurse -Path $CMAppParentPath
    }
    else 
    { 
        ## If querying a single exported source.
        New-LogEntry -LogValue "Identified source is targetting a single export directory" -Severity 1 -Component "Get-CMExportAppData"

        $CMAppMetaData = Get-ChildItem -Recurse -Path $CMAppMetaDataPath
        $CMAppContent  = Get-ChildItem -Recurse -Path $CMAppContentPath
    }

    ## Collects app Details
    foreach($CMAppPath in $($CMAppMetaData.Where({$_.FullName -like "*SMS_Application*object.xml"})))
    {
        $CMApp = [xml](Get-Content -Path $($CMAppPath.FullName))
        $CMAppDeploymentType = [xml]($CMApp.Instance.Property.Where({$_.Name -eq "SDMPackageXML"}).Value.'#cdata-section')

        $AppDetails += Format-MSIXAppExportDetails -Application $CMApp -ApplicationDeploymentType $CMAppDeploymentType -CMExportAppPath $CMAppContent -CMAppPath $CMAppPath -SigningCertificatePublisher $SigningCertificatePublisher
    }

    Return $AppDetails
}
