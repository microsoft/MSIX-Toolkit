. $PSScriptRoot\SharedScriptLib.ps1

function Set-MSIXSignApp($msixFolder, $CertificatePath, $CertificatePassword, $Encryption="SHA256")
{
    ## Goes up two folders in the path.
    $SignToolPath = $PSScriptRoot
    $SignToolPath = $SignToolPath.Substring(0, $($SignToolPath.LastIndexOf("\")))
    $SignToolPath = $SignToolPath.Substring(0, $($SignToolPath.LastIndexOf("\")))

    ## Detects the OS Architecture and sets the variable path approrpriately.
    Switch ($(Get-WmiObject -Query "Select OSArchitecture from Win32_operatingsystem").OSArchitecture)
    {
        "64-bit" {$SignTool   = ".\Redist.x64\signtool.exe"}
        "32-bit" {$SignTool   = ".\Redist.x86\signtool.exe"}
    }

    ##Sets the location to root of the MSIX Toolkit
    $IntialLocation = Get-Location
    Set-Location -Path $SignToolPath

    ## Parses through all files in the identified MSIX Folder to sign all files.
#    Get-ChildItem $msixFolder | foreach-object 
    ForEach ($File in $(Get-ChildItem $msixFolder))
    {
        $msixPath = $File.FullName

        ##Validates that the file to be signed is an MSIX App.
        IF ($([System.IO.Path]::GetExtension($msixPath)) -eq ".msix")
        {
            $signToolCmd = "$SignTool sign /f ""$CertificatePath"" /p $CertificatePassword /fd $Encryption ""$msixPath"""
            New-LogEntry -LogValue $signToolCmd -Component "SharedScriptLib:Set-MSIXSignApp"

            ## Commits the signing of each MSIX App using the signing tool.
            Invoke-Expression $signToolCmd
        }   
        else 
        {
            New-LogEntry -LogValue "The following is not an MSIX packaged application: $($File.Name)" -Component "sign_deploy_run:Set-MSIXSignApp" -Severity 2
        }
    }

    ## Returns the current path to the original location.
    Set-Location -Path $IntialLocation
}