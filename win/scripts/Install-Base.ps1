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
	[string]$GitUserEmail
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
winget install --silent Microsoft.PowerToys
winget install --silent gerardog.gsudo
winget install --silent VideoLAN.VLC
winget install --silent Microsoft.VisualStudioCode --override '/SILENT /mergetasks="!runcode,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath"'
## Neovim
winget install --silent Neovim.Neovim
$env:EDITOR = "nvim"
[Environment]::SetEnvironmentVariable("EDITOR", "nvim", "User")

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
# TODO: Enable signing with SSH key (https://github.com/Okeanos/dotfiles-windows/blob/8cba8eda06ee01bc5a174f61656a7bc7cb798e4d/bootstrap.ps1#L62-L89)
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

# TODO: Install custom cursor

exit 0
