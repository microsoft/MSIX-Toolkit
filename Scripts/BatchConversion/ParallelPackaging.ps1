<#

.SYNOPSIS
ParallelPackaging.ps1

.DESCRIPTION
Uses multiple local VMs in order to package in parallel all MSIs of a given folder
The syntax is:
ParallelPackaging.ps1 -VMNames <VMs name comma separated> -FolderContainingMSIs <folder path> -publisherName <publisher name>

.EXAMPLE
Use a full path to an .APPXBUNDLE file:
ParallelPackaging.ps1 -VMNames MSIXVM01,MSIXVM02 -FolderContainingMSIs C:\Temp\FolderWithMSIs\ -publisherName "Contoso Software (FOR LAB USE ONLY), O=Contoso Corporation, C=US"

.NOTES
All the VMs have to use the same login/password

.LINK
https://github.com/microsoft/MSIX-Toolkit/tree/master/Scripts/BatchConversion

#>[CmdletBinding()]
Param(
    [parameter(Mandatory=$true, HelpMessage="Names of the local VMs to use to package MSIX (comma separated). All VMs must have the same login/password")]
    [AllowEmptyString()]
    [string[]]$VMNames,

    [parameter(Mandatory=$true, HelpMessage="Folder containing all MSIs to package")]
    [AllowEmptyString()]
    [string]$FolderContainingMSIs,
    
    [parameter(Mandatory=$true, HelpMessage="Exact name of the Publisher (will be used for the signing)")]
    [AllowEmptyString()]
    [string]$publisherName  
)


# Include scripts from the MSI-Toolbox
. $PSScriptRoot\batch_convert.ps1
. $PSScriptRoot\sign_deploy_run.ps1




# Starting point
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::CreateSpecificCulture("en-US") 


if ($VMName -eq '') {
    Write-Host "[Error] A VM name was not specified." -ForegroundColor Red
    #Write-Host "Please use 'get-help .\MakeAPPXForWin10S.ps1' for more details" 
    exit 
}


$credential = Get-Credential



Add-Type @'
public class CVMName
{
    public string Name;    
    public System.Management.Automation.PSCredential Credential;
}
'@    


$virtualMachines = @()

foreach ($o in $VMNames) {
    $vm = New-Object CVMName
    $vm.Name = $o
    $vm.Credential = $credential
    $virtualMachines += $vm
}


$remoteMachines = @(
    #@{ ComputerName = "."; Credential = $credential }
)



Add-Type @'
public class Cparameter
{
    public string InstallerPath;    
    public string PackageName;
    public string PackageDisplayName;
    public string PublisherName;
    public string PublisherDisplayName;
    public string PackageVersion;
}
'@    


$conversionsParameters = @()

$root = $FolderContainingMSIs
get-childitem $root -recurse | Where-Object {$_.extension -eq ".msi"} | % {
  
    $o = New-Object Cparameter
    $o.InstallerPath = $_.FullName
    $o.PackageName = $_.BaseName
    $o.PackageDisplayName = $_.BaseName
    $o.PublisherName = $publisherName;
    $o.PublisherDisplayName = $publisherName;
    $o.PackageVersion = "1.0.0.0"

    $conversionsParameters += $o
}



$workingDirectory = [System.IO.Path]::Combine($PSScriptRoot, "out")

Write-Host 
Write-Host "Here is the job you asked"
Write-Host "========================="
Write-Host "- Packaging all MSIs of the folder '$FolderContainingMSIs'"
Write-Host "- Using the following VMs: "
foreach ($o in $virtualMachines) {
	Write-Host "`t" $o.Name
}
Write-Host "- Using the publisher name : '$publisherName'"
Write-Host
Write-Host "Press ENTER continue or CTRL+C to stop here" -ForegroundColor Yellow
Read-Host


RunConversionJobs -conversionsParameters $conversionsParameters -virtualMachines $virtualMachines -remoteMachines $remoteMachines $workingDirectory

SignAndDeploy "$workingDirectory\MSIX"
