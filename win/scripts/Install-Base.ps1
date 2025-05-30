#Requires -RunAsAdministrator
################################################################################
# Install basic apps and fonts
################################################################################
param(
	[Parameter(Mandatory)]
	[string]$BrowserChoice,
	[Parameter(Mandatory)]
	[string]$InstallFirefoxExtensions,
	[Parameter(Mandatory)]
	[string]$InstallLibrewolfExtensions,
	[Parameter(Mandatory)]
	[string]$InstallChromeExtensions,
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
$ChromeExtensions = Get-Content -Path "$env:DOTFILES/common/config/chrome/extensions.txt"
# Strip out empty lines and comments
$ChromeExtensions = $ChromeExtensions | Where-Object { $_ -notmatch "^\s*$" -and $_ -notmatch "^#" }
if ($InstallChromeExtensions -eq $True)
{
	$ChromeExtensions | ForEach-Object {
		& "C:\Program Files\Google\Chrome\Application\chrome.exe" $_
	}
}

winget install --silent Mozilla.Firefox
$FirefoxExtensions = Get-Content -Path "$env:DOTFILES/common/config/firefox/extensions.txt"
# Strip out empty lines and comments
$FirefoxExtensions = $FirefoxExtensions | Where-Object { $_ -notmatch "^\s*$" -and $_ -notmatch "^#" }
if ($InstallFirefoxExtensions -eq $True)
{
	$FirefoxExtensions | ForEach-Object {
		& "C:\Program Files\Mozilla Firefox\firefox.exe" -new-tab $_
	}
}

winget install --silent LibreWolf.LibreWolf
$FirefoxExtensions = Get-Content -Path "$env:DOTFILES/common/config/firefox/extensions.txt"
# Strip out empty lines and comments
$FirefoxExtensions = $FirefoxExtensions | Where-Object { $_ -notmatch "^\s*$" -and $_ -notmatch "^#" }
if ($InstallLibrewolfExtensions -eq $True)
{
	$FirefoxExtensions | ForEach-Object {
		& "C:\Program Files\LibreWolf\libreWolf.exe" -new-tab $_
	}
}
Write-Host -ForegroundColor Blue "Setting default browser"
choco install -y setdefaultbrowser
if ($BrowserChoice -eq "firefox") {
    SetDefaultBrowser.exe HKLM Firefox-308046B0AF4A39CB
} elseif ($BrowserChoice -eq "chrome") {
    SetDefaultBrowser.exe chrome
} elseif ($BrowserChoice -eq "librewolf") {
		SetDefaultBrowser.exe HKLM LibreWolf
}
Write-Host -ForegroundColor Green "Default browser set to $BrowserChoice"
Write-Host -ForegroundColor Green "Browsers installed"
Write-Host ""


# Utils
Write-Host -ForegroundColor Blue "Installing utils"
winget install --silent 7zip.7zip
$7zipPath = "C:\Program Files\7-Zip"
if ($env:PATH -notlike "*$7zipPath*") {
		[Environment]::SetEnvironmentVariable("PATH", "$env:Path;$7zipPath", "User")
}
Reload-Path
winget install --silent Microsoft.PowerToys

# Download PowerToys plugins
$processorType = (Get-WmiObject -Class Win32_Processor).Architecture

switch ($processorType) {
    5 { $arch = "ARM" }
    9 { $arch = "x64" }
    0 { $arch = "x86" }
    default { $arch = "Unknown" }
}
$powerToysRunPlugins = @(
	"8LWXpg/PowerToysRun-GitHubRepo",
	"CoreyHayward/PowerToys-Run-ClipboardManager",
	"CoreyHayward/PowerToys-Run-InputTyper",
	"CoreyHayward/PowerToys-Run-Snippets",
	"CoreyHayward/PowerToys-Run-Timer"
)

$powerToysRunPluginsFolder = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Microsoft\PowerToys\PowerToys Run\Plugins"

foreach ($plugin in $powerToysRunPlugins) {
	Invoke-WebRequest -Uri "https://api.github.com/repos/$plugin/releases/latest" | ConvertFrom-Json | ForEach-Object {
    Write-Host -ForegroundColor Blue "Installing PowerToys Run plugin: $plugin"
    $asset = $_.assets[0]
    if ($_.assets.Count -gt 1) {
      $asset = $_.assets | Where-Object { $_.name -match $arch }
    }
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile "$env:TEMP\$($asset.name)"
    Expand-Archive -Path "$env:TEMP\$($asset.name)" -DestinationPath $powerToysRunPluginsFolder -Force
    Remove-Item -Path "$env:TEMP\$($asset.name)" -Force
	}
}

winget install --silent gerardog.gsudo
winget install --silent VideoLAN.VLC
winget install --silent CodecGuide.K-LiteCodecPack.Full
winget install --silent Bitwarden.Bitwarden
winget install --silent Bitwarden.CLI
winget install --silent Microsoft.WindowsTerminal
winget install --silent lsd-rs.lsd

## VSCode
winget install --silent Microsoft.VisualStudioCode --override '/SILENT /mergetasks="!runcode,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath"'
Reload-Path
code --install-extension vscodevim.vim

## Neovim
winget install --silent Neovim.Neovim
$env:EDITOR = "nvim"
[Environment]::SetEnvironmentVariable("EDITOR", "nvim", "User")
Reload-Path
$nvimConfigPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath "nvim"
if (Test-Path -Path $nvimConfigPath) {
	Remove-Item -Path $nvimConfigPath -Force
}
New-Item -ItemType SymbolicLink -Path $nvimConfigPath -Target "$env:DOTFILES\common\config\nvim"

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
choco upgrade -y `
	nerd-fonts-bitstreamverasansmono `
	nerd-fonts-commitmono `
	nerd-fonts-fantasquesansmono `
	nerd-fonts-iosevka `
	nerd-fonts-jetbrainsmono `
	nerd-fonts-lekton `
	nerd-fonts-proggyclean `
	nerd-fonts-spacemono `
	nerd-fonts-terminus `
	nerd-fonts-ubuntumono `
	nerd-fonts-victormono `
	nerd-fonts-hack `
	cascadiamono `
	monaspace
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
if (Test-Path -Path "$env:USERPROFILE\.gitignore_global") {
	Remove-Item -Path "$env:USERPROFILE\.gitignore_global" -Force
}
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.gitignore_global" -Target "$env:DOTFILES\common\config\git\.gitignore_global"
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
if (Test-Path -Path Bibata) {
	Remove-Item -Path Bibata -Force -Recurse
}
mkdir.exe -p Bibata
Expand-Archive -Path Bibata-Modern-Classic-Windows.zip -DestinationPath .\Bibata
$cursors = Get-ChildItem -Path .\Bibata
foreach ($cursor in $cursors) {
	$installPath = Join-Path -Path $cursor.FullName -ChildPath "install.inf"
	Start-Process "$installPath" -Verb "Install"
}
Write-Host -ForegroundColor Cyan "Change your cursor theme"
control.exe /name Microsoft.Mouse
Write-Host -ForegroundColor Green "Custom cursor installed"
popd

exit 0
