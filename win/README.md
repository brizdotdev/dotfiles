# Dotfiles for Windows

## Setup

1. Run the following command from PowerShell

    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force; iwr https://raw.githubusercontent.com/brizdotdev/dotfiles/main/win/bootstrap.ps1 | iex
    ```

1. Run the install script as Administrator

    ```powershell
    $env:USERPROFILE\.dotfiles\win\install.ps1
    ```

    You may need to set the execution policy to `Bypass` for the install script to run

    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    ```

1. Set the following Settings
    1. In Windows Update Settings > Turn on Receive Updates for other Microsoft products
    1. Go over all Windows settings
    1. Check Startup apps
    1. Restore PowerToys settings

## Refs

- [WinGet - Microsoft Store](https://apps.microsoft.com/store/detail/app-installer/9NBLGGH4NNS1)
- [Git for Windows: Silent Install](https://github.com/git-for-windows/git/wiki/Silent-or-Unattended-Installation)
- [VSCode install args](https://github.com/microsoft/vscode/blob/main/build/win32/code.iss#L76)