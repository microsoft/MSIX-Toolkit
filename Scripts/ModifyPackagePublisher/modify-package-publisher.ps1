<#

.SYNOPSIS

    This script will update the publisher in the app manifest and resign the package based on a new certificate.  The script is currently limited to msix packages only and not msixbundles. 



    [NOTE]: The script should be run from within the folder context. All the required dependencies are present within the zip file. You will need to modify the relative paths to

    packageeditor and signtool if the script needs to be run from a different context. 



    [NOTE]: The script was verified on the Windows 10 1809.



.DESCRIPTION

    modify-package-publisher.ps1 is a PowerShell script. It takes a directory containing MSIX packages along with a cert file as required inputs. The script retrives the publisher info from the cert and modifies the manifest file inside the MSIX package to reflect the publisher retrieved from the cert file. Then, the script repacks the MSIX package with the new manifest. 



.PARAMETER <-directory>

    [Required] This parameter takes the directory containing the MSIX packages. 



.PARAMETER <-certPath>

   [Required] This parameter takes the path to the cert file that will be used to get the publisher/Subject info. 



.PARAMETER <-redist>

   [Required] This parameter takes the directory of the redist for signtool and PackageEditor 



.PARAMETER <-pfxPath>

   This parameter takes the path to the pfx file that will be use to sign the MSIX package. This is an optional parameter.



.PARAMETER <-password>

   This parameter is the password to the .pfx file. This is only required if the specified .pfx file is protected via password.



.PARAMETER <-forceContinue>

   This is an optional parameter which default to false. If the parameter is specified, the script will ignore the failed operations and continue with the next msix package if available. 



.EXAMPLE

   .\modify-package-publisher.ps1 -directory "C:\MSIX" -redist "C:\MSIX-Toolkit\Redist" -certPath "C:\cert\mycert.cer"



.EXAMPLE

   .\modify-package-publisher.ps1 -directory "C:\MSIX" -redist "C:\MSIX-Toolkit\Redist" -certPath "C:\cert\mycert.cer" -pfxPath "C:\cert\CertKey.pfx"



.EXAMPLE 

   .\modify-package-publisher.ps1 -directory "C:\MSIX" -redist "C:\MSIX-Toolkit\Redist" -certPath "C:\cert\mycert.cer" -pfxPath "C:\cert\CertKey.pfx" -password "aaabbbccc"



.EXAMPLE

   .\modify-package-publisher.ps1 -directory "C:\MSIX" -redist "C:\MSIX-Toolkit\Redist" -certPath "C:\cert\mycert.cer" -pfxPath "C:\cert\CertKey.pfx" -forceContinue

#>



#Input Arguments for the script

param(

   [Parameter(Mandatory=$true)][string]$directory,

   [Parameter(Mandatory=$true)][string]$certPath,

   [Parameter(Mandatory=$true)][string]$redist,

   [string]$pfxPath,

   [string]$password,

   [switch]$forceContinue=$false

)





#relative paths to the tools used to repackage and sign

$packageEditorExe = $redist + "\PackageEditor.exe"

$signToolExe = $redist + "\signtool.exe"



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

        #                & "SDK_Signing_Tools\signtool.exe" sign /f ".\CertKey.pfx" /fd SHA256 "C:\msix\MyEmployees.msix"

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

        $signToolCmd = ("& `"" + $signToolExe + "`" sign /f `"" + $pfxPath + "`" /p " + $password + " /fd SHA256 `"" + $path + "`"" )

        #                & "SDK_Signing_Tools\signtool.exe" sign /f ".\CertKey.pfx" /fd SHA256 "C:\msix\MyEmployees.msix" /p "My!Pa$$word"



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
# SIG # Begin signature block
# MIIjogYJKoZIhvcNAQcCoIIjkzCCI48CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCNlMcGBDYD+jnY
# t8l400mAK7FTNLYBgAzxfnT+hfB7rKCCDYEwggX/MIID56ADAgECAhMzAAABUZ6N
# j0Bxow5BAAAAAAFRMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMTkwNTAyMjEzNzQ2WhcNMjAwNTAyMjEzNzQ2WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQCVWsaGaUcdNB7xVcNmdfZiVBhYFGcn8KMqxgNIvOZWNH9JYQLuhHhmJ5RWISy1
# oey3zTuxqLbkHAdmbeU8NFMo49Pv71MgIS9IG/EtqwOH7upan+lIq6NOcw5fO6Os
# +12R0Q28MzGn+3y7F2mKDnopVu0sEufy453gxz16M8bAw4+QXuv7+fR9WzRJ2CpU
# 62wQKYiFQMfew6Vh5fuPoXloN3k6+Qlz7zgcT4YRmxzx7jMVpP/uvK6sZcBxQ3Wg
# B/WkyXHgxaY19IAzLq2QiPiX2YryiR5EsYBq35BP7U15DlZtpSs2wIYTkkDBxhPJ
# IDJgowZu5GyhHdqrst3OjkSRAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUV4Iarkq57esagu6FUBb270Zijc8w
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDU0MTM1MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAWg+A
# rS4Anq7KrogslIQnoMHSXUPr/RqOIhJX+32ObuY3MFvdlRElbSsSJxrRy/OCCZdS
# se+f2AqQ+F/2aYwBDmUQbeMB8n0pYLZnOPifqe78RBH2fVZsvXxyfizbHubWWoUf
# NW/FJlZlLXwJmF3BoL8E2p09K3hagwz/otcKtQ1+Q4+DaOYXWleqJrJUsnHs9UiL
# crVF0leL/Q1V5bshob2OTlZq0qzSdrMDLWdhyrUOxnZ+ojZ7UdTY4VnCuogbZ9Zs
# 9syJbg7ZUS9SVgYkowRsWv5jV4lbqTD+tG4FzhOwcRQwdb6A8zp2Nnd+s7VdCuYF
# sGgI41ucD8oxVfcAMjF9YX5N2s4mltkqnUe3/htVrnxKKDAwSYliaux2L7gKw+bD
# 1kEZ/5ozLRnJ3jjDkomTrPctokY/KaZ1qub0NUnmOKH+3xUK/plWJK8BOQYuU7gK
# YH7Yy9WSKNlP7pKj6i417+3Na/frInjnBkKRCJ/eYTvBH+s5guezpfQWtU4bNo/j
# 8Qw2vpTQ9w7flhH78Rmwd319+YTmhv7TcxDbWlyteaj4RK2wk3pY1oSz2JPE5PNu
# Nmd9Gmf6oePZgy7Ii9JLLq8SnULV7b+IP0UXRY9q+GdRjM2AEX6msZvvPCIoG0aY
# HQu9wZsKEK2jqvWi8/xdeeeSI9FN6K1w4oVQM4Mwggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIVdzCCFXMCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAVGejY9AcaMOQQAAAAABUTAN
# BglghkgBZQMEAgEFAKCByjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgPq8y0tL9
# j1QEgdQTheqy5Tm02zVuM9BGb4EfMs+tjRcwXgYKKwYBBAGCNwIBDDFQME6gMoAw
# AG0AbwBkAGkAZgB5ACAAcABhAGMAawBhAGcAZQAgAHAAdQBiAGwAaQBzAGgAZQBy
# oRiAFmh0dHBzOi8vbWljcm9zb2Z0LmNvbSAwDQYJKoZIhvcNAQEBBQAEggEAjbo+
# 8HVKON2ijLUXI0r2EZUhGAQwej/cVCUVnTf+gkVUlHhsB7+T9MGw5hqGacEB7LBK
# XS/JiM6PRLIpmH3EABpYtiR68JFNAYd38Acv0QrozZuk3gfAFFS4XT6MpSef8Ae0
# noSnxycw2CmKM81GmaiOmXeBHJ+WSJs+5wOnydEp+NAWi1aELw+alS082Av84A0E
# JXtC2ROAdz6NqJt6hlmRsN1X87wRDzW7u/CTzkROS9rgiBbe7YNkOdjCg5daInjs
# Y82JtE6uVMEKOEifjj++PlYL7FjdRZu4jLGcsRdWqGFHARhOrqbu5KQ0qxsZvki+
# YqgcxUnbvkoK4vT5iKGCEuUwghLhBgorBgEEAYI3AwMBMYIS0TCCEs0GCSqGSIb3
# DQEHAqCCEr4wghK6AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFRBgsqhkiG9w0BCRAB
# BKCCAUAEggE8MIIBOAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFlAwQCAQUABCDR
# lxBh5s5kceEFsMFApyL5+OshCPTl/cHVjiRPyHnx3AIGXMtKXg+cGBMyMDE5MDcw
# OTIzMDM0MC4zMDVaMASAAgH0oIHQpIHNMIHKMQswCQYDVQQGEwJVUzELMAkGA1UE
# CBMCV0ExEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3BlcmF0aW9ucyBM
# aW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpEMDgyLTRCRkQtRUVCQTEl
# MCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgc2VydmljZaCCDjwwggTxMIID
# 2aADAgECAhMzAAAA4hg4e2bp6sHYAAAAAADiMA0GCSqGSIb3DQEBCwUAMHwxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTE4MDgyMzIwMjcwM1oXDTE5MTEy
# MzIwMjcwM1owgcoxCzAJBgNVBAYTAlVTMQswCQYDVQQIEwJXQTEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQL
# EyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsT
# HVRoYWxlcyBUU1MgRVNOOkQwODItNEJGRC1FRUJBMSUwIwYDVQQDExxNaWNyb3Nv
# ZnQgVGltZS1TdGFtcCBzZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
# CgKCAQEAqKsDvYUXc0ItbmZ8s78PQRnlhyzTSiIxKKyxcsHpYX0Y10/vxDMXADKn
# Fb/6plJzOpodsMfyGVvGTN/cOJiAB2lCOcaQu6PAq1ZJo/b3+VV/uMWofL2/p4f4
# t06LQu+2s9FbfgzIK+nFnI5bgfWHc+TEIEvlFrbWwOqBxUvWZ7SizDxBNRFeYjgv
# J4t1MfcJwjYCA0NdOOwUF/dCw74ljIA5hatNwufLBU3oOuKCaCsMmTnD7BHhWsd+
# XZP09Fltn5QO3XfDDIH13ohRG7NXyUewBV8Xy31LRoZU+aRDdzbBo6EemynpUQz5
# PkPY+HzElfWvzbPrtZGWYZw4/Y1YLQIDAQABo4IBGzCCARcwHQYDVR0OBBYEFIk+
# kPoGw/an5ysMkvbfa+gS0vF7MB8GA1UdIwQYMBaAFNVjOlyKMZDzQ3t8RhvFM2ha
# hW1VMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9w
# a2kvY3JsL3Byb2R1Y3RzL01pY1RpbVN0YVBDQV8yMDEwLTA3LTAxLmNybDBaBggr
# BgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNv
# bS9wa2kvY2VydHMvTWljVGltU3RhUENBXzIwMTAtMDctMDEuY3J0MAwGA1UdEwEB
# /wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZIhvcNAQELBQADggEBABFA
# e7shJ4G4lIcq4NEjTjvThwfQHsFjN4QisPXlrC+IxFxgh8g4em8bNk5ZCA/YebRG
# vuS9NS7VWtJJpDuLWA9Z2GoybDlYGdJLlvF4yGHH1SwBJ4Tzi9S7zY15lqkZKMff
# xgBvhZP5O2JORygjn2sD4JMKrXTy20jFV9lyveJ3vo4RMgfQe+GWfE45aPAbLi6X
# plrlGhMsb+ijausaZWLcXCs1YZ7NgsE4O4SyPMbfqUJG0EoLZkAd9s7PnC2RQduq
# Hv2ZQqhyM/iverF/lM3zvJ/qDW5PH4nyl2cCLmIe35m1qeBaqdVMTw+ghERaEFWU
# YV9B2QQtTHY6v3RoCpYwggZxMIIEWaADAgECAgphCYEqAAAAAAACMA0GCSqGSIb3
# DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIw
# MAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAx
# MDAeFw0xMDA3MDEyMTM2NTVaFw0yNTA3MDEyMTQ2NTVaMHwxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQSAyMDEwMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
# qR0NvHcRijog7PwTl/X6f2mUa3RUENWlCgCChfvtfGhLLF/Fw+Vhwna3PmYrW/AV
# UycEMR9BGxqVHc4JE458YTBZsTBED/FgiIRUQwzXTbg4CLNC3ZOs1nMwVyaCo0UN
# 0Or1R4HNvyRgMlhgRvJYR4YyhB50YWeRX4FUsc+TTJLBxKZd0WETbijGGvmGgLvf
# YfxGwScdJGcSchohiq9LZIlQYrFd/XcfPfBXday9ikJNQFHRD5wGPmd/9WbAA5ZE
# fu/QS/1u5ZrKsajyeioKMfDaTgaRtogINeh4HLDpmc085y9Euqf03GS9pAHBIAmT
# eM38vMDJRF1eFpwBBU8iTQIDAQABo4IB5jCCAeIwEAYJKwYBBAGCNxUBBAMCAQAw
# HQYDVR0OBBYEFNVjOlyKMZDzQ3t8RhvFM2hahW1VMBkGCSsGAQQBgjcUAgQMHgoA
# UwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQY
# MBaAFNX2VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6
# Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1
# dF8yMDEwLTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0
# dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0XzIw
# MTAtMDYtMjMuY3J0MIGgBgNVHSABAf8EgZUwgZIwgY8GCSsGAQQBgjcuAzCBgTA9
# BggrBgEFBQcCARYxaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL1BLSS9kb2NzL0NQ
# Uy9kZWZhdWx0Lmh0bTBABggrBgEFBQcCAjA0HjIgHQBMAGUAZwBhAGwAXwBQAG8A
# bABpAGMAeQBfAFMAdABhAHQAZQBtAGUAbgB0AC4gHTANBgkqhkiG9w0BAQsFAAOC
# AgEAB+aIUQ3ixuCYP4FxAz2do6Ehb7Prpsz1Mb7PBeKp/vpXbRkws8LFZslq3/Xn
# 8Hi9x6ieJeP5vO1rVFcIK1GCRBL7uVOMzPRgEop2zEBAQZvcXBf/XPleFzWYJFZL
# dO9CEMivv3/Gf/I3fVo/HPKZeUqRUgCvOA8X9S95gWXZqbVr5MfO9sp6AG9LMEQk
# IjzP7QOllo9ZKby2/QThcJ8ySif9Va8v/rbljjO7Yl+a21dA6fHOmWaQjP9qYn/d
# xUoLkSbiOewZSnFjnXshbcOco6I8+n99lmqQeKZt0uGc+R38ONiU9MalCpaGpL2e
# Gq4EQoO4tYCbIjggtSXlZOz39L9+Y1klD3ouOVd2onGqBooPiRa6YacRy5rYDkea
# gMXQzafQ732D8OE7cQnfXXSYIghh2rBQHm+98eEA3+cxB6STOvdlR3jo+KhIq/fe
# cn5ha293qYHLpwmsObvsxsvYgrRyzR30uIUBHoD7G4kqVDmyW9rIDVWZeodzOwjm
# mC3qjeAzLhIp9cAvVCch98isTtoouLGp25ayp0Kiyc8ZQU3ghvkqmqMRZjDTu3Qy
# S99je/WZii8bxyGvWbWu3EQ8l1Bx16HSxVXjad5XwdHeMMD9zOZN+w2/XU/pnR4Z
# OC+8z1gFLu8NoFA12u8JJxzVs341Hgi62jbb01+P3nSISRKhggLOMIICNwIBATCB
# +KGB0KSBzTCByjELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAldBMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsT
# JE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlvbnMgTGltaXRlZDEmMCQGA1UECxMd
# VGhhbGVzIFRTUyBFU046RDA4Mi00QkZELUVFQkExJTAjBgNVBAMTHE1pY3Jvc29m
# dCBUaW1lLVN0YW1wIHNlcnZpY2WiIwoBATAHBgUrDgMCGgMVAHJAJSF4Q569oj1l
# z/dAauRfjaILoIGDMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAw
# DQYJKoZIhvcNAQEFBQACBQDgz23wMCIYDzIwMTkwNzEwMDM0ODAwWhgPMjAxOTA3
# MTEwMzQ4MDBaMHcwPQYKKwYBBAGEWQoEATEvMC0wCgIFAODPbfACAQAwCgIBAAIC
# H70CAf8wBwIBAAICEzowCgIFAODQv3ACAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYK
# KwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQUF
# AAOBgQBCiuf0+wzlngR7kQTEtyAOb2RQkHwre2PXXeaqtgPoPIspZ8UdbqeUCFhl
# B1GRW3vO3KTxZ6Zz1+lkNHeC5iE5P9spi0tthYapNRSGgda62uq0amHEA4VzmpY8
# PEvs+NYKG5gu/gruhUHnckH9WqsHbE4Zx78YPVDAUCaSLfaCsjGCAw0wggMJAgEB
# MIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNV
# BAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAA4hg4e2bp6sHY
# AAAAAADiMA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcN
# AQkQAQQwLwYJKoZIhvcNAQkEMSIEIE9eH/L/gzJ01ptpaSAisG6jK63Mi3fqQA3t
# SI3KhhxEMIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQg3wGklKZAIa5tbBVr
# i1b5oy96gcxf+cOdU3x+IM4yysswgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFt
# cCBQQ0EgMjAxMAITMwAAAOIYOHtm6erB2AAAAAAA4jAiBCBVVoFPfPMdZOSoD3Ou
# jyx4GRwqYK2On5IjtK6NtysVEDANBgkqhkiG9w0BAQsFAASCAQBrOGMOuNeIHU3x
# cvjDCFETHiEYN9oDrQdKwoeLlLAcRvuuw0wzJHVDPEJfw/JQoBs7YX2E6rUxfeY4
# YTGIa1JvnFAqM8Th3PKE/bFl8x3EUX3jVu0fc2DVwTLwETeTwvq6kr4pOKCc8Eu1
# qYh8hqE6VKjxbtPrmzLvzO0Dbg82aaml13VQ3jPrIfgpIjS7QLezzlzP7vEhpM4S
# v3lugpv1m/3tWVqL/tjExX9HSllb4/VuD3pkZTlGvWh+I+sgRxL0VYcNgrkuCxY1
# 8u9/VwfyY1nyv1ZK/bsbHD3akAp0K67ahaPLLso3Q5WRShTPTRo3WGTuoK0kwj9/
# 0fVwGm5J
# SIG # End signature block
