Param
(
        $ExportedCMAppsPath = "C:\Temp\ConfigMgrOutput_files",
        $ExportedCMAppMetaData = "C:\Temp\ConfigMgrOutput")

# Imports the Function Library
. $PSScriptRoot\Get-MSIXConnectLib.ps1
. $PSScriptRoot\..\BulkConversion\bulk_convert.ps1
#. $PSScriptRoot\..\BulkConversion\run_job.ps1
. $PSScriptRoot\..\BulkConversion\SharedScriptLib.ps1
#. $PSScriptRoot\..\BulkConversion\sign_deploy_run.ps1

## Script Starts
$workingDirectory = [System.IO.Path]::Combine($PSScriptRoot, "out")

## Retrieves the credentials that will be used for connecting to both Virtual and Remote Machines. Credentials must be consistent.
New-LogEntry -LogValue "Collecting credentials for accessing the Remote / Virtual Machines" -Component "entry.ps1"
#$credential = Get-Credential

## The Code Signing certificate to be used for signing the MSIX Apps.
$SigningCertificate = @{
    Password = "P@ssw0rd"; Path = "C:\Temp\cert.pfx"
}

## Virtual Machines to be used for converting applications to the MSIX Packaging format.
$virtualMachines = @(
    @{ Name = "vm1"; Credential = $credential }
    @{ Name = "vm2"; Credential = $credential }
)

## Remote Machines to be used for converting applications to the MSIX Packaging format.
$remoteMachines = @(
    @{ ComputerName = "YourVMNameHere.westus.cloudapp.azure.com"; Credential = $credential }
)

$conversionsParameters = @()
$conversionsParameters = Get-CMExportAppData -CMAppContentPath $ExportedCMAppsPath -CMAppMetaDataPath $ExportedCMAppMetaData

## Converts the identified applications to MSIX Packaging Format.
#Write-Host "`n###########  Packaging Applications  ###########" -BackgroundColor Black
#RunConversionJobs -conversionsParameters $conversionsParameters -virtualMachines $virtualMachines -remoteMachines $remoteMachines $workingDirectory

## Signs the previously created MSIX Apps with provided certificate.
#Write-Host "`n############  Signing Applications  ############" -BackgroundColor Black
#Set-MSIXSignApp -conversionsParameters $conversionsParameters -WorkingDirectory $workingDirectory -CertificatePath $($SigningCertificate.Path) -CertificatePassword $($SigningCertificate.Password)

Write-host $conversionsParameters