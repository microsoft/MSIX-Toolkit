Param
(
        [Parameter(Mandatory, ParameterSetName="CMExportPathTarget")] $ExportedCMAppsPath = "C:\Temp\Demo\ConfigMgrExport_files\",
        [Parameter(Mandatory, ParameterSetName="CMExportPathTarget")] $ExportedCMAppMetaData = "C:\Temp\Demo\ConfigMgrExport\",
        [Parameter(Mandatory, ParameterSetName="CMExportPathParent")] $CMAppParentPath = "C:\Temp\Demo",
        [Parameter(Mandatory, ParameterSetName="CMServer"          )] $CMSiteCode     = "[ConfigMgr Site Code]",
        [Parameter(Mandatory, ParameterSetName="CMServer"          )] $CMSiteServer   = "[FQDN of the ConfigMgr Site Server]"
)

# Imports the Function Library
. $PSScriptRoot\..\MSIXConnect\Get-MSIXConnectLib.ps1
. $PSScriptRoot\..\BulkConversion\bulk_convert.ps1
. $PSScriptRoot\..\BulkConversion\SharedScriptLib.ps1
. $PSScriptRoot\..\BulkConversion\sign_deploy_run.ps1

## Variable Declaration
$workingDirectory   = [System.IO.Path]::Combine($($PSScriptRoot), "out")
$credential         = Get-Credential

################################
#########  Edit Below  #########
#############################################################################

$CMAppName      = "[Name of Application - Optional]"
$CertPassword   = "[Cert Password]"
$CertPath       = "[Path to PFX Signing Cert]"

## Virtual Machines to be used for converting applications to the MSIX Packaging format.
[TargetMachine[]] $virtualMachines = @(
    @{ Name = "[Hyper-V VM Name]"; Credential = $credential }
    @{ Name = "[Hyper-V VM Name]"; Credential = $credential }
    @{ Name = "[Hyper-V VM Name]"; Credential = $credential }
)

## Remote Machines to be used for converting applications to the MSIX Packaging format.
[TargetMachine[]] $remoteMachines = @(
    @{ ComputerName = "[ComputerName]"; Credential = $credential }
    @{ ComputerName = "[ComputerName]"; Credential = $credential }
    @{ ComputerName = "[ComputerName]"; Credential = $credential }
)

#############################################################################
#########  Stop Edits  #########
################################

$CertPublisher  = $(Get-PfxData -FilePath $($CertPath) -Password $($(ConvertTo-SecureString -String $($CertPassword) -AsPlainText -force))).EndEntityCertificates.Subject

[CodeSigningCert] $SigningCertificate = @{
    Password = $CertPassword; Path = $CertPath; Publisher = $CertPublisher
}

Write-Host "`n###########  Collecting Applications  ###########" -BackgroundColor Black
[ConversionParam[]] $conversionsParameters = @()

Switch ($PSCmdlet.ParameterSetName)
{
    "CMExportPathTarget"
        { $conversionsParameters = Get-CMExportAppData -CMAppContentPath $CMSiteCode -CMAppMetaDataPath $CMSiteServer -AppName $CMAppName -SigningCertificate $SigningCertificate -WorkingDirectory $workingDirectory }
    "CMExportPathParent"
        { $conversionsParameters = Get-CMExportAppData -CMAppParentPath $CMSiteCode -AppName $CMAppName -SigningCertificate $SigningCertificate -WorkingDirectory $workingDirectory }
    "CMServer"
        { $conversionsParameters = Get-CMExportAppData -CMSiteCode $CMSiteCode -CMSiteServer $CMSiteServer -AppName $CMAppName -SigningCertificate $SigningCertificate -WorkingDirectory $workingDirectory }
}

## Verifies that there are application conversion details to be converted.
IF($conversionsParameters -ne "" -and $null -ne $conversionsParameters)
{
    ## Converts the identified applications to MSIX Packaging Format.
    Write-Host "`n###########  Packaging Applications  ###########" -BackgroundColor Black
    RunConversionJobs -conversionsParameters $conversionsParameters -virtualMachines $virtualMachines -remoteMachines $remoteMachines $workingDirectory

    ## Signs the previously created MSIX Apps with provided certificate.
    Write-Host "`n############  Signing Applications  ############" -BackgroundColor Black
    Set-MSIXSignApp -conversionsParameters $conversionsParameters -WorkingDirectory $workingDirectory -CertificatePath $($SigningCertificate.Path) -CertificatePassword $($SigningCertificate.Password)
}