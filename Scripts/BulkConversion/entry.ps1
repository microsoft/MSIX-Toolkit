. $PSScriptRoot\bulk_convert.ps1
. $PSScriptRoot\SharedScriptLib.ps1

## Retrieves the credentials that will be used for connecting to both Virtual and Remote Machines. Credentials must be consistent.
$credential = Get-Credential

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

## Applications to be converted.
$conversionsParameters = @(
    @{
        InstallerPath = "Path\To\Your\Installer\YourInstaller.msi";
        PackageName = "YourApp";
        PackageDisplayName = "Your App";
        PublisherName = "CN=YourCompany";
        PublisherDisplayName = "YourCompany";
        PackageVersion = "1.0.0.0"
    },
    @{
       InstallerPath = "Path\To\Your\Installer\YourInstaller2.msi";
       PackageName = "YourApp2";
       PackageDisplayName = "Your App2";
       PublisherName = "CN=YourCompany";
       PublisherDisplayName = "YourCompany";
       PackageVersion = "1.0.0.0"
    },
    @{
       InstallerPath = "Path\To\Your\Installer\YourInstaller3.msi";
       PackageName = "YourApp3";
       PackageDisplayName = "Your App3";
       PublisherName = "CN=YourCompany";
       PublisherDisplayName = "YourCompany";
       PackageVersion = "1.0.0.0"
    }
)

$workingDirectory = [System.IO.Path]::Combine($PSScriptRoot, "out")

## Converts the identified applications to MSIX Packaging Format.
RunConversionJobs -conversionsParameters $conversionsParameters -virtualMachines $virtualMachines -remoteMachines $remoteMachines $workingDirectory

## Signs the previously created MSIX Apps with provided certificate.
Set-MSIXSignApp -msixFolder "$workingDirectory\MSIX" -CertificatePath $SigningCertificate.Path -CertificatePassword $SigningCertificate.Password