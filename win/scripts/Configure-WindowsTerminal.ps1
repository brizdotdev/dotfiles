#Requires -RunAsAdministrator
################################################################################
# Update Windows Terminal to latest version and configure it
# This is in a separate script because if Windows Terminal is running,
# It will not let you symlink over the settings.json
################################################################################
winget install --silent Microsoft.WindowsTerminal
$WindowsTerminalConfigFolder = "$env:LocalAppData\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
if (!(Test-Path $WindowsTerminalConfigFolder)) {
		mkdir.exe -p $WindowsTerminalConfigFolder
}
New-Item -ItemType SymbolicLink -Path "$WindowsTerminalConfigFolder\settings.json" -Target "$env:DOTFILES\win\config\WindowsTerminal\settings.json"