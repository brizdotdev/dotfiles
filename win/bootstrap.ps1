################################################################################
# Bootstrap script: Installs Git and clones dotfiles repo
################################################################################
param (
    [switch]$UpdateFromGitHub,
    [ValidateSet("Preview", "Stable")]
    [string]$WinGetRelease = "Stable"
)

$GitHubUsername = "brizdotdev"
$GitHubRepoName = "dotfiles"

$gitInstallPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Programs\Git"
# https://github.com/git-for-windows/git/wiki/Silent-or-Unattended-Installation
$gitConfig = @"
[Setup]
Lang=default
Dir=$gitInstallPath
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

enum WinGetRelease {
    Stable
    Preview
}


$WinGetUrl = @{
    [WinGetRelease]::Stable  = "https://aka.ms/getwinget"
    [WinGetRelease]::Preview = "https://aka.ms/getwingetpreview"
}

function Update-WinGetFromGitHub ([WinGetRelease]$Release = [WinGetRelease]::Stable) {
    Write-Host -ForegroundColor Blue "Downloading WinGet $Release and its dependencies..."
    Push-Location $env:TEMP
    Invoke-WebRequest -Uri $WinGetUrl[$release] -OutFile WinGet.msixbundle
    Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile Microsoft.VCLibs.x64.14.00.Desktop.appx
    Invoke-WebRequest -Uri https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx -OutFile Microsoft.UI.Xaml.2.8.x64.appx
    Add-AppxPackage Microsoft.VCLibs.x64.14.00.Desktop.appx
    Add-AppxPackage Microsoft.UI.Xaml.2.8.x64.appx
    Add-AppxPackage WinGet.msixbundle
    Pop-Location
}

function Update-WinGetFromPowerShellGallery([WinGetRelease]$Release = [WinGetRelease]::Stable) {
    Write-Host -ForegroundColor Blue "Installing WinGet PowerShell module from PSGallery..."
    Install-PackageProvider -Name NuGet -Force | Out-Null
    Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
    if ($Release -eq [WinGetRelease]::Preview) {
        Repair-WinGetPackageManager -Latest -IncludePrerelease
    } else {
        Repair-WinGetPackageManager -Latest
    }
}

function Update-WinGetFromStore {
    $store = Get-AppxPackage -Name "Microsoft.WindowsStore"
    if ($null -ne $store) {
        Start-Process "ms-windows-store://pdp/?ProductId=9nblggh4nns1"
        Read-Host -Prompt "Press Enter after installing WinGet"
        return $True
    }
    Write-Host -ForegroundColor Red "Windows Store not found. Use -UpdateFromGitHub to download WinGet from GitHub"
    exit 1
}

function Test-WinGet {
    $WinGetMinVersion = [version]"1.9.25170"
    $ErrorActionPreference = "SilentlyContinue"
    Write-Host -ForegroundColor Blue "Checking WinGet version"
    $winGetVersion = winget -v
    $ErrorActionPreference = "Continue"
    if ($null -eq $winGetVersion) {
        Write-Host -ForegroundColor Red "WinGet not installed"
        return $False
    }
    $winGetVersion = $winGetVersion -replace '^v'
    if ([version]$winGetVersion -lt $WinGetMinVersion) {
        Write-Host -ForegroundColor Red "WinGet version $wingetVersion is too old. Update to the latest version"
        return $False
    }
    Write-Host -ForegroundColor Green "WinGet installed"
    return $True
}

function Install-Git {
    $ErrorActionPreference = "Stop"
    Write-Host -ForegroundColor Blue "Installing Git"
    Push-Location $env:TEMP
    $gitConfig | Out-File -FilePath "git.ini" -Encoding ASCII
    winget install Git.Git --scope user --silent --accept-source-agreements --accept-package-agreements --override "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOCANCEL /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /SP- /LOG /LOADINF=git.ini"
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Pop-Location
    Write-Host -ForegroundColor Green "Git installed"
}

function Clone-Repo {
    $ErrorActionPreference = "Stop"
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

if ((Test-WinGet) -eq $False) {
    Update-WinGetFromPowerShellGallery
}
Install-Git
Clone-Repo
