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
        PackageName          = "YourApp1";
        PackageDisplayName   = "Your App1";
        PublisherName        = "CN=YourCompany";
        PublisherDisplayName = "YourCompany";
        PackageVersion       = "1.0.0.0";
        InstallerPath        = "Path\to\YourInstaller1.msi";
     },
    @{
        PackageName          = "YourApp2";
        PackageDisplayName   = "Your App2";
        PublisherName        = "CN=YourCompany";    
        PublisherDisplayName = "YourCompany";
        PackageVersion       = "1.0.0.0";
        InstallerPath        = "Path\to\YourInstaller2.exe";
        InstallerArguments   = "\Silent"            
    }#,
#    @{
#        PackageName          = "YourApp3";                                          ## Package File Name (No spaces or special characters)
#        PackageDisplayName   = "Your App3";                                         ## The name of the Application
#        PublisherName        = "CN=YourCompany";                                    ## This must be the same as the code signing certificate.
#        PublisherDisplayName = "YourCompany";                                       ## Application Publisher Name
#        PackageVersion       = "1.0.0.0";                                           ## Application version (quad-octet)
#        InstallerPath        = "Path\to\YourInstaller3.exe";                        ## File Path to the Installation media
#        InstallerArguments   = "";                                                  ## Required If Installer is not an MSI.
#        SavePackagePath      = $([System.IO.Path]::Combine($PSScriptRoot, "out"));  ## Optional - Working Directory will be used if not provided.
#        SaveTemplatePath     = $([System.IO.Path]::Combine($PSScriptRoot, "out"))   ## Optional - Working Directory will be used if not provided.
#   }
)

## Converts the identified applications to MSIX Packaging Format.
Write-Host "`n###########  Packaging Applications  ###########" -BackgroundColor Black
RunConversionJobs -conversionsParameters $conversionsParameters -virtualMachines $virtualMachines -remoteMachines $remoteMachines $workingDirectory

## Signs the previously created MSIX Apps with provided certificate.
Write-Host "`n############  Signing Applications  ############" -BackgroundColor Black
Set-MSIXSignApp -conversionsParameters $conversionsParameters -WorkingDirectory $workingDirectory -CertificatePath $($SigningCertificate.Path) -CertificatePassword $($SigningCertificate.Password)