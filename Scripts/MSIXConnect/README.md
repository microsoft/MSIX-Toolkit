# Bulk Conversion scripts
A set of PowerShell scripts that will retrieve application installation information from ConfigMgr Database or Application export.

## Supporting scripts
1. New-MSIXConnectLib.ps1 - Contains the library of PowerShell scripts used to retrieve application information from ConfigMgr database, or an application export.
1. New-MSIXConnectExportMakeMSIX.ps1 - Provides the virtual and/or remote machine information then executes the collection of application information, before bulk converting each app.

## Usage
Edit the file New-MSIXConnectExportMakeMSIX.ps1 with the parameters of your virtual/remote machines and installers you would like to convert.
Run: New-MSIXConnectExportMakeMSIX.ps1

## Prerequisites
Prior to running the entry.ps1 script, the following prerequisites must be met to ensure a successful application packaing experience.

| Term            | Description                                                        |
|-----------------|--------------------------------------------------------------------|
| Host Machine    | This is the device executing the entry.ps1 script.                 |
| Virtual Machine | This is a device existing in Hyper-V, hosted on the Host Machine.  |
| Remote Machine  | This is a physical or virtual machine accessible over the network. |

### Host Machine
The Host Machine must meet the following requirements:
* PowerShell must allow running of scripts.
* PowerShell must be run as Administrator.
* MSIX Packaging Tool must be installed.
* If Virtual Machines are used, Hyper-V must be installed.
* If Remote Machines are used, WinRM must be enabled, and Trusted host must be configured.
    * If Remote Machine is on the same domain, Trusted Host does not need to be configured.
    * If Remote Machine is not on the same domain, the Remote Machine must be configured as a Trusted Host.

### Virtual Machines:
It is recommended that the Hyper-V Quick Create - MSIX Packaging Tools Environment image be used as it meets the required configurations.

If you are using the Virtual Machine option, the virtual machine must be located on the Host Machine and running within Hyper-V

Virtual Machine must meet the following requirements:
* MSIX Packaging Tool Installed.

### Remote Machines:
Remote Machine must meet the following requirements:
* MSIX Packaging Tool Installed.
* Windows remoting (WinRM) must be enabled (winrm quickconfig)
* PowerShell Remoting must be enabled (Enable-PSRemoting -force)
* The WinRM Trusted Hosts must be configured:
    * If the devices are on the same domain, no action required.
    * If the devices are not on the same domain, WinRM Trusted Hosts must contain a reference to the device running the script.
