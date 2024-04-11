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

function Update-WinGet {
    $store = Get-AppxPackage -Name "Microsoft.WindowsStore"
    if ($store -ne $null) {
        Start-Process "ms-windows-store://pdp/?ProductId=9nblggh4nns1"
        Read-Host -Prompt "Press Enter after installing WinGet"
    }

    Write-Host -ForegroundColor Blue "Downloading WinGet and its dependencies..."
    pushd $env:TEMP
    Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
    Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile Microsoft.VCLibs.x64.14.00.Desktop.appx
    Invoke-WebRequest -Uri https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx -OutFile Microsoft.UI.Xaml.2.8.x64.appx
    Add-AppxPackage Microsoft.VCLibs.x64.14.00.Desktop.appx
    Add-AppxPackage Microsoft.UI.Xaml.2.8.x64.appx
    Add-AppxPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
    popd
    return
}

function Test-WinGet {
    Write-Host -ForegroundColor Blue "Checking WinGet version"
    $ErrorActionPreference = "SilentlyContinue";
    $winGetVersion = winget -v
    $ErrorActionPreference = "Continue";
    if ($winGetVersion -eq $null) {
        Write-Host -ForegroundColor Red "WinGet not installed"
        Update-WinGet
    }
    $winGetVersion = $(winget -v) -replace '^v'
    if ([version]$winGetVersion -lt [version]"1.6.0")
    {
        Write-Host -ForegroundColor Red "WinGet version $wingetVersion is too old. Update to the latest version"
        Update-Winget
    }
    Write-Host -ForegroundColor Green "WinGet installed"
}

function Install-Git
{
    Write-Host -ForegroundColor Blue "Installing Git"
    pushd $env:TEMP
    $gitConfig | Out-File -FilePath "git.ini" -Encoding ASCII
    winget install Git.Git --silent --accept-source-agreements --accept-package-agreements --override "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOCANCEL /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /SP- /LOG /LOADINF=git.ini"
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    popd
    Write-Host -ForegroundColor Green "Git installed"
}

function Clone-Repo
{
    Write-Host -ForegroundColor Blue "Cloning dotfiles"
    $dotfilesPath = Join-Path -Path $HOME -ChildPath ".dotfiles"
    if (Test-Path -Path $dotfilesPath) {
        Write-Host -ForegroundColor Yellow "Dotfiles folder already exists"
        Read-Host
        exit 0
    }
    git clone --recurse-submodules "https://github.com/$GitHubUsername/$GitHubRepoName" $dotfilesPath
    if ($? -eq $False) {
        Write-Host -ForegroundColor Red  "Failed to clone dotfiles"
        Read-Host
        exit 1
    }
    Write-Host -ForegroundColor Green "Dotfiles cloned to $dotfilesPath"
    Write-Host -ForegroundColor Green "Run AS ADMIN $dotfilesPath\win\install.ps1 to finish setup"
}

Test-WinGet
Install-Git
Clone-Repo
