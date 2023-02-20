# Dotfiles for Windows

## Setup

1. If Winget isn't installed, install it from the [Microsoft Store](https://apps.microsoft.com/store/detail/app-installer/9NBLGGH4NNS1)

1. Run the following command from PowerShell

    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force; iwr https://raw.githubusercontent.com/brizdotdev/dotfiles/main/win/bootstrap.ps1 | iex
    ```

1. Run the install script as Administrator

    ```powershell
    $env:USERPROFILE\.dotfiles\win\install.ps1
    ```

1. Set the following Settings
    1. In Windows Update Settings > Turn on Receive Updates for other Microsoft products
    1. Go over all Windows settings
    1. Check Startup apps
    1. Run script to set MPV as default player
    1. Restore PowerToys settings
    1. (Temp) Fix Windows Terminal settings

## Refs

- [Git for Windows: Silent Install](https://github.com/git-for-windows/git/wiki/Silent-or-Unattended-Installation)
- [VSCode install args](https://github.com/microsoft/vscode/blob/main/build/win32/code.iss#L76)