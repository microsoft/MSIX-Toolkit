############################
##  Variable Declaration  ##
############################

## Work on AppV
## Selective App conversions
##   - List of Folder
##   - individual, or selective apps


#Script Libraries required to run this script.
#. $PSScriptRoot\..\BulkConversion\bulk_convert.ps1
#. $PSScriptRoot\..\BulkConversion\sign_deploy_run.ps1
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

function Connect-CMEnvironment ([Parameter(Mandatory=$True,Position=0)] [String]$CMSiteCode,
                                [Parameter(Mandatory=$False,Position=1)] [String]$CMSiteServer)
{
    Import-Module $ENV:SMS_ADMIN_UI_PATH.replace("bin\i386","bin\ConfigurationManager.psd1")
    New-LogEntry -LogValue "Connecting to the $($CMSiteCode) ConfigMgr PowerShell Environment..." -Component "Connect-CMEnvironment"

    ## If No Site exists in PS Drive, it will create it.
    if((Get-PSDrive -Name $CMSiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) 
    {
        $initParams = @{}
        New-PSDrive -Name $CMSiteCode -PSProvider CMSite -Root $CMSiteServer @initParams
    }

    ## Checks that the PS Drive Exists, and then attempts to connect
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

function Format-MSIXAppExportDetails ($Application, 
                                      $ApplicationDeploymentType, 
                                      [Parameter(Mandatory=$True,ParameterSetName=$('CMExportedApp'),Position=0)]  $CMExportAppPath,
                                      [Parameter(Mandatory=$True,ParameterSetName=$('CMExportedApp'),Position=1)]  $CMAppPath,
                                      [Parameter(Mandatory=$True,ParameterSetName=$('CMServer'))]  [Switch]$CMServer,
                                      $SigningCertificatePublisher) 
{

    $AppDetails = @()

    Switch ($PSCmdlet.ParameterSetName)
    {
        "CMExportedApp" { $AppName = $($Application.Instance.Property.Where({$_.Name -eq "LocalizedDisplayName"}).Value) }
        "CMServer"      { $AppName = $($Application.LocalizedDisplayName) }
    }


    IF($($ApplicationDeploymentType.count -le 1))
         { $XML = [XML]$($ApplicationDeploymentType) }
    Else 
         { $XML = [XML]$($ApplicationDeploymentType[0].SDMPackageXML) }


    New-LogEntry -LogValue "Parsing through the Deployment Types of $AppName application." -Component "Format-MSIXAppDetails" -WriteHost $true

    Foreach($Deployment IN $($XML.AppMgmtDigest.DeploymentType))
    {
        New-LogEntry -LogValue "  Parsing the Application (""$AppName""), currently recording information from Deployment Type:  ""$($Deployment.Title.'#text')""" -Component "Format-MSIXAppDetails" -WriteHost $true -textcolor "Cyan"
        New-LogEntry -LogValue "    $($("Install String:").PadRight(22))  $($Deployment.Installer.InstallAction.Args.Arg.Where({$_.Name -eq "InstallCommandLine"}).'#text')" -Severity 1 -Component "Format-MSIXAppDetails"

#        $XML                = [XML]$($DeploymentType.SDMPackageXML)  ## Not sure if this should be here or not.. needs to be tested with it removed.
        $MSIXAppDetails     = New-Object PSObject
        $InstallerArgument  = ""
        $objContentPath     = ""

#        $_RequiresUserInteraction = $XML.AppMgmtDigest.DeploymentType.Installer.CustomData.RequiresUserInteraction
        $objInstallerAction       = Get-MSIXConnectInstallInfo -DeploymentAction $($Deployment.Installer.InstallAction) -InstallerTechnology $($Deployment.Installer.Technology)
        $objUninstallerAction     = Get-MSIXConnectInstallInfo -DeploymentAction $($Deployment.Installer.UninstallAction) -InstallerTechnology $($Deployment.Installer.Technology)
        $_AppFileName             = $objInstallerAction.Filename
        $_InstallerArgument       = Format-MSIXPackageInfo -AppArgument "$($objInstallerAction.Argument)"
        $_UninstallerPath         = $objUninstallerAction.Filename
        $_UninstallerArgument     = Format-MSIXPackageInfo -AppArgument "$($objUninstallerAction.Argument)"
        $_AppInstallerType        = $Deployment.Installer.Technology
        $_ExecutionContext        = $Arg.'#text'
        $_AppFolderPath           = $Deployment.Installer.Contents.Content.Location
        $_PublisherName           = $SigningCertificate.Publisher

        New-LogEntry -LogValue "    $($("Installer Filename:").PadRight(22))  |$_AppFileName| |$_InstallerArgument|" -Severity 1 -Component "Format-MSIXAppExportDetails"
        
        $_ContentID      = $($Deployment.Installer.Contents.Content.ContentID)
        $_DeploymentType = $Deployment.Title.'#text'

        Switch($PSCmdlet.ParameterSetName)
        {
            "CMExportedApp"
            {
                $_PackageName            = $($(Format-MSIXPackageInfo -AppName "$($Application.Instance.Property.Where({$_.Name -eq "LocalizedDisplayName" }).Value)-$($_ContentID.Substring($_ContentID.Length-6, 6))" ))
                $_PackageDisplayName     = $Application.Instance.Property.Where({$_.Name -eq "LocalizedDisplayName"}).Value
                $_PublisherDisplayname   = $Application.Instance.Property.Where({$_.Name -eq "Manufacturer"}).Value
                $_ApplicationDescription = $Application.Instance.Property.Where({$_.Name -eq "LocalizedDescription"}).Value
                $_CMAppPackageID         = $Application.Instance.Property.Where({$_.Name -eq "PackageID"}).Value
                $_ContentParentRoot      = $($CMAppPath.Directory.Parent.Parent.Name)
                $_AppInstallerFolderPath = $("$(Get-Item -Path $($CMExportAppPath.Where({$_.FullName -like "*$($_ContentParentRoot)*$($Deployment.Installer.Contents.Content.ContentID)"})).FullName)\")
                $_InstallerPath          = $(Get-Item -Path $("$_AppInstallerFolderPath\$_AppFileName")).FullName
                $_InstallerFolderPath    = $($(Get-Item -Path $("$_AppInstallerFolderPath")).FullName)
                $_UninstallerPath        = $(Get-Item -Path $("$_AppInstallerFolderPath\$_UninstallerPath") -ErrorAction SilentlyContinue).FullName
                $_PackageVersion         = Format-MSIXPackageInfo -AppVersion $($Application.Instance.Property.Where({$_.Name -eq "SoftwareVersion"}).Value)
            }
            "CMServer"
            {
                $_PackageName            = $($(Format-MSIXPackageInfo -AppName "$($Application.LocalizedDisplayName)-$($_ContentID.Substring($_ContentID.Length-6, 6))" ))
                $_PackageDisplayName     = $Application.LocalizedDisplayName
                $_PublisherDisplayname   = $Application.Manufacturer
                $_ApplicationDescription = $Application.LocalizedDescription
                $_CMAppPackageID         = $Application.PackageID
                $_AppInstallerFolderPath = $(Get-Item -Path $($Deployment.Installer.Contents.Content.Location)).FullName
                $_InstallerFolderPath    = $("C:\Temp\" + $($_AppInstallerFolderPath.TrimStart("\")))
                $_InstallerPath          = $($_InstallerFolderPath + $_AppFileName)
                $_UninstallerPath        = $($_UninstallerPath)
                $_ContentParentRoot      = $("")
                $_PackageVersion         = Format-MSIXPackageInfo -AppVersion $($Application.SoftwareVersion)
            }
        }

        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PackageDisplayName"      -Value $($_PackageDisplayName)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PublisherDisplayName"    -Value $($_PublisherDisplayname)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppDescription"          -Value $($_ApplicationDescription)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "CMAppPackageID"          -Value $($_CMAppPackageID)

        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PackageName"             -Value $($_PackageName)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PublisherName"           -Value $($_PublisherName)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PackageVersion"          -Value $($_PackageVersion)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "RequiresUserInteraction" -Value $($_RequiresUserInteraction)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppFolderPath"           -Value $($_AppFolderPath)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppInstallerFolderPath"  -Value $($_AppInstallerFolderPath)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppFileName"             -Value $($_AppFileName)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "AppIntallerType"         -Value $($_AppInstallerType)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "ContentID"               -Value $($_ContentID)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "InstallerArguments"      -Value $($_InstallerArgument)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "ExecutionContext"        -Value $($_ExecutionContext)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "ContentParentRoot"       -Value $($_ContentParentRoot)

        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "InstallerPath"           -Value $($_InstallerPath)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "InstallerFolderPath"     -Value $($_InstallerFolderPath)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "UninstallerPath"         -Value $($_UninstallerPath)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "UninstallerArgument"     -Value $($_UninstallerArgument)
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "DeploymentType"          -Value $($_DeploymentType)
     
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
        $MSIXAppDetails | Add-Member -MemberType NoteProperty -Name "PackageName" -Value $(Format-MSIXPackageInfo -AppName $($Application.LocalizedDisplayName))
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

Function Format-MSIXPackageInfo ([Parameter(Mandatory=$True,ParameterSetName=$('PackageVersion'),Position=0)]  $AppVersion,
                                 [Parameter(Mandatory=$True,ParameterSetName=$('PackageArgument'),Position=1)] $AppArgument,
                                 [Parameter(Mandatory=$True,ParameterSetName=$('PackageName'),Position=2)]     $AppName)
{
    switch ($PSCmdlet.ParameterSetName) 
    {
        "PackageName"     
        {
            New-LogEntry -LogValue "    Removing Special Characters from the Application Package Name." -Component "Format-MSIXPackagingName" -Severity 1 -WriteHost $VerboseLogging
            $MSIXPackageName = $AppName -replace '[!,@,#,$,%,^,&,*,(,),+,=,~,`]',''
            $MSIXPackageName = $MSIXPackageName -replace '_','-'
            $MSIXPackageName = $MSIXPackageName -replace ' ','-'
        
            IF($MSIXPackageName.Length -gt 43)
                { $MSIXPackageName = $MSIXPackageName.Substring(0,43) }
        
            Return $MSIXPackageName
        }
        "PackageArgument" 
        {
            $MSIXPackageArgument = $AppArgument

            IF($MSIXPackageArgument.StartsWith(" "))
                { $MSIXPackageArgument = Format-MSIXPackageInfo -AppArgument $MSIXPackageArgument.Substring(1, $MSIXPackageArgument.Length -1) }

            Return $MSIXPackageArgument
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
            Return $NewPackageVersion
        }
        Default {}
    }
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

    #Test-PSArchitecture
    IF(!$(Connect-CMEnvironment $SiteCode)) {Return}
    $MSIXAppMetaData = Get-CMAppMetaData $ApplicationName
    Disconnect-CMEnvironment

    $workingDirectory = [System.IO.Path]::Combine($PSScriptRoot, "out")

    RunConversionJobs -conversionsParameters $MSIXAppMetaData -virtualMachines $virtualMachines -remoteMachines $remoteMachines $workingDirectory

    SignAndDeploy "$workingDirectory\MSIX"

}

Function Get-CMExportAppData ($SigningCertificatePublisher,
                              [string]$AppName="*",
                              [Parameter(Mandatory=$True,ParameterSetName=$('CMExportPathTarget'),Position=0)]  [string]$CMAppContentPath,
                              [Parameter(Mandatory=$True,ParameterSetName=$('CMExportPathTarget'),Position=1)]  [string]$CMAppMetaDataPath,
                              [Parameter(Mandatory=$True,ParameterSetName=$('CMExportPathParent'),Position=0)]  [string]$CMAppParentPath,
                              [Parameter(Mandatory=$True,ParameterSetName=$('CMServer'), Position=0)]  [string]$CMSiteCode,
                              [Parameter(Mandatory=$True,ParameterSetName=$('CMServer'), Position=1)]  [string]$CMSiteServer
                             )
{
    $AppDetails    = @()
    $CMApplication = @()

    Switch ($PSCmdlet.ParameterSetName)
    {
        "CMExportPathTarget" 
        {
            ## If querying a single exported source.
            New-LogEntry -LogValue "Identified source is targetting a single export directory" -Severity 1 -Component "Get-CMExportAppData"

            $CMAppMetaData = Get-ChildItem -Recurse -Path $CMAppMetaDataPath
            $CMAppContent  = Get-ChildItem -Recurse -Path $CMAppContentPath
            $CMApplication = $($CMAppMetaData.Where({$_.FullName -like "*SMS_Application*object.xml"}))
        }
        "CMExportPathParent"
        {
            ## If querying multiple exported sources all at once
            New-LogEntry -LogValue "Identied source is targetting parent directory" -Severity 1 -Component "Get-CMExportAppData"

            $CMAppMetaData = Get-ChildItem -Recurse -Path $CMAppParentPath
            $CMAppContent  = Get-ChildItem -Recurse -Path $CMAppParentPath
            $CMApplication = $($CMAppMetaData.Where({$_.FullName -like "*SMS_Application*object.xml"}))
        }
        "CMServer"
        {
            New-LogEntry -LogValue "Collecting information from ConfigMgr for application: $AppName" -Component "Get-CMAppMetaData"

            ## Attempts to connect to ConfigMgr environment, if fails, returns zero conversion results.
            IF(!$(Connect-CMEnvironment $CMSiteCode $CMSiteServer)) {Return}

            $CMApplication = Get-CMApplication -Name $AppName
            Write-Host $($CMApplication.LocalizedDisplayName) -ForegroundColor Yellow

            Disconnect-CMEnvironment
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
                $AppDetails += Format-MSIXAppExportDetails -Application $CMApp -ApplicationDeploymentType $CMAppDeploymentType -CMExportAppPath $CMAppContent -CMAppPath $CMAppPath -SigningCertificatePublisher $SigningCertificatePublisher
            }
        }
        ELSEIF($PSCmdlet.ParameterSetName -eq "CMServer")
        {
            ## App Content was sourced from ConfigMgr Server.
            $CMAppDeploymentType = [xml]($CMApp.SDMPackageXML)
            $AppDetails += Format-MSIXAppExportDetails -Application $CMApp -ApplicationDeploymentType $CMAppDeploymentType -SigningCertificatePublisher $SigningCertificatePublisher -CMServer
        }
    }

    Return $AppDetails
}
