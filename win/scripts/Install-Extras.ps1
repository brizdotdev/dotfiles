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
$RegionToShare = YesNoPrompt "Install RegionToShare?"
$TwinkleTray = YesNoPrompt "Install TwinkleTray?"

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
    winget install --silent Microsoft.Sysinternals.ZoomIt
}

if ($RegionToShare -eq $True) {
    winget install --accept-package-agreements --accept-source-agreements 9N4066W2R5Q4
}

if ($TwinkleTray -eq $True)
{
    winget install --accept-package-agreements --accept-source-agreements xanderfrangos.twinkletray
}

Write-Host -ForegroundColor Green "Done installing extras"
exit 0
