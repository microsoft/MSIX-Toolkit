. $PSScriptRoot\bulk_convert.ps1
. $PSScriptRoot\SharedScriptLib.ps1
. $PSScriptRoot\Sign_deploy_run.ps1

## Variable Declaration
$workingDirectory = [System.IO.Path]::Combine($PSScriptRoot, "out")
$credential = Get-Credential

################################
#########  Edit Below  #########
#############################################################################

$CertPassword  = "[Cert Password]"
$CertPath      = "[Path to PFX Signing Cert]"
$CertPublisher = $(Get-PfxData -FilePath $($CertPath) -Password $($(ConvertTo-SecureString -String $($CertPassword) -AsPlainText -force))).EndEntityCertificates.Subject

## Virtual Machines to be used for converting applications to the MSIX Packaging format.
[TargetMachine[]] $virtualMachines = @(
    @{ Name = "[Hyper-V VM Name]"; Credential = $credential }
    @{ Name = "[Hyper-V VM Name]"; Credential = $credential }
    @{ Name = "[Hyper-V VM Name]"; Credential = $credential }
)

## Remote Machines to be used for converting applications to the MSIX Packaging format.
[TargetMachine[]] $remoteMachines = @(
    @{ Name = "[ComputerName]"; Credential = $credential }
    @{ Name = "[ComputerName]"; Credential = $credential }
    @{ Name = "[ComputerName]"; Credential = $credential }
)

## Applications to be converted.
[ConversionParam[]] $conversionsParameters = @(
    @{
        PackageName          = "YourApp1";
        PackageDisplayName   = "Your App1";
        PublisherName        = $CertPublisher;
        PublisherDisplayName = "YourCompany";
        PackageVersion       = "1.0.0.0";
        InstallerPath        = "Path\to\YourInstaller1.msi";
     },
    @{
        PackageName          = "YourApp2";
        PackageDisplayName   = "Your App2";
        PublisherName        = $CertPublisher;    
        PublisherDisplayName = "YourCompany";
        PackageVersion       = "1.0.0.0";
        InstallerPath        = "Path\to\YourInstaller2.exe";
        InstallerArguments   = "\Silent"            
    }
)

#############################################################################
#########  Stop Edits  #########
################################

[CodeSigningCert]$SigningCertificate = @{
    Password = $CertPassword; Path = $CertPath; Publisher = $CertPublisher
}

## Converts the identified applications to MSIX Packaging Format.
Write-Host "`n###########  Packaging Applications  ###########" -BackgroundColor Black
RunConversionJobs -conversionsParameters $conversionsParameters -virtualMachines $virtualMachines -remoteMachines $remoteMachines $workingDirectory

## Signs the previously created MSIX Apps with provided certificate.
Write-Host "`n############  Signing Applications  ############" -BackgroundColor Black
Set-MSIXSignApp -conversionsParameters $conversionsParameters -WorkingDirectory $workingDirectory -CertificatePath $($SigningCertificate.Path) -CertificatePassword $($SigningCertificate.Password)