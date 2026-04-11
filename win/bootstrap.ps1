################################################################################
# Bootstrap script: Installs Git and clones dotfiles repo
################################################################################
param (
    [ValidateSet("Preview", "Stable")]
    [string]$WinGetRelease = "Stable"
)

$GitHubUsername = "brizdotdev"
$GitHubRepoName = "dotfiles"

$dotfilesPath = Join-Path -Path $HOME -ChildPath ".dotfiles"

$ErrorActionPreference = 'Stop'
enum WinGetRelease {
    Stable
    Preview
}

function Update-WinGetFromPowerShellGallery([WinGetRelease]$Release = [WinGetRelease]::Stable) {
    Write-Host -ForegroundColor Blue "Installing WinGet"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 # Ensure required TLS protocols are enabled for the gallery
    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
    Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -Scope CurrentUser -AllowClobber -ErrorAction SilentlyContinue
    if ($Release -eq [WinGetRelease]::Preview) {
        Repair-WinGetPackageManager -Latest -Force -IncludePrerelease
    } else {
        Repair-WinGetPackageManager -Latest -Force
    }
    winget configure --enable
}

function Install-Git {
    $ErrorActionPreference = "Stop"
    Write-Host -ForegroundColor Blue "Installing Git"
    winget configure --accept-configuration-agreements https://raw.githubusercontent.com/$GitHubUsername/$GitHubRepoName/refs/heads/main/win/winget/git.winget
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-Host -ForegroundColor Green "Git installed"
}

function Clone-Repo {
    $ErrorActionPreference = "Stop"
    Write-Host -ForegroundColor Blue "Cloning dotfiles"
    if (Test-Path -Path $dotfilesPath) {
        Write-Host -ForegroundColor Yellow "Dotfiles folder already exists"
        Read-Host
        exit 0
    }
    git clone --recurse-submodules "https://github.com/$GitHubUsername/$GitHubRepoName" $dotfilesPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host -ForegroundColor Red  "Failed to clone dotfiles"
        Read-Host
        exit 1
    }
    [Environment]::SetEnvironmentVariable("DOTFILES", $dotfilesPath, "User")
    Write-Host -ForegroundColor Green "Dotfiles cloned to $dotfilesPath"
    Write-Host -ForegroundColor Green "Run $dotfilesPath\win\install.ps1 to finish setup"
}

function Set-EnvironmentVariables {
    # Set dotfiles env var to the path of the dotfiles repo
    [Environment]::SetEnvironmentVariable("DOTFILES", $dotfilesPath, "User")
    $env:DOTFILES = [Environment]::GetEnvironmentVariable("DOTFILES", "User")
}

Update-WinGetFromPowerShellGallery -Release $WinGetRelease
Install-Git
Clone-Repo
Set-EnvironmentVariables