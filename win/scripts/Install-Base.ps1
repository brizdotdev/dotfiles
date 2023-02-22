#Requires -RunAsAdministrator
################################################################################
# Install basic apps and fonts
################################################################################

# Browsers
Write-Host -ForegroundColor Blue "Installing browsers"
winget install --silent Google.Chrome
winget install --silent Mozilla.Firefox
Write-Host -ForegroundColor Blue "Setting default browser"
choco install -y setdefaultbrowser
do {
    $browserChoice = Read-Host -Prompt "Which browser do you want to set as default? (firefox, chrome, none): "
}
while ($browserChoice -ne "firefox" -and $browserChoice -ne "chrome" -and $browserChoice -ne "none")
if ($browserChoice -eq "firefox") {
    SetDefaultBrowser.exe HKLM Firefox-308046B0AF4A39CB
} elseif ($browserChoice -eq "chrome") {
    SetDefaultBrowser.exe chrome
}
Write-Host -ForegroundColor Green "Default browser set to $browserChoice"
Write-Host -ForegroundColor Green "Browsers installed"

# Utils
Write-Host -ForegroundColor Blue "Installing utils"
winget install --silent 7zip.7zip
winget install --silent Microsoft.PowerToys
winget install --silent gerardog.gsudo
winget install --silent VideoLAN.VLC
winget install --silent Microsoft.VisualStudioCode --override '/SILENT /mergetasks="!runcode,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath"'
## Windows Terminal
winget install --silent Microsoft.WindowsTerminal
$WindowsTerminalConfigFolder = "$env:LocalAppData\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
if (!(Test-Path $WindowsTerminalConfigFolder)) {
		mkdir.exe -p $WindowsTerminalConfigFolder
}
New-Item -ItemType SymbolicLink -Path "$WindowsTerminalConfigFolder\settings.json" -Target "$env:DOTFILES\win\config\WindowsTerminal\settings.json"
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

# Fonts
Write-Host -ForegroundColor Blue "Installing fonts"
choco install -y nerd-fonts-jetbrainsmono nerd-fonts-iosevka nerd-fonts-cascadiacode nerdfont-hack nerd-fonts-ubuntumono nerd-fonts-victormono
Write-Host -ForegroundColor Green "Fonts installed"

# Git config
Write-Host -ForegroundColor Blue "Configuring Git"
choco install -y delta
## Symlink .gitconfig
if (Test-Path -Path "$env:USERPROFILE\.gitconfig") {
		Remove-Item -Path "$env:USERPROFILE\.gitconfig" -Force
}
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.gitconfig" -Target "$env:DOTFILES\common\git\.gitconfig"
$GitUserName = Read-Host -Prompt "Enter your Git user name ";
$GitUserEmail = Read-Host -Prompt "Enter your Git user email ";
Remove-Item -Path "$env:USERPROFILE\.gitconfig.local" -Force
@"
[user]
	name = $GitUserName
	email = $GitUserEmail
"@ | Out-File -Encoding "utf8NoBOM" -FilePath "$($ENV:USERPROFILE)\.gitconfig.local"
# TODO: Enable signing with SSH key (https://github.com/Okeanos/dotfiles-windows/blob/8cba8eda06ee01bc5a174f61656a7bc7cb798e4d/bootstrap.ps1#L62-L89)
## Set pager
$env:PAGER = "less"
[Environment]::SetEnvironmentVariable("PAGER", "less", "User")
Write-Host -ForegroundColor Green "Git configured"

# Install and configure PowerShell
Write-Host -ForegroundColor Blue "Installing PowerShell"
winget install --silent Microsoft.PowerShell
winget install --silent Starship.Starship
choco install -y zoxide
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
refreshenv
pwsh -c "Install-Module -Name posh-git -Scope CurrentUser -Force"
pwsh -c "Install-Module -Name Terminal-Icons -Scope CurrentUser -Force"
pwsh -c "Install-Module -Name DockerCompletion -Scope CurrentUser -Force"
pwsh -c "Install-Module -Name PSFzf -Scope CurrentUser -Force"
pwsh -c "Install-Module -Name PSReadLine -Scope CurrentUser -AllowPrerelease -Force"
pwsh -c "Install-Module -Name CompletionPredictor -Scope CurrentUser -AllowPrerelease -Force"
pwsh -c "Install-Module -Name ChangeScreenResolution -Scope CurrentUser -Force"
# Symlink profile.ps1
$PowerShellFolder = "$env:USERPROFILE\Documents\PowerShell"
mkdir.exe -p $PowerShellFolder
LinkFiles "$env:DOTFILES\win\config\PowerShell" $PowerShellFolder
# Symlink Starship config
$StarshipFolder = "$env:USERPROFILE\.config\"
mkdir.exe -p $StarshipFolder
New-Item -ItemType SymbolicLink -Path "$StarshipFolder\starship.toml" -Target "$env:DOTFILES\common\starship\starship.toml"
Write-Host -ForegroundColor Green "PowerShell installed"

# Variables
# Ensure that Unix tools have a consistent and predictable HOME directory; important if a network drive is used as pseudo-home
[Environment]::SetEnvironmentVariable("HOME", "%UserProfile%", 'User')
# Ensure that Unix tools have a consistent and predictable USER variable available; important for SSH for example
[Environment]::SetEnvironmentVariable("USER", "$Env:UserName", 'User')

exit 0