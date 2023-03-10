#Requires -RunAsAdministrator
################################################################################
# Install apps and tools for development
################################################################################
Write-Host -ForegroundColor Blue "Installing apps and tools for development"
$LocalWindowsApps = "$env:LocalAppData\Microsoft\WindowsApps"

# Helper functions
$HelperPath = Join-Path -Path $PSScriptRoot -ChildPath "helpers"
Get-ChildItem -Path $HelperPath -Filter "*.ps1" | ForEach-Object {
    . $_.FullName
}

# Install and configure PowerShell
Write-Host -ForegroundColor Blue "Installing PowerShell"
winget install --silent Microsoft.PowerShell
winget install --silent Starship.Starship
Install-PackageProvider -Name NuGet -Scope AllUsers -Force -ErrorAction SilentlyContinue
choco install -y zoxide fzf
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
refreshenv
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
[Environment]::SetEnvironmentVariable("POWERSHELL_TELEMETRY_OPTOUT", "1", 'User')
[Environment]::SetEnvironmentVariable("POWERSHELL_UPDATECHECK_OPTOUT", "1", 'User')
pwsh.exe -c "Install-Module -Name posh-git -Scope CurrentUser -Force"
pwsh.exe -c "Install-Module -Name Terminal-Icons -Scope CurrentUser -Force"
pwsh.exe -c "Install-Module -Name DockerCompletion -Scope CurrentUser -Force"
pwsh.exe -c "Install-Module -Name PSFzf -Scope CurrentUser -Force"
pwsh.exe -c "Install-Module -Name PSReadLine -Scope CurrentUser -AllowPrerelease -Force"
pwsh.exe -c "Install-Module -Name CompletionPredictor -Scope CurrentUser -AllowPrerelease -Force"
pwsh.exe -c "Install-Module -Name ChangeScreenResolution -Scope CurrentUser -Force"
pwsh.exe -c "Install-Module -Name VirtualDesktop -Scope CurrentUser -Force"
# Symlink profile.ps1
touch.exe $PROFILE
$PowerShellFolder = pwsh.exe -NoLogo -NonInteractive -NoProfile -c '$(Get-Item -Path "$PROFILE").Directory.FullName'
Write-Host "Powershell folder: $PowerShellFolder"
mkdir.exe -p $PowerShellFolder
$PowerShellDotfilesFolder = "$env:DOTFILES\win\config\PowerShell"
Get-ChildItem -Path $PowerShellFolder | ForEach-Object {
	$filename = $_.Name
	if (Test-Path -Path "$PowerShellDotfilesFolder\$filename") {
		Remove-Item -Path "$PowerShellFolder\$filename" -Force
	}
}
LinkFiles $PowerShellDotfilesFolder "$PowerShellFolder"
# Symlink Starship config
$StarshipFolder = "$env:USERPROFILE\.config\"
$StarshipFile = "$StarshipFolder\starship.toml"
mkdir.exe -p $StarshipFolder
if (Test-Path -Path $StarshipFile)
{
	Remove-Item -Path $StarshipFile -Force
}
New-Item -ItemType SymbolicLink -Path $StarshipFile -Target "$env:DOTFILES\common\config\starship\starship.toml"
Write-Host -ForegroundColor Green "PowerShell installed"
Write-Host ""

# CLI tools
winget install --silent stedolan.jq
winget install --silent MikeFarah.yq
winget install --silent JFLarvoire.Ag
winget install --silent glab
choco install -y ripgrep fzf bat lazygit fd lf glow dust duf xsv sd-cli
# Install fx
pushd $LocalWindowsApps
curl.exe -L -o fx.exe https://github.com/antonmedv/fx/releases/latest/download/fx_windows_amd64.exe
popd

# Configure Lazygit
$LazyGitConfigPath = "$env:AppData\lazygit"
mkdir.exe -p $LazyGitConfigPath
$LazyGitConfigFile = Join-Path -Path $LazyGitConfigPath -ChildPath "config.yml"
if (Test-Path -Path $LazyGitConfigFile) {
    Remove-Item -Path $LazyGitConfigFile -Force
}
New-Item -ItemType SymbolicLink -Path "$LazyGitConfigFile" -Target "$env:DOTFILES\common\config\lazygit\config.yml"

# Useful GUI tools
winget install --silent WinMerge.WinMerge
winget install --silent WinSCP.WinSCP
winget install --silent Insomnia.Insomnia

# dotnet
winget install --silent Microsoft.DotNet.SDK.3_1
winget install --silent Microsoft.DotNet.SDK.5
winget install --silent Microsoft.DotNet.SDK.6
winget install --silent Microsoft.DotNet.SDK.7
winget install --silent Microsoft.DotNet.SDK.Preview

# DB
winget install --silent TablePlus.TablePlus
winget install --silent Microsoft.SQLServerManagementStudio

# Langs
winget install --silent OpenJS.NodeJS
Remove-Item -Path "$LocalWindowsApps\python.exe" -Force
Remove-Item -Path "$LocalWindowsApps\python3.exe" -Force
winget install --silent Python.Python.3.12 --override '/passive PrependPath=1'

# Repos folder
$ReposFolder = "$env:USERPROFILE\Repos"
if (!(Test-Path -Path $ReposFolder)) {
    New-Item -ItemType Directory -Path $ReposFolder
}
$env:REPOS = $ReposFolder
[Environment]::SetEnvironmentVariable("REPOS", $ReposFolder, "User")

# Hosts file
$HostsFile = "C:\Windows\System32\drivers\etc\hosts"
$env:HOSTS = $HostsFile
[Environment]::SetEnvironmentVariable("HOSTS", $HostsFile, "Machine")

Write-Host -ForegroundColor Green "Apps and tools for development installed"
exit 0
