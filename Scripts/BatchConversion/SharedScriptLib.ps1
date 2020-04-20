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
    $('<![LOG['+$LogValue+']LOG]!><time="'+$Time+'" date="'+$Date+'" component="'+$component+'" context="Empty" type="'+$severity+'" thread="Empty" file="'+"Empty"+'">') | out-file -FilePath $($Path+"\MSIXConnect.log") -Append -NoClobber -encoding default

    IF($WriteHost)
    {
        Write-Host $("   " + $LogValue) -ForegroundColor $(switch ($Severity) {1 {"White"} 2 {"Yellow"} 3 {"Red"}})
    }
}