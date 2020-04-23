# Batch Conversion scripts
A set of basic scripts that allow converting a batch of installers on a set of machines using MSIX Packaging Tool:

## Supporting scripts
1. batch_convert.ps1 - Dispatch work to target machines
1. sign_deploy_run.ps1 - Sign resulting packages
1. run_job.ps1 - Attempt to run the packages locally for initial validation
1. SharedScriptLib.ps1 - Shared Function library used by all scripts.
1. entry.ps1 - Provides application, virtual machine, and /or remote machine information then executes scripts based on information provided.

## Usage
Edit the file entry.ps1 with the parameters of your virtual/remote machines and installers you would like to convert.
Run: entry.ps1

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