A set of basic scripts that allow converting a batch of installers on a set of machines using MSIX Packaging Tool:

Supporting scripts:
1. batch_convert.ps1 - Dispatch work to target machines
2. sign_deploy_run.ps1 - Sign resulting packages
3. run_job.ps1 - Attempt to run the packages locally for initial validation

## Package specified MSIs locally or on virtual/remote machines
The script point is *entry.ps1*

**Note:** Edit the file entry.ps1 with the parameters of your virtual/remote machines and installers you would like to convert.

**Run:**

`.\entry.ps1`


## Packages all MSIs or executables from a folder on multiple virtual machines
The script is *ParallelPackaging.ps1*. It takes 3 parameters:
- VMNames = Names of the local virtual machines on which we run the packaging in parallel. The names are comma separated
- FolderContainingMSIs - Local full path name of the folder containing all MSIs to package
- publisherName - Full name of the publisher which has to be the same as the signing certificate like `CN=Contoso Software (FOR LAB USE ONLY), O=Contoso Corporation, C=US`


**Note:** In order to perform a checkpoint/restore between each packaging and have a clean VM each time you have to uncomment the commented line of the script *run_job.js1*.

**⚠ Caution:** Support for executables is actually a partial support. The goal of this script is to run automatically for all files (.exe or .msi) from a folder. For executables, we need the *silent* switch. It can be different from each executable. So we will need to add another parameter to provide the switches. Right now, we use "/S" for all executables.

**Example:** 

`.\ParallelPackaging.ps1 -VMNames MSIXVM01,MSIXVM02 -FolderContainingMSIs C:\Temp\FolderWithMSIs\ -publisherName "Contoso Software (FOR LAB USE ONLY), O=Contoso Corporation, C=US"`