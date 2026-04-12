# Dotfiles for Windows

## Setup

1. Run the following command from PowerShell

    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force; iwr https://raw.githubusercontent.com/brizdotdev/dotfiles/main/win/bootstrap.ps1 | iex
    ```

1. Run the install script as Administrator

    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force; & $env:USERPROFILE\.dotfiles\win\install.ps1
    ```
