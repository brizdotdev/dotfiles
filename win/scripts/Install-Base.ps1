#Requires -RunAsAdministrator
################################################################################
# Install basic apps and fonts
################################################################################
param(
	[Parameter(Mandatory)]
	[string]$BrowserChoice,
	[Parameter(Mandatory)]
	[string]$GitUserName,
	[Parameter(Mandatory)]
	[string]$GitUserEmail,
	[Parameter(Mandatory)]
	[string]$GitConfigureSigning
)

# Helper functions
$HelperPath = Join-Path -Path $PSScriptRoot -ChildPath "helpers"
Get-ChildItem -Path $HelperPath -Filter "*.ps1" | ForEach-Object {
    . $_.FullName
}

# Browsers
Write-Host -ForegroundColor Blue "Installing browsers"
winget install --silent Google.Chrome
winget install --silent Mozilla.Firefox
Write-Host -ForegroundColor Blue "Setting default browser"
choco install -y setdefaultbrowser
if ($BrowserChoice -eq "firefox") {
    SetDefaultBrowser.exe HKLM Firefox-308046B0AF4A39CB
} elseif ($BrowserChoice -eq "chrome") {
    SetDefaultBrowser.exe chrome
}
Write-Host -ForegroundColor Green "Default browser set to $BrowserChoice"
Write-Host -ForegroundColor Green "Browsers installed"
Write-Host ""


# Utils
Write-Host -ForegroundColor Blue "Installing utils"
winget install --silent 7zip.7zip
$7zipPath = "C:\Program Files\7-Zip"
[Environment]::SetEnvironmentVariable("PATH", "$env:Path;$7zipPath", "User")
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
winget install --silent Microsoft.PowerToys
winget install --silent gerardog.gsudo
winget install --silent VideoLAN.VLC
winget install --silent Microsoft.VisualStudioCode --override '/SILENT /mergetasks="!runcode,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath"'
## Neovim
winget install --silent Neovim.Neovim
$env:EDITOR = "nvim"
[Environment]::SetEnvironmentVariable("EDITOR", "nvim", "User")
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# MS Store Apps
foreach ($app in @(
	"9P3JFR0CLLL6" # mpv
	"9PMMSR1CGPWG" # HEIF Image Extensions
	"9N5TDP8VCMHS" # Web Media Extensions
	"9PG2DK419DRG" # Webp Image Extensions
	"9N4D0MSMP0PT" # VP9 Video Extensions
	"9N95Q1ZZPMH4" # MPEG-2 Video Extension
	"9MVZQVXJBQ9V" # AV1 Video Extension
)) {
	winget install --id $app --silent --source msstore --accept-package-agreements --accept-source-agreements
}
Write-Host -ForegroundColor Green "Utils installed"
Write-Host ""

# Fonts
Write-Host -ForegroundColor Blue "Installing fonts"
choco install -y nerd-fonts-jetbrainsmono nerd-fonts-iosevka nerd-fonts-cascadiacode nerdfont-hack nerd-fonts-ubuntumono nerd-fonts-victormono
Write-Host -ForegroundColor Green "Fonts installed"
Write-Host ""

# Git config
Write-Host -ForegroundColor Blue "Configuring Git"
winget install --silent dandavison.delta
winget install --silent GnuPG.Gpg4win
winget install --silent Microsoft.OpenSSH.Beta
## Symlink .gitconfig
if (Test-Path -Path "$env:USERPROFILE\.gitconfig") {
		Remove-Item -Path "$env:USERPROFILE\.gitconfig" -Force
}
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.gitconfig" -Target "$env:DOTFILES\common\config\git\.gitconfig"
if (Test-Path -Path "$env:USERPROFILE\.gitconfig.local") {
		Remove-Item -Path "$env:USERPROFILE\.gitconfig.local" -Force
}
@"
[user]
	name = $GitUserName
	email = $GitUserEmail
"@ | Out-File -Encoding "utf8" -FilePath "$($ENV:USERPROFILE)\.gitconfig.local"
if ($GitConfigureSigning -eq $True) {
@"
[gpg]
	format = ssh
[commit]
	gpgsign = true
[user]
	signingkey = ~/.ssh/id_ed25519_sk_rk_Default
"@ | Out-File -Encoding "utf8" -FilePath "$($ENV:USERPROFILE)\.gitconfig.local" -Append
}
## Set pager
$env:PAGER = "less"
[Environment]::SetEnvironmentVariable("PAGER", "less", "User")
## Symlink .vimrc
if (Test-Path -Path "$env:USERPROFILE\.vimrc") {
		Remove-Item -Path "$env:USERPROFILE\.vimrc" -Force
}
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.vimrc" -Target "$env:DOTFILES\common\config\vim\.vimrc"
Write-Host -ForegroundColor Green "Git configured"
Write-Host ""

# Variables
# Ensure that Unix tools have a consistent and predictable HOME directory; important if a network drive is used as pseudo-home
[Environment]::SetEnvironmentVariable("HOME", "$env:USERPROFILE", 'User')
# Ensure that Unix tools have a consistent and predictable USER variable available; important for SSH for example
[Environment]::SetEnvironmentVariable("USER", "$env:USERNAME", 'User')

# Install custom cursor
Write-Host -ForegroundColor Blue "Installing custom cursor"
pushd $env:TEMP
curl.exe -L -O  https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic-Windows.zip
mkdir.exe Bibata
Expand-Archive -Path Bibata-Modern-Classic-Windows.zip -DestinationPath .\Bibata
Get-ChildItem -Path .\Bibata | ForEach-Object {
	Start-Process "$_\install.inf" -Verb "Install"
}
Write-Host -ForegroundColor Cyan "Change your cursor theme"
control.exe /name Microsoft.Mouse
Write-Host -ForegroundColor Green "Custom cursor installed"
popd


exit 0
