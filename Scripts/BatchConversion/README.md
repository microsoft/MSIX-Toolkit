# Batch Conversion scripts
A set of basic scripts that allow converting a batch of installers on a set of machines using MSIX Packaging Tool:

## Supporting scripts
1. batch_convert.ps1 - Dispatch work to target machines
2. sign_deploy_run.ps1 - Sign resulting packages
3. run_job.ps1 - Attempt to run the packages locally for initial validation

## Usage
Edit the file entry.ps1 with the parameters of your virtual/remote machines and installers you would like to convert.
Run: entry.ps1
