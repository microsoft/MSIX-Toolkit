# MSIX Toolkit - Scripts

This folder is a collection of PowerShell and bash scripts to assist in making the process of packaging, signing, managing and distributing MSIX packages. 

| Scripts | Description | Download |
|---|---|---|
| [Batch Conversion](BatchConversion/README.md) | This script allows users to convert a set of desktop applications to MSIX packages. | [Batch-Conversion.zip](https://github.com/microsoft/MSIX-Toolkit/releases/download/v1.0/Batch-Conversion.zip)
| [Modify Package Publisher](ModifyPackagePublisher/readme.md) | This script takes an app package and certificate(pfx) file to resign the package with provide cert.| [Modify-Package-Publisher.ps1](https://github.com/microsoft/MSIX-Toolkit/releases/download/v1.1/modify-package-publisher.ps1)|

## How to contribute

This is a open source project. We welcome external contributions. For the best experience for users that want to contribute or consume the scripts and other tools available in this repo, the following are a few guidelines we will enforce on this GitHub project. 

1. This repo will only include scripts that help users in working with MSIX packages 
2. Every script will need to be accompanied with a readme.md file that will detail the requirements, use cases and instructions on how to use it.
3. Scripts will be delimited by folders. All the required metadata files like config files(.xml, .ini, .txt etc) will be placed in the folder along with the readme file.
