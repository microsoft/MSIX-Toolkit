Function New-LogEntry
{
Param(
    [Parameter(Position=0)] [string]  $LogValue,
    [Parameter(Position=1)] [string]  $Component = "",
    [Parameter(Position=2)] [int]     $Severity  = 1,
    [Parameter(Position=3)] [boolean] $WriteHost = $true,
                            [string]  $Path      = $($PSScriptRoot + "\Log")
)
    IF(!(Test-path -Path $Path)) {mkdir $Path}
    #Formats the values required to enter for Trace32 Format
    #$TimeZoneBias = Get-WmiObject -Query "Select Bias from Win32_TimeZone"
    [string]$Time = Get-Date -Format "HH:mm:ss.ffff"
    [string]$Date = Get-Date -Format "MM-dd-yyyy"

    #Appends the newest log entry to the end of the log file in a Trace32 Formatting
    $('<![LOG['+$LogValue+']LOG]!><time="'+$Time+'" date="'+$Date+'" component="'+$component+'" context="Empty" type="'+$severity+'" thread="Empty" file="'+"Empty"+'">') | out-file -FilePath $($Path+"\BulkConversion.log") -Append -NoClobber -encoding default

    IF($WriteHost)
    {
        Write-Host $("" + $LogValue) -ForegroundColor $(switch ($Severity) {1 {"White"} 2 {"Yellow"} 3 {"Red"}})
    }
}

Function New-InitialSnapshot ($SnapshotName, $VMName, $jobId="" )
{
    ## Verifies if the script snapshot exists, if not exists snapshot is created.
    IF ($SnapshotName -cnotin $(Get-VMSnapshot -VMName $vmName).Name)
    {
        New-LogEntry -LogValue "Creating VM Snap for VM ($VMName): $SnapshotName" -Component "run_job.ps1:$jobId" 
        $Scratch = Checkpoint-VM -Name $vmName -SnapshotName "$SnapshotName"
    }
    Else
    {
        New-LogEntry -LogValue "Snapshot ($SnapshotName) for VM ($VMName) already exists. " -Component "run_job.ps1:$jobId"
        }
}

Function Restore-InitialSnapshot ($SnapshotName, $VMName, $jobId="" )
{
    IF ($SnapshotName -in $(Get-VMSnapshot -VMName $vmName).Name)
    {
        New-LogEntry -LogValue "Reverting Virtual Machine to earlier snapshot ($initialSnapshotName)" -Component "run_job.ps1:$jobId"
        $Scratch = Restore-VMSnapshot -Name "$SnapshotName" -VMName $vmName -Confirm:$false
    }
}

Function Test-VMConnection ([string]$VMName)
{
    ## Retrieves a list of network interfaces for the machine.
    $HostNic = netsh interface ipv4 show interfaces

    ## Retrieves the VM Object, if no object found fails, and returns false.
    $GuestVM = Get-VM -Name $VMName -ErrorVariable Error -ErrorAction SilentlyContinue
    If ($Error) 
    {
        New-LogEntry -LogValue "Unable to locate $VMName on this machine." -Component "SharedScriptLib.ps1:Test-VMConnection" -Severity 3
        Return $false
    }

    ## Collects the name of the VM NIC.
    $GuestVMNic = $(Get-VMNetworkAdapter -VM $GuestVM).SwitchName

    ## Parses through all of the host NIC's to find the matching NIC of the VM. Validates connection status then returns true if status is connected.
    Foreach ($Connection in $HostNic)
    {
        IF($Connection -like "*" + $GuestVMNic + "*" -and $Connection -notlike "*disconnected*")
        {
            New-LogEntry -LogValue "Connection to $VMName VM was successful." -Component "SharedScriptLib.ps1:Test-VMConnection"
            Return $true
        }
    }

    ## Unable to find a matching NIC or the connection was disconnected. Returns false.
    New-LogEntry -LogValue "Connection to $VMName VM failed." -Component "SharedScriptLib.ps1:Test-VMConnection" -Severity 3
    Return $false
}

Function Test-VMMSIXPackagingTool ($VMName)
{

}

Function Test-RMConnection ($RemoteMachineName)
{
    ## Sends a network ping request to the Remote Machine
    $PingResult = Test-Connection $RemoteMachineName -ErrorAction SilentlyContinue

    ## Validates if a response of any kind has been returned.
    If ($($PingResult.Count) -gt 0 )
    {
        ## If all Pings returned successfully, consider this a 100% good VM to work with.
        If ($($PingResult.Count) -eq 4)
        {
            New-LogEntry -LogValue "Connection to $RemoteMachineName Successful." -Component "SharedScriptLib.ps1:Test-RMConnection"
            Return $true
        }

        ## If some Pings were lost, still good, just potential network issue.
        New-LogEntry -LogValue "Connection to $RemoteMachineName successful, Some packets were dropped." -Component "SharedScriptLib.ps1:Test-RMConnection" -Severity 2
        Return $true
    }

    ## Returns false, no network response was available.
    New-LogEntry -LogValue "Unable to Connect to $RemoteMachineName`r    - Ensure Firewall has been configured to allow remote connections and PING requests"  -Component "SharedScriptLib.ps1:Test-RMConnection" -Severity 3
    Return $false
}

Function Test-RMPSRemoting ($RemoteMachineName)
{

}

Function Test-RMWinRM ($RemoteMachineName, $HostMachineName)
{

}

Function Test-HostHyperV ()
{

}

Function Test-HostMSIXPackagingTool ()
{

}

Function Test-HostWinRM ($RemoteMachineName)
{

    $HostMachineObject = (Get-WmiObject -ComputerName $RemoteMachineName -Query "Win32_ComputerSystem")
    $RemoteMachineObject = (Get-WmiObject -ComputerName $RemoteMachineName -Query "Win32_ComputerSystem")


}