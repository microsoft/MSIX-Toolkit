# ModifyPackagePublisher

Use this script to repackage and sign a MSIX package after modifying the publisher info in the manifest to match
that of the cert that will be used to sign the package.

> [!NOTE]
> The script should be run from within the folder context. All the required dependencies are present within
the zip file. You will need to modify the relative paths to packageeditor and signtool if the script needs to be run from a different context.

> [!NOTE]
> The script was verified on the RS5_release insider builds.

## SYNTAX

```ps1
modify-package-publisher.ps1 [-directory] <String> [-certPath] <String> [[-pfxPath] <String>]
    [[-password] <String>] [-forceContinue] [<CommonParameters>]
```

## DESCRIPTION

modify-package-publisher.ps1 is a PowerShell script. It takes a directory containing MSIX packages along with a cert file as
required inputs. The script retrives the publisher info from the cert and modifies the manifest file inside the
MSIX package to reflect the publisher retrieved from the cert file. Then, the script repacks the MSIX package with
the new manifest.


## PARAMETERS
-directory <String>

    Required?                    true
    Position?                    1
    Default value
    Accept pipeline input?       false
    Accept wildcard characters?  false

-certPath <String>

    Required?                    true
    Position?                    2
    Default value
    Accept pipeline input?       false
    Accept wildcard characters?  false

-pfxPath <String>

    Required?                    false
    Position?                    3
    Default value
    Accept pipeline input?       false
    Accept wildcard characters?  false

-password <String>

    Required?                    false
    Position?                    4
    Default value
    Accept pipeline input?       false
    Accept wildcard characters?  false

-forceContinue [<SwitchParameter>]

    Required?                    false
    Position?                    named
    Default value                False
    Accept pipeline input?       false
    Accept wildcard characters?  false

## Usage
``` PowerShell
-------------------------- EXAMPLE 1 --------------------------

PS C:\>.\modify-package-publisher.ps1 -directory "c:\msixpackages\" -certPath "C:\cert\mycert.cer"


-------------------------- EXAMPLE 2 --------------------------

PS C:\>.\modify-package-publisher.ps1 -directory "c:\msixpackages\" -certPath "C:\cert\mycert.cer" -pfxPath
"C:\cert\CertKey.pfx"


-------------------------- EXAMPLE 3 --------------------------

PS C:\>.\modify-package-publisher.ps1 -directory "c:\msixpackages\" -certPath "C:\cert\mycert.cer" -pfxPath
"C:\cert\CertKey.pfx" -password "aaabbbccc"


-------------------------- EXAMPLE 4 --------------------------

PS C:\>.\modify-package-publisher.ps1 -directory "c:\msixpackages\" -certPath "C:\cert\mycert.cer" -pfxPath
"C:\cert\CertKey.pfx" -forceContinue
  ```
