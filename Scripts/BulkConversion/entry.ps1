. $PSScriptRoot\bulk_convert.ps1
. $PSScriptRoot\sign_deploy_run.ps1

##
## Usage:
##
$credential = Get-Credential

$virtualMachines = @(
    @{ Name = "vm1"; Credential = $credential }
    @{ Name = "vm2"; Credential = $credential }
)

$remoteMachines = @(
    @{ ComputerName = "YourVMNameHere.westus.cloudapp.azure.com"; Credential = $credential }
)

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

RunConversionJobs -conversionsParameters $conversionsParameters -virtualMachines $virtualMachines -remoteMachines $remoteMachines $workingDirectory

SignAndDeploy "$workingDirectory\MSIX"