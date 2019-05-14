function SignAndDeploy($msixFolder)
{
    Get-AppxPackage *YourApp* | Remove-AppxPackage
    Get-AppxPackage *YourApp2* | Remove-AppxPackage
    Get-AppxPackage *YourApp3* | Remove-AppxPackage

    Get-ChildItem $msixFolder | foreach-object {
        $pfxFilePath = "\\Path\To\Your\Certificate\YourCert.pfx"
        $msixPath = $_.FullName
        Write-Host "Running: signtool.exe sign /f $global:common_pfxLocation /fd SHA256 $path"
        & "Path\To\signtool.exe" sign /f $pfxFilePath /fd SHA256 $msixPath
        Add-AppxPackage $msixPath
    }
}