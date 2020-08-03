Param
(
        $ExportedCMAppsPath = "C:\Temp\Demo\ConfigMgrExport_files\",
        $ExportedCMAppMetaData = "C:\Temp\Demo\ConfigMgrExport\",
        $CMAppParentPath = ""
)

## Script Starts
$workingDirectory = [System.IO.Path]::Combine($($PSScriptRoot), "out")

# Imports the Function Library
. $PSScriptRoot\..\MSIXConnect\Get-MSIXConnectLib.ps1
. $PSScriptRoot\..\BulkConversion\bulk_convert.ps1
. $PSScriptRoot\..\BulkConversion\SharedScriptLib.ps1
. $PSScriptRoot\..\BulkConversion\sign_deploy_run.ps1

## Retrieves the credentials that will be used for connecting to both Virtual and Remote Machines. Credentials must be consistent.
New-LogEntry -LogValue "Collecting credentials for accessing the Remote / Virtual Machines" -Component "entry.ps1"
$credential = Get-Credential


$CertPassword  = "[Cert Password]"
$CertPath      = "[Path to PFX Signing Cert]"
$CertPublisher = $(Get-PfxData -FilePath $($CertPath) -Password $($(ConvertTo-SecureString -String $($CertPassword) -AsPlainText -force))).EndEntityCertificates.Subject

$SigningCertificate = @{
    Password = $CertPassword; Path = $CertPath; Publisher = $CertPublisher
}

## Virtual Machines to be used for converting applications to the MSIX Packaging format.
$virtualMachines = @(
    @{ Name = "[Hyper-V VM Name]"; Credential = $credential }
)

## Remote Machines to be used for converting applications to the MSIX Packaging format.
$remoteMachines = @(
    @{ Name = "[ComputerName]"; Credential = $credential }
)


$conversionsParameters = @()
$conversionsParameters = Get-CMExportAppData -CMSiteCode "[ConfigMgr 3 Character Site Code]" -CMSiteServer "[ConfigMgr Site Server Name]" -AppName "[App Name - Optional]" -SigningCertificate $SigningCertificate

## Converts the identified applications to MSIX Packaging Format.
Write-Host "`n###########  Packaging Applications  ###########" -BackgroundColor Black
RunConversionJobs -conversionsParameters $conversionsParameters -virtualMachines $virtualMachines -remoteMachines $remoteMachines $workingDirectory

## Signs the previously created MSIX Apps with provided certificate.
Write-Host "`n############  Signing Applications  ############" -BackgroundColor Black
Set-MSIXSignApp -conversionsParameters $conversionsParameters -WorkingDirectory $workingDirectory -CertificatePath $($SigningCertificate.Path) -CertificatePassword $($SigningCertificate.Password)