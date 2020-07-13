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

# ## The Code Signing certificate to be used for signing the MSIX Apps.
# $SigningCertificate = @{
#     Password = "P@ssw0rd"; Path = "C:\Temp\cert.pfx"
# }
#
# ## Virtual Machines to be used for converting applications to the MSIX Packaging format.
# $virtualMachines = @(
#     @{ Name = "vm1"; Credential = $credential }
#     @{ Name = "vm2"; Credential = $credential }
# )
#
# ## Remote Machines to be used for converting applications to the MSIX Packaging format.
# $remoteMachines = @(
#     @{ ComputerName = "YourVMNameHere.westus.cloudapp.azure.com"; Credential = $credential }
# )

## The Code Signing certificate to be used for signing the MSIX Apps.
$SigningCertificate = @{
    Password = "MSIX!Lab1809"; Path = "C:\Temp\Certs\msix-lab-cert.pfx"
}

## Virtual Machines to be used for converting applications to the MSIX Packaging format.
$virtualMachines = @(
    @{ Name = "MSIX Packaging Tool Environment"; Credential = $credential }
#    @{ Name = "MSIX Packaging Tool Environment 1"; Credential = $credential }
#    @{ Name = "vm2"; Credential = $credential }
)

## Remote Machines to be used for converting applications to the MSIX Packaging format.
$remoteMachines = @(
    @{ Name = "DESKTOP-VQQKQF9"; Credential = $credential }
)

$conversionsParameters = @()
#$conversionsParameters = Get-CMExportAppData -CMAppContentPath $ExportedCMAppsPath -CMAppMetaDataPath $ExportedCMAppMetaData
$conversionsParameters = Get-CMExportAppData -CMAppParentPath $CMAppParentPath

## Converts the identified applications to MSIX Packaging Format.
Write-Host "`n###########  Packaging Applications  ###########" -BackgroundColor Black
#RunConversionJobs -conversionsParameters $conversionsParameters -virtualMachines $virtualMachines -remoteMachines $remoteMachines $workingDirectory
RunConversionJobsVMLocal -conversionsParameters $conversionsParameters $remoteMachines $virtualMachines $workingDirectory

## Signs the previously created MSIX Apps with provided certificate.
Write-Host "`n############  Signing Applications  ############" -BackgroundColor Black
Set-MSIXSignApp -conversionsParameters $conversionsParameters -WorkingDirectory $workingDirectory -CertificatePath $($SigningCertificate.Path) -CertificatePassword $($SigningCertificate.Password)
