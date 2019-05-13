<#
.SYNOPSIS
    Use this script to repackage and sign a MSIX package after modifying the publisher info in the manifest to match that of the cert that will be used to sign the package. 

    [NOTE]: The script should be run from within the folder context. All the required dependencies are present within the zip file. You will need to modify the relative paths to
    packageeditor and signtool if the script needs to be run from a different context. 

    [NOTE]: The script was verified on the Windows 10 1809.

.DESCRIPTION
    modify-package-publisher.ps1 is a PowerShell script. It takes a directory containing MSIX packages along with a cert file as required inputs. The script retrives the publisher info from the cert and modifies the manifest file inside the MSIX package to reflect the publisher retrieved from the cert file. Then, the script repacks the MSIX package with the new manifest. 

.PARAMETER <-directory>
    This parameter takes the directoryectory containing the MSIX packages. 

.PARAMETER <-certPath>
   This parameter takes the path to the cert file that will be used to get the publisher/Subject info. 

.PARAMETER <-pfxPath>
   This parameter takes the path to the pfx file that will be use to sign the MSIX package. This is an optional parameter.

.PARAMETER <-password>
   This parameter is the password to the .pfx file. This is only required if the specified .pfx file is protected via password.

.PARAMETER <-forceContinue>
   This is an optional parameter which default to false. If the parameter is specified, the script will ignore the failed operations and continue with the next msix package if available. 

.EXAMPLE
   .\modify-package-publisher.ps1 -directory "c:\msixpackages\" -certPath "C:\cert\mycert.cer"

.EXAMPLE
   .\modify-package-publisher.ps1 -directory "c:\msixpackages\" -certPath "C:\cert\mycert.cer" -pfxPath "C:\cert\CertKey.pfx"

.EXAMPLE 
   .\modify-package-publisher.ps1 -directory "c:\msixpackages\" -certPath "C:\cert\mycert.cer" -pfxPath "C:\cert\CertKey.pfx" -password "aaabbbccc"

.EXAMPLE
   .\modify-package-publisher.ps1 -directory "c:\msixpackages\" -certPath "C:\cert\mycert.cer" -pfxPath "C:\cert\CertKey.pfx" -forceContinue
#>

#Input Arguments for the script
param(
   [Parameter(Mandatory=$true)][string]$directory,
   [Parameter(Mandatory=$true)][string]$certPath,
   [string]$pfxPath,
   [string]$password,
   [switch]$forceContinue=$false
)


#relative paths to the tools used to repackage and sign
$packageEditorExe = "packageeditor\PackageEditor.exe"
$signToolExe = "SDK_Signing_Tools\signtool.exe"

#retreive publisher info from the .cer file
function GetCertPublisher
{

    $cert = New-Object -TypeName "System.Security.Cryptography.X509Certificates.X509Certificate"
    $cert.Import($certPath)
    $certPublisher = $cert.Subject
    $certPublisher

}

#Modify the publisher info in appxmanifest.xml file and repack the msix package
function ModifyPackagePublisher
{
    $msixFiles = Get-ChildItem $directory -Recurse -File -Filter *.msix

    foreach  ($item in $msixFiles)
    {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
        $filesToExtract = @("appxmanifest.xml";)
        $zipPath = $item.FullName
        
        try
        {
            $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
        }
        catch
        {
            Write-Host "Failed to open the MSIX package: " $zipPath
            if ($forceContinue)
            {
                Write-Host "Proceeding with next MSIX package if available."
                continue
            }
            else
            {
                Exit 1
            }
        }

        foreach($entry in $zip.Entries){
            if ($filesToExtract -contains $entry.FullName)
            {
                $dst = [io.path]::combine($env:temp, $entry.FullName)

                if (Test-Path -Path $dst) 
                {
                    Remove-Item -Path $dst 
                }

                Write-Verbose $("Extract ==> {0}" -f @($dst))
                Write-Host "Extracting package manifest"
                try
                {
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dst)
                }
                catch
                {
                    Write-Host "Failed to extract the file to the temp location- source: "  $entry  " destination: "  $dst 
                    if ($forceContinue)
                    {
                        Write-Host "Proceeding with next MSIX package if available."
                        continue
                    }
                    else
                    {
                        Exit 1
                    }
                }
            }
        }
        
        $zip.Dispose()

        $manifestPath = ([System.IO.Path]::Combine($env:temp, "AppxManifest.xml"))
        
        if ((Test-Path $manifestPath) -eq $false)
        {
            Write-Host "Cannot find AppxManifest.xml file. Check if the provided package has a manifest file."
            if ($forceContinue)
            {
                Write-Host "Proceeding with next MSIX package if available."
                continue
            }
            else
            {
                Exit 1
            }
        }
                    
        Write-Host "Modifying Package Publisher in the extracted manifest"
        $packagePublisherElement = Select-Xml -path $manifestPath -XPath "//*[local-name()='Identity']/@Publisher"
        $packagePublisherElement.Node.Value = GetCertPublisher
        Write-Host "New publisher: $($packagePublisherElement.Node.Value)"
        $packagePublisherElement.Node.OwnerDocument.Save($manifestPath)

        $packageEditorCmd = ("& `"" + $packageEditorExe + "`" updateManifest -p `"" + $($item.FullName) + "`" -m `"" + $manifestPath + "`" -l")
      
        Write-Host "Re-package $($item.FullName) with manifest $manifestPath"
        Invoke-Expression $packageEditorCmd

        if ($LASTEXITCODE) 
        { 
            if (!$forceContinue)
            {
                Exit 1 
            }
            
        }
        Write-Host "Modified MSIX Package: " $item.FullName
        
        #Cleaning up the remaining temp Manifest file
        Remove-Item -Path $manifestPath

        if (![string]::IsNullOrEmpty($pfxPath))
        {
            Write-Host "Signing Package"
            SignPackage ($($item.FullName))
        }
        Write-Host "--------------------------------`n--------------------------------`n--------------------------------"
    }

}

#Sign the package specified in the path with the provided pfx file
function SignPackage ([string]$path)
{
    if ([string]::IsNullOrEmpty($password))
    {
        $signToolCmd = ("& `"" + $signToolExe + "`" sign /f `"" + $pfxPath + "`" /fd SHA256 `"" + $path + "`"" )
        #                & "SDK_Signing_Tools\signtool.exe" sign /f ".\CertKey.pfx" /fd SHA256 "C:\Users\cdon\Desktop\msixscript\aps\New folder\AppInstaller - Copy.msix"
        Write-Host $signToolCmd
        Invoke-Expression $signToolCmd
        if ($LASTEXITCODE) 
        { 
            if (!$forceContinue)
            {
                Exit 1 
            }
        }
    }
    else
    {
        $signToolCmd = ("& `"" + $signToolExe + "`" sign /f `"" + $pfxPath + "`" /fd SHA256 `"" + $path + "`"" + "`" /p `"" + $password + "`"")
        #                & "SDK_Signing_Tools\signtool.exe" sign /f ".\CertKey.pfx" /fd SHA256 "C:\Users\cdon\Desktop\msixscript\aps\New folder\AppInstaller - Copy.msix"" /p "aaabbbaa"

        Write-Host $signToolCmd
        Invoke-Expression $signToolCmd
        if ($LASTEXITCODE) 
        { 
            if (!$forceContinue)
            {
                Exit 1 
            }
        }
    }
    
}

#Main Function
ModifyPackagePublisher
