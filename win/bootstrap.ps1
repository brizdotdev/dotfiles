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
SSHOption=ExternalOpenSSH
TortoiseOption=false
CURLOption=WinSSL
CRLFOption=CRLFAlways
BashTerminalOption=ConHost
GitPullBehaviorOption=Rebase
UseCredentialManager=Enabled
PerformanceTweaksFSCache=Enabled
EnableSymlinks=Enabled
EnablePseudoConsoleSupport=Disabled
EnableFSMonitor=Enabled
"@

Write-Host -ForegroundColor Blue "Checking winget version"
$wingetVersion = winget -v
if ($wingetVersion -eq $null) {
    Write-Host -ForegroundColor Red "Winget not installed"
    exit 1
}
$wingetVersion = $wingetVersion -replace '^v'
if ([version]$wingetVersion -lt [version]"1.6.0")
{
    Write-Host -ForegroundColor Red "Winget version $wingetVersion is too old. Downloading latest release..."
    $wingetReleases = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
    $response = Invoke-RestMethod -Uri $wingetReleases
    $latestRelease = $response[0].assets | Where-Object { $_.name -match "msixbundle" }[0]
    if ($latestRelease -eq $null) {
        Write-Host -ForegroundColor Red "Failed to find latest release"
        exit 1
    }
    pushd "$env:USERPROFILE\Downloads"
    Invoke-WebRequest -Uri $latestRelease.browser_download_url -OutFile $latestRelease.name
    Start-Process -Wait -FilePath $latestRelease.name
}
Write-Host -ForegroundColor Green "Winget installed"

Write-Host -ForegroundColor Blue "Installing Git"
pushd $env:TEMP
$gitConfig | Out-File -FilePath "git.ini" -Encoding ASCII
winget install Git.Git --silent --accept-source-agreements --accept-package-agreements --override "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOCANCEL /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /SP- /LOG /LOADINF=git.ini"
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
popd
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