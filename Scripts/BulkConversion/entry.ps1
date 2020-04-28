. $PSScriptRoot\bulk_convert.ps1
. $PSScriptRoot\SharedScriptLib.ps1
. $PSScriptRoot\Sign_deploy_run.ps1

## Specifies the directory that will host the newly created MSIX Packaged Apps.
$workingDirectory = [System.IO.Path]::Combine($PSScriptRoot, "out")

## Retrieves the credentials that will be used for connecting to both Virtual and Remote Machines. Credentials must be consistent.
New-LogEntry -LogValue "Collecting credentials for accessing the Remote / Virtual Machines" -Component "entry.ps1"
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
        PackageName = "YourApp2";
        PackageDisplayName = "Your App2";
        PublisherName = "CN=YourCompany";
        PublisherDisplayName = "YourCompany";
        PackageVersion = "1.0.0.0"
        Installers = @{
            InstallerPath = "Path\To\Your\Installer\YourInstaller2.msi"
     },
    @{
       PackageName = "YourApp2";
       PackageDisplayName = "Your App2";
       PublisherName = "CN=YourCompany";
       PublisherDisplayName = "YourCompany";
       PackageVersion = "1.0.0.0"
       Installers = @{
           InstallerPath = "Path\To\Your\Installer\YourInstaller2.msi"
}
   },
    @{
        PackageName             = "YourApp2";
        PackageDisplayName      = "Your App2";
        PublisherName           = "CN=YourCompany";                                         ## This must be the same as the code signing certificate.
        PublisherDisplayName    = "YourCompany";
        PackageVersion          = "1.0.0.0"
        Installers = @{
            InstallerPath       = "Path\To\Your\Installer\YourInstaller2.msi";
#            InstallerArguements = ""                                                       ## Optional - If Installer is MSI otherwise required.
#       $SavePackagePath = [System.IO.Path]::Combine($PSScriptRoot, "out\MSIX");            ## Optional - Working Directory will be used if not provided.
#       $SaveTemplatePath - [System.IO.Path]::Combine($PSScriptRoot, "out\MPT_Templates");  ## Optional - Working Directory will be used if not provided.
   }
)

## Converts the identified applications to MSIX Packaging Format.
RunConversionJobs -conversionsParameters $conversionsParameters -virtualMachines $virtualMachines -remoteMachines $remoteMachines $workingDirectory

## Signs the previously created MSIX Apps with provided certificate.
Set-MSIXSignApp -msixFolder "$workingDirectory\MSIX" -CertificatePath $SigningCertificate.Path -CertificatePassword $SigningCertificate.Password