function Set-MSIXSignApp($msixFolder, $CertificatePath, $CertificatePassword)
{
    ## Goes up two folders in the path.
    $SignToolPath = $PSScriptRoot
    $SignToolPath = $SignToolPath.Substring(0, $($SignToolPath.LastIndexOf("\")))
    $SignToolPath = $SignToolPath.Substring(0, $($SignToolPath.LastIndexOf("\")))

    ##Sets the location to root of the MSIX Toolkit
    $IntialLocation = Get-Location
    Set-Location -Path $SignToolPath

    ## Parses through all files in the identified MSIX Folder to sign all files.
    Get-ChildItem $msixFolder | foreach-object {
        $msixPath       = $_.FullName
        $SignToolPath   = ".\Redist.x64\signtool.exe"
        $Encryption     = "SHA256"
        
        $signToolCmd = "$SignToolPath sign /f ""$CertificatePath"" /p $CertificatePassword /fd $Encryption ""$msixPath"""
        Write-Host $signToolCmd

        ## Commits the signing of each MSIX App using the signing tool
        Invoke-Expression $signToolCmd

        ## Installs the MSIX App onto the computer.
        Add-AppxPackage $msixPath

    }

    ## Returns the current path to the original location
    Set-Location -Path $IntialLocation
}