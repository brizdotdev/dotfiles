#Requires -RunAsAdministrator
################################################################################
# Setup script for my dotfiles
################################################################################

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$configMap = @(
    [PSCustomObject]@{
        Name = "Base"
        Preselected = $True
        Configs = @(
            "$PSScriptRoot\winget\powershell.winget"
            "$PSScriptRoot\winget\windows-settings.winget"
            "$PSScriptRoot\winget\windows-settings-personalisation.winget"
            "$PSScriptRoot\winget\windows-settings-privacy.winget"
            "$PSScriptRoot\winget\power-plan.winget"
            "$PSScriptRoot\winget\browsers.winget"
            "$PSScriptRoot\winget\powertoys.winget"
            "$PSScriptRoot\winget\utils.winget"
            "$PSScriptRoot\winget\vscode.winget"
            "$PSScriptRoot\winget\windows-terminal-settings.winget"
            "$PSScriptRoot\winget\winget-settings.winget"
        )
        Scripts = @(
            "$PSScriptRoot\scripts\Remove-Bloatware.ps1"
        )
    }
    [PSCustomObject]@{
        Name = "Dev"
        Configs = @(
            "$PSScriptRoot\winget\dev.winget"
            "$PSScriptRoot\winget\git.winget"
            "$PSScriptRoot\winget\fonts.winget"
            "$PSScriptRoot\winget\neovim.winget"
            "$PSScriptRoot\winget\sandbox.winget"
        )
    }
    [PSCustomObject]@{
        Name = "Gaming"
        Configs = @(
            "$PSScriptRoot\winget\gaming.winget"
        )
    }
    [PSCustomObject]@{
        Name = "Remove Teams and OneDrive"
        Preselected = $True
        Configs = @(
            "$PSScriptRoot\winget\remove-teams-onedrive.winget"
        )
    }
)

$extras = @{
    "OBS" = "OBSProject.OBSStudio"
    "Spotify" = "9NCBCSZSJRSB"
    "LibreOffice" = "TheDocumentFoundation.LibreOffice"
    "WireGuard" = "WireGuard.WireGuard"
    "Obsidian" = "Obsidian.Obsidian"
    "WinDirStat" = "WinDirStat.WinDirStat"
    "ScreenToGif" = "NickeManarin.ScreenToGif"
    "FFMPEG" = "Gyan.FFmpeg"
    "Flameshot" = "flameshot"
    "RegionToShare" = "9N4066W2R5Q4"
    "TwinkleTray" = "xanderfrangos.twinkletray"
}

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

function Initialize-Requirements {
    # Ensure that Gum is installed
    if (-not (Get-Command "gum" -ErrorAction SilentlyContinue)) {
        winget install --silent --accept-source-agreements --accept-package-agreements --source winget --no-upgrade charmbracelet.gum
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    }

    Write-Host -ForegroundColor Blue "Enabling WinGet configuration..."
    winget install --silent --scope user --accept-source-agreements --accept-package-agreements --source winget Microsoft.Dsc.Preview
    winget install --silent --no-upgrade --source winget Microsoft.VCRedist.2015+.x64
    winget install --silent --source winget OpenDsc.Resources
    winget configure --enable --disable-interactivity --accept-source-agreements
    Write-Host -ForegroundColor Green "WinGet configuration enabled"

    if ($isAdmin) {
        if ($null -eq (Get-ComputerRestorePoint)) {
            Enable-ComputerRestore -Drive "$env:SystemDrive\"
        }
    }
    else {
        Write-Warning "Skipping System Restore setup because the script is not running as Administrator."
    }
}

function Get-Inputs{
    $configOptions = @($configMap.Name)
    $preselectedOptions = ($configMap | Where-Object { $_.Preselected -eq $True } | Select-Object -ExpandProperty Name) -join ','
    $selectedOptions = gum choose --header "Select configuration to apply" --no-limit --selected "$preselectedOptions" $configOptions
    $selectedExtras = gum choose --header "Select extras to install" --no-limit $extras.Keys
    $ImportSSHKey = $False
    if (gum confirm "Import SSH Key from Yubikey?") {
        $ImportSSHKey = $True
    }
    $GitUserEmail = gum input --header "Git email address"
    $GitConfigureSigning = $False
    if (gum confirm "Configure commit signing?") {
        $GitConfigureSigning = $True
    }
    $SetDefaultBrowser = $False
    $Browser = $null
    if (gum confirm "Set a default browser?") {
        $SetDefaultBrowser = $True
        $Browser = gum choose --header "Select default browser" Firefox Chrome LibreWolf
    }
    $CodingAgent = gum input --header "Coding agent (e.g. claude, opencode)" --placeholder "claude"
    return [PSCustomObject]@{
        SelectedOptions = $selectedOptions
        SelectedExtras = $selectedExtras
        ImportSSHKey = $ImportSSHKey
        GitUserEmail = $GitUserEmail
        GitConfigureSigning = $GitConfigureSigning
        SetDefaultBrowser = $SetDefaultBrowser
        Browser = $Browser
        CodingAgent = $CodingAgent
    }
}

function Install-SelectedItems {
    param (
        [object[]]$SelectedOptions,
        [object[]]$SelectedExtras
    )

    foreach ($option in $SelectedOptions) {
        $selectedConfig = $configMap | Where-Object { $_.Name -eq $option }
        foreach ($config in $selectedConfig.Configs) {
            winget configure --suppress-initial-details --accept-configuration-agreements --disable-interactivity $config
        }
        foreach ($script in $selectedConfig.Scripts) {
            & $script
        }
    }

    foreach ($extra in $SelectedExtras) {
        $packageId = $extras[$extra]
        winget install --accept-package-agreements --accept-source-agreements --disable-interactivity $packageId
    }
}

function Set-GitConfiguration {
    param (
        [string]$GitUserEmail,
        [bool]$GitConfigureSigning
    )

    if ($GitUserEmail -ne "") {
        git config --file "$HOME/.gitconfig.local" user.email $GitUserEmail
    }
    if ($GitConfigureSigning) {
        git config --file "$HOME/.gitconfig.local" commit.gpgsign true
        git config --file "$HOME/.gitconfig.local" user.signingkey ~/.ssh/id_ed25519_sk_rk_Default
    }
}

$env:DOTFILES_ROOT = Split-Path -Parent $PSScriptRoot
Initialize-Requirements
$inputs = Get-Inputs
Install-SelectedItems -SelectedOptions $inputs.SelectedOptions -SelectedExtras $inputs.SelectedExtras
Set-GitConfiguration -GitUserEmail $inputs.GitUserEmail -GitConfigureSigning $inputs.GitConfigureSigning
if ($inputs.ImportSSHKey) {
    & "$PSScriptRoot\scripts\Import-SSHKey.ps1"
}
if ($inputs.SetDefaultBrowser) {
    & "$PSScriptRoot\scripts\Set-DefaultBrowser.ps1" -Browser $inputs.Browser
}
if ($inputs.CodingAgent -ne "") {
    [Environment]::SetEnvironmentVariable("CODING_AGENT", $inputs.CodingAgent, "User")
    $env:CODING_AGENT = $inputs.CodingAgent
}
Write-Host -ForegroundColor Green "Done!"
Read-Host
