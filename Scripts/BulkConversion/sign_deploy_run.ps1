. $PSScriptRoot\SharedScriptLib.ps1

function Set-MSIXSignApp($conversionsParameters, $WorkingDirectory, $CertificatePath, $CertificatePassword, $Encryption="SHA256")
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
    New-LogEntry -LogValue "Identified path to the SignTool:  $($SignToolPath)$($SignTool.Substring(1,$($($SignTool.Length)-1)))" -Component "sign_deploy_run.ps1:Set-MSIXSignApp" -Path $WorkingDirectory

    ##Sets the location to root of the MSIX Toolkit
    $IntialLocation = Get-Location
    Set-Location -Path $SignToolPath

    ForEach ($ConvertParam in $conversionsParameters)
    {
        IF($ConvertParam.SavePackagePath)
            {$msixFolder = [System.IO.Path]::Combine($($ConvertParam.SavePackagePath), "msix") }
        Else
            {$msixFolder = [System.IO.Path]::Combine($WorkingDirectory, "msix") }

        New-LogEntry -LogValue "Searching the ""$msixFolder"" for ""$($ConvertParam.PackageName)_$($ConvertParam.PackageVersion)""" -Component "sign_deploy_run.ps1:Set-MSIXSignApp" -Path $WorkingDirectory

        ForEach ($File in $(Get-ChildItem -Recurse $msixFolder))
        {
            $msixPath = $File.FullName

            ##Validates that the file to be signed is an MSIX App.
            IF ($([System.IO.Path]::GetExtension($msixPath)) -eq ".msix" -and $($File.Name).StartsWith("$($ConvertParam.PackageName)_$($ConvertParam.PackageVersion)"))
            {
                $signToolCmd = "$SignTool sign /f ""$CertificatePath"" /p $CertificatePassword /fd $Encryption ""$msixPath"""
                New-LogEntry -LogValue $signToolCmd -Component "SharedScriptLib:Set-MSIXSignApp" -Path $WorkingDirectory

                ## Commits the signing of each MSIX App using the signing tool.
                Invoke-Expression $signToolCmd
            }   
        }
    }

    ## Returns the current path to the original location.
    Set-Location -Path $IntialLocation
}