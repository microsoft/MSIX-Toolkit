# MSIX Toolkit 

# Welcome to the MSIX-Toolkit wiki!

MSIX Toolkit is a combination of tools and scripts focused on assisting IT pros and developers to make their app package modernization journey smoother. The toolkit will be open sourced on GitHub to allow customers and enthusiasts to contribute directly and provide suggestions and feedback on the content that is available. 
The goal of the toolkit is to make it a gathering place for customers working with MSIX packages to come and find the help and assistance they need to build, manage, troubleshoot them. 

## Principles:
1.	MSIX toolkit is a community led space where customers can freely contribute source code along with binaries and executables 
2.	Users can’t post artifacts that don’t have a corresponding source code unless they are redistributables (discussed in more detail later in the doc). 
3.	Till enough community involvement, a Microsoft employee will oversee making the decision to accept a pull request into the GitHub master branch.
4.	All contributed source code will need to include a readme file with detailed instructions on the setup and how to build the source code

## Posting source code:
Source code in the master branch will need to adhere to the following guidelines:
-	The source code needs to compile  
-	The source code needs to compile into consumable binaries or executables with an entrypoint 
-	The code quality will need to adhere to common coding standards
o	Microsoft curator will provide the feedback to contributors on any pull request on the changes that are required to accept their contribution 
Posting consumable binaries or executables:
-	Contributors are encouraged to also add the built binaries, so that users can directly consume them as compared to requiring them to compile the source code. 
-	By having access to the source code along with the built binaries, users can validate their scenarios and if they are not met – they can contribute back to the source code to add support for their scenarios. 
How to contribute:
MSIX toolkit GitHub repository will accept external contributions via pull requests from a fork. 
This article goes through the process of what an external contributor will need to go through to create a pull request -  https://help.github.com/en/articles/creating-a-pull-request-from-a-fork
Before we can accept a pull request from you, you'll need to sign a Contributor License Agreement (CLA). It is an automated process and you only need to do it once.
Will need to check with cela and might need to get this contributor license agreement as vs code.
To enable us to quickly review and accept your pull requests, always create one pull request per issue. Similarly, if it’s a new tool or script, create individual pull requests per tool or script. Keep the pull requests as small and contained to a scenario as possible. Never merge multiple requests in one unless they have the same root cause. Avoid pure formatting changes to code that has not been modified otherwise. Pull requests should contain tests or readme material to explain the changes and how it can be used whenever possible.
Source code guidelines:
It is important to make sure that sound coding practices are enforced initially in the setup of the MSIX Toolkit GitHub project. To that end, all contributions from internal and external contributions will need to be reviewed by fellow colleagues before the code can be checked in. 
We will have a few folks that will manage the GitHub project that will act as the mandatory reviewers for source code that will be checked in. 
License: 
The goal of this project is to enable our customers to be more productive and efficient while working with MSIX packages. The license for this project will allow people to freely use the source code and tools. 
All the source code in the MSIX-Toolkit GitHub project will accompany with an open license which means users are allowed to use as-is or modify the code as needed for their purposes. 
Speak with CELA to get more details what it means to allow external contributions in source code and built binaries.  
Build system:
Only source code that is in the master branch of MSIX toolkit repo will be built on each pull request merge. 

## Executable code:
The build system will build only win32 applications and MSIX packages and copy the artifacts to the releases tab for consumption. 
Speak with William on how to setup the build system for MSIX packages in a GitHub repo. 

## Scripts:
There will no build systems for scripts. Scripts will be checked in as source code and will be available for download. Scripts will be formatted and commented prior to being checked in to master.

## Tests:
Always recommended. Including tests in your pull requests will help expedite the review process as it allows contributors and reviewers ways to validate. It is also good practice to ensure that the source code builds and compile fine. 

We also understand that it might not always make sense to have test case for your pull requests. Besides pull requests that are fixing a minor issue, we ask that the pull request includes an addition to the readme file that will detail the new functionality that was added and how it can be used.  

## What to upload in a project:
Only upload the files and content that is required to compile the application. For instance, if you are using Visual Studio as your IDE, VS auto-generates a bunch of files that are using specific to the setup of the local user which aren’t applicable or required. So we recommend that you add these files to the .gitignore file. 

## Redistributables:
MSIX Toolkit will also include tools that are traditionally available in the Windows 10 SDK. This allows for IT pros specifically to not require downloading a massive SDK that is of no use to them. There will a ‘redist’ folder in the root of the MSIX toolkit GitHub project where these tools will be available. 

Tools include makeappx, comparepackage, signtool, packageeditor, appxsip.dll, appxpackaging.dll etc.




## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
