# Dotfiles for Windows

## Setup
When setting up on a new Windows machine, do the following

1. Create a file called `git.inf` with the following content
```
[Setup]
Lang=default
Dir=C:\Program Files\Git
Group=Git
NoIcons=0
SetupType=default
Components=gitlfs,assoc,assoc_sh,scalar
Tasks=
EditorOption=VIM
CustomEditorPath=
DefaultBranchOption=main
PathOption=CmdTools
SSHOption=OpenSSH
TortoiseOption=false
CURLOption=OpenSSL
CRLFOption=CRLFAlways
BashTerminalOption=MinTTY
GitPullBehaviorOption=Rebase
UseCredentialManager=Enabled
PerformanceTweaksFSCache=Enabled
EnableSymlinks=Enabled
EnablePseudoConsoleSupport=Disabled
EnableFSMonitor=Disabled
```

2. Install Git
```powershell
winget install Git.Git --accept-source-agreements --accept-package-agreements --override "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOCANCEL /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /SP- /LOG /LOADINF=git.inf"
```
> If the install fails,check the log in the User's TEMP folder

3. Clone this repo and cd into the directory
```powershell
git clone {Path to repo}
cd dotfiles
```

4. Open a new PowerShell window **as Administrator** in the dotfiles folder and run
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\win\bootstrap.ps1
```

5. If WSL isn't installed, the bootstrap script will install it and reboot the machine. After reboot, setup a username and password for WSL and run the bootstrap script again to proceed.

6. Add the IP address to the [hosts](/win/ansible/hosts) file by running
```powershell
.\win\scripts\setup-wsl-host-ip.ps1
```

7. Test the connection by running from PowerShell from the dotfiles directory
```powershell
wsl --cd $(Get-Location).Path -- '$HOME/.local/bin/ansible' winbox -i ./win/ansible/hosts -m win_ping -k -u {username}
```

You should see a response similar to
```json
192.168.64.1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

8. Run the desired Ansible playbooks from WSL

## Troubleshooting
The Windows host IP set in the hosts file can change.
To get the current IP, run the following command in WSL
```bash
cat /etc/resolv.conf | grep nameserver | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}"
```
or PowerShell
```powershell
Get-NetIPAddress -AddressFamily IPv4 | Where-Object -Property InterfaceAlias -Like "*WSL*" | Select-Object -Property IPAddress
```


# Refs
[Git for Windows: Silent Install](https://github.com/git-for-windows/git/wiki/Silent-or-Unattended-Installatio)