# Helper functions
$HelperPath = Join-Path -Path $PSScriptRoot -ChildPath "helpers"
Get-ChildItem -Path $HelperPath -Filter "*.ps1" | ForEach-Object {
    . $_.FullName
}


Write-Host -ForegroundColor Blue "Installing Extras"
Write-Host -ForegroundColor Blue ""

$OBS = YesNoPrompt "Install OBS Studio?"
$Spotify = YesNoPrompt "Install Spotify?"
$LibreOffice = YesNoPrompt "Install LibreOffice?"
$WireGuard = YesNoPrompt "Install WireGuard?"
$Obsidian = YesNoPrompt "Install Obsidian?"
$WinDirStat = YesNoPrompt "Install WinDirStat?"
$ScreenToGif = YesNoPrompt "Install ScreenToGif?"
$FFMPEG = YesNoPrompt "Install ffmpeg?"
$LightShot = YesNoPrompt "Install LightShot?"
$ZoomIt = YesNoPrompt "Install ZoomIt?"
$FancyWM = YesNoPrompt "Install FancyWM?"
$RegionToShare = YesNoPrompt "Install RegionToShare?"

if ($OBS -eq $True) {
    winget install --silent OBSProject.OBSStudio
}

if ($Spotify -eq $True) {
    winget install --silent 9NCBCSZSJRSB
}

if ($LibreOffice -eq $True) {
    winget install --silent TheDocumentFoundation.LibreOffice
}

if ($WireGuard -eq $True) {
    winget install --silent WireGuard.WireGuard
}

if ($Obsidian -eq $True) {
    winget install --silent Obsidian.Obsidian
}

if ($WinDirStat -eq $True) {
    winget install --silent WinDirStat.WinDirStat
}

if ($ScreenToGif -eq $True) {
    winget install --silent NickeManarin.ScreenToGif
}

if ($FFMPEG -eq $True) {
    winget install --silent Gyan.FFmpeg
}

if ($LightShot -eq $True) {
    winget install --silent Skillbrains.Lightshot
}

if ($ZoomIt -eq $True) {
    choco install -y zoomit
}

if ($FancyWM -eq $True) {
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

if ($RegionToShare -eq $True) {
    winget install --accept-package-agreements --accept-source-agreements 9N4066W2R5Q4
}

Write-Host -ForegroundColor Green "Done installing extras"
exit 0
