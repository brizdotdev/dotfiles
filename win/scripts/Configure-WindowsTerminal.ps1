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
$WindowsTerminalConfigFile = Join-Path -Path $WindowsTerminalConfigFolder -ChildPath "settings.json"
if (Test-Path $WindowsTerminalConfigFile) {
    Remove-Item $WindowsTerminalConfigFile
}
New-Item -ItemType SymbolicLink -Path "$WindowsTerminalConfigFile" -Target "$env:DOTFILES\win\config\WindowsTerminal\settings.json"

Write-Host -ForegroundColor Green "Done configuring Windows Terminal"
Write-Host -ForegroundColor Green "You may need to restart for the changes to take effect"
exit 0