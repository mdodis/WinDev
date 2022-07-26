# WinDev

## Requirements
* Chocolatey
* Visual Studio with 'C++ Development' package


## Installation
1. Either clone the repository, or run the following one-liner:
```
Set-ExecutionPolicy Unrestricted -Scope Process; $tInstallDir = Read-Host -Prompt 'Enter Absolute path to installation directory:'; $tInstallDirName = Read-Host -Prompt "Enter Directory name:"; if (!(Test-Path $PROFILE)) {     Write-Output $null > $PROFILE; }; Write-Output "Installing to $tInstallDir"; if (!(Test-Path $tInstallDir)) {     Write-Output "This is not a valid path to an existing directory. Exiting...";     exit } else {     $tDev = "$tInstallDir";     pushd $tDev;     $tUrl = "https://github.com/mdodis/WinDev/archive/refs/heads/main.zip";          Invoke-WebRequest -Uri $tUrl -OutFile "WinDev.zip";     Expand-Archive .\WinDev.zip -DestinationPath .;          Move-Item WinDev-main $tInstallDirName;     del .\WinDev.zip;          popd;               Add-Content "$PROFILE" " . ""$tInstallDir/$tInstallDirName/System/Shell.ps1""";      }; 
```
2. Run `System\Reset.ps1` to setup startup scripts (Remember, you *need* to have MSVC installed!)