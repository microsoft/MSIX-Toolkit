Param
(
    [Parameter(Mandatory=$True,HelpMessage="Please Enter CM SiteCode",ParameterSetName=$('Execution'))]
        $SiteCode = "CM1",
    [Parameter(Mandatory=$True,HelpMessage="Please Enter the Site Server name",ParameterSetName=$('Execution'))]
        $SiteServerServerName = "CL-CM01",
    [Parameter(Mandatory=$True,HelpMessage="Please Enter the Site Server name",ParameterSetName=$('Execution'))]
        $ApplicationName = "Notepad++"
)

# Imports the Function Library
. .\Get-MSIXConnectLib.ps1


Test-PSArchitecture
IF(!$(Connect-CMEnvironment $SiteCode)) {Return}

$MSIXAppMetaData = Get-CMAppMetaData $ApplicationName



$credential = Get-Credential

$virtualMachines = @(
    @{ Name = "vm1"; Credential = $credential }
    @{ Name = "vm2"; Credential = $credential }
)

$remoteMachines = @(
    @{ ComputerName = "YourVMNameHere.westus.cloudapp.azure.com"; Credential = $credential }
)
