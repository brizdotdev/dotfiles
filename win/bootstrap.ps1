################################################################################
# Bootstrap script: Installs Git and clones dotfiles repo
################################################################################
param (
    [ValidateSet("Preview", "Stable")]
    [string]$WinGetRelease = "Stable"
)

$GitHubUsername = "brizdotdev"
$GitHubRepoName = "dotfiles"

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
        Repair-WinGetPackageManager -Latest -IncludePrerelease
    } else {
        Repair-WinGetPackageManager -Latest
    }
}

function Add-ToPath(
    [string[]]$Paths,
    [System.EnvironmentVariableTarget]$Scope = [System.EnvironmentVariableTarget]::User
) {
    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", $Scope)
    $pathEntries = @()
    if (-not [string]::IsNullOrWhiteSpace($currentPath)) {
        $pathEntries = $currentPath -split ";"
    }

    foreach ($pathToAdd in $Paths) {
        if ([string]::IsNullOrWhiteSpace($pathToAdd)) {
            continue
        }

        if (-not ($pathEntries -contains $pathToAdd)) {
            if ([string]::IsNullOrWhiteSpace($currentPath)) {
                $currentPath = $pathToAdd
            } else {
                $currentPath = "$currentPath;$pathToAdd"
            }
            $pathEntries += $pathToAdd
        }
    }

    [System.Environment]::SetEnvironmentVariable("Path", $currentPath, $Scope)
}

function Install-Git {
    $ErrorActionPreference = "Stop"
    Write-Host -ForegroundColor Blue "Installing Git"

    $gitInstallPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Programs\Git"
    # https://gitforwindows.org/silent-or-unattended-installation.html
    # https://jrsoftware.org/ishelp/index.php?topic=setupcmdline
    $gitInstallOverrides = @(
        "/SP-"
        "/VERYSILENT"
        "/SUPPRESSMSGBOXES"
        "/NORESTART"
        "/NOCANCEL"
        "/CURRENTUSER"
        "/LOG"
        "/DIR=`"$gitInstallPath`""
        "/COMPONENTS=`"assoc,assoc_sh,gitlfs,scalar`""
        "/TASKS=`"`""
        "/o:SSHOption=ExternalOpenSSHPathOption=CmdTools"
        "/o:CURLOption=WinSSL"
        "/o:PathOption=CmdTools"
        "/o:BashTerminalOption=ConHost"
        "/o:EnableSymlinks=Enabled"
        "/o:EnableFSMonitor=Enabled"
        "/o:PerformanceTweaksFSCache=Enabled"
    ) -join " "
    winget install --scope user --silent --accept-source-agreements --accept-package-agreements --source winget --override $gitInstallOverrides Git.Git

    $gitCmdPath = Join-Path -Path $gitInstallPath -ChildPath "cmd"
    $gitBinPath = Join-Path -Path $gitInstallPath -ChildPath "bin"
    $gitUsrBinPath = Join-Path -Path $gitInstallPath -ChildPath "usr\bin"
    $gitPathsToAdd = @($gitCmdPath, $gitBinPath, $gitUsrBinPath)
    Add-ToPath -Paths $gitPathsToAdd -Scope ([System.EnvironmentVariableTarget]::User)

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
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
    if ($LASTEXITCODE -ne 0) {
        Write-Host -ForegroundColor Red  "Failed to clone dotfiles"
        Read-Host
        exit 1
    }
    [Environment]::SetEnvironmentVariable("DOTFILES", $ParentPath, "User")
    Write-Host -ForegroundColor Green "Dotfiles cloned to $dotfilesPath"
    Write-Host -ForegroundColor Green "Run $dotfilesPath\win\install.ps1 to finish setup"
}

Update-WinGetFromPowerShellGallery -Release $WinGetRelease
Install-Git
Clone-Repo
