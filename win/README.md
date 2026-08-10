# Dotfiles for Windows

## Setup

1. Run the following command from PowerShell

    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force; iwr https://raw.githubusercontent.com/brizdotdev/dotfiles/main/win/bootstrap.ps1 | iex
    ```

1. Collect your answers, **as your own user, in a non-elevated shell**

    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force; & $env:USERPROFILE\.dotfiles\win\install.ps1 -Pass Answers
    ```

1. Apply the machine configs **from a shell already elevated as an admin account**

    ```powershell
    & $env:USERPROFILE\.dotfiles\win\install.ps1 -Pass Machine
    ```

1. Apply the user configs, back **in your own non-elevated shell**

    ```powershell
    & $env:USERPROFILE\.dotfiles\win\install.ps1 -Pass User
    ```

`install.ps1` refuses to run a pass in the wrong context, so a mistake fails fast
rather than writing to the wrong account.

### Why two passes

Configs are split by security context into `<name>.machine.winget` and
`<name>.user.winget`. Every unit in a `.machine` file declares
`securityContext: elevated`; no unit in a `.user` file does.

If you are a standard user with a separate admin account, do **not** run the whole
thing unelevated and let WinGet elevate for you. WinGet's elevated child process
runs under the *admin* account but writes state into the *caller's* profile, and it
re-secures `%LOCALAPPDATA%\Microsoft\WinGet\State\Configuration` so that you — the
profile's owner — can no longer read it. Every subsequent unit then fails with
`0x80070005`, elevated or not, and clearing it needs admin:

```powershell
Remove-Item "$env:LOCALAPPDATA\Microsoft\WinGet\State\Configuration" -Recurse -Force
```

Running each pass in a shell that is already the right identity avoids the
cross-user child entirely.

### Admin account prerequisites

`winget.exe` and `dsc.exe` are per-user MSIX app execution aliases. An admin account
that has never had them registered fails process init with `0xC0000142`. The machine
pass registers them itself, but if you need to do it by hand, run this **as the admin
account**:

```powershell
Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesiredStateConfiguration_8wekyb3d8bbwe
```

Over-the-shoulder elevation also needs `ConsentPromptBehaviorUser` set to prompt
rather than auto-deny; a value of `0` silently denies every elevation request:

```powershell
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' ConsentPromptBehaviorUser
```

## Autounattend

[Generated using unattend-generator](https://schneegans.de/windows/unattend-generator/) based on [CTT's bypassnro](https://github.com/ChrisTitusTech/bypassnro)

```cmd
curl.exe -L -o C:\Windows\Panther\unattend.xml https://raw.githubusercontent.com/brizdotdev/dotfiles/main/win/autounattend.xml
%WINDIR%\System32\Sysprep\Sysprep.exe /oobe /unattend:C:\Windows\Panther\unattend.xml /reboot
```
