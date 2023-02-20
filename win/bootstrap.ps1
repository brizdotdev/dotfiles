################################################################################
# Bootstrap script: Installs Git and clones dotfiles repo
################################################################################
$GitHubUsername = "brizdotdev"
$GitHubRepoName = "dotfiles"

$gitConfig = @"
[Setup]
Lang=default
Dir=C:\Program Files\Git
Group=Git
NoIcons=0
SetupType=default
Components=gitlfs,assoc,assoc_sh,scalar,windowsterminal
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
"@

$gitConfig | Out-File -FilePath "$env:TEMP\git.ini" -Encoding ASCII

Write-Host -ForegroundColor Blue "Installing Git"
git --version | Out-Null
if ($? -eq $True) {
    Write-Host -ForegroundColor Yellow "Git already installed"
}
else
{
    winget install Git.Git --silent --accept-source-agreements --accept-package-agreements --override "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOCANCEL /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /SP- /LOG /LOADINF=$env:TEMP\git.inf"
}
if ($? -eq $False) {
    Write-Host -ForegroundColor Red  "Failed to install Git"
    exit 1
}
Write-Host -ForegroundColor Green "Git installed"

Write-Host -ForegroundColor Blue "Cloning dotfiles"
$dotfilesPath = Join-Path -Path $HOME -ChildPath ".dotfiles"
if (Test-Path -Path $dotfilesPath) {
    Write-Host -ForegroundColor Yellow "Dotfiles folder already exists"
    exit 0
}
git clone --recurse-submodules "https://github.com/$GitHubUsername/$GitHubRepoName" $dotfilesPath
if ($? -eq $False) {
    Write-Host -ForegroundColor Red  "Failed to clone dotfiles"
    exit 1
}
Write-Host -ForegroundColor Green "Dotfiles cloned to $dotfilesPath"
Write-Host -ForegroundColor Green "Run AS ADMIN $dotfilesPath\win\install.ps1 to finish setup"