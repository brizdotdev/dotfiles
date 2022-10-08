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
winget install Git.Git --override "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOCANCEL /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /SP- /LOG /LOADINF=git.inf"
```
> If the install fails,check the log in the User's TEMP folder

3. Clone this repo
```powershell
git clone {Path to repo}
```

4. Run setup script
```powershell
.\win\bootstrap.ps1
```

5. Edit the [hosts](/win/ansible/hosts) file and setup the username, password and IP


# Refs
[Git for Windows: Silent Install](https://github.com/git-for-windows/git/wiki/Silent-or-Unattended-Installatio)