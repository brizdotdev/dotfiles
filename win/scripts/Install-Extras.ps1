$HelperPath = Join-Path -Path $PSScriptRoot -ChildPath "helpers"
foreach ($DotfilesHelper in $HelperPath) {
  . $DotfilesHelper;
};

Write-Host -ForegroundColor Blue "Installing Extras"

$ans = YesNoPrompt "Install OBS Studio?"
if ($ans -eq $True) {
    winget install --silent OBSProject.OBSStudio
}

$ans = YesNoPrompt "Install Spotify?"
if ($ans -eq $True) {
    winget install --silent 9NCBCSZSJRSB
}

$ans = YesNoPrompt "Install LibreOffice?"
if ($ans -eq $True) {
    winget install --silent TheDocumentFoundation.LibreOffice
}

$ans = YesNoPrompt "Install WireGuard?"
if ($ans -eq $True) {
    winget install --silent WireGuard.WireGuard
}

$ans = YesNoPrompt "Install Obsidian?"
if ($ans -eq $True) {
    winget install --silent Obsidian.Obsidian
}

$ans = YesNoPrompt "Install WinDirStat?"
if ($ans -eq $True) {
    winget install --silent WinDirStat.WinDirStat
}

$ans = YesNoPrompt "Install ScreenToGif?"
if ($ans -eq $True) {
    winget install --silent NickeManarin.ScreenToGif
}

$ans = YesNoPrompt "Install ffmpeg?"
if ($ans -eq $True) {
    choco install -y ffmpeg
}

$ans = YesNoPrompt "Install LightShot?"
if ($ans -eq $True) {
    winget install --silent Skillbrains.Lightshot
}

$ans = YesNoPrompt "Install ZoomIt?"
if ($ans -eq $True) {
    choco install -y zoomit
}

$ans = YesNoPrompt "Install FancyWM?"
if ($ans -eq $True) {
    winget install --silent --accept-package-agreements --accept-source-agreements 9P1741LKHQS9
    $FancyWMConfigFolder = "$env:LOCALAPPDATA\Packages\2203VeselinKaraganev.FancyWM_9x2ndwrcmyd2c\LocalCache\Roaming\FancyWM"
    mkdir.exe -p $FancyWMConfigFolder
    $FancyWMConfigPath = Join-Path -Path $FancyWMConfigFolder -ChildPath "settings.json"
    if (Test-Path $FancyWMConfigPath)
    {
        Remove-Item -Path $FancyWMConfigPath -Force
    }
    New-Item -ItemType SymbolicLink -Path $FancyWMConfigPath -Target "$env:DOTFILES\win\config\FancyWM\settings.json"
}

$ans = YesNoPrompt "Install RegionToShare?"
if ($ans -eq $True) {
    winget install --accept-package-agreements --accept-source-agreements 9N4066W2R5Q4
}

Write-Host -ForegroundColor Green "Done installing extras"
exit 0