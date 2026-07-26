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

## Autounattend

[Generated using unattend-generator](https://schneegans.de/windows/unattend-generator/) based on [CTT's bypassnro](https://github.com/ChrisTitusTech/bypassnro)

```cmd
curl.exe -L -o C:\Windows\Panther\unattend.xml https://raw.githubusercontent.com/brizdotdev/dotfiles/main/win/autounattend.xml
%WINDIR%\System32\Sysprep\Sysprep.exe /oobe /unattend:C:\Windows\Panther\unattend.xml /reboot
```
