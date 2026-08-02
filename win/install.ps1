################################################################################
# Setup script for my dotfiles
################################################################################

param(
    [switch]$Reconfigure
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$answersPath = "$PSScriptRoot\install.answers.json"

$configMap = @(
    [PSCustomObject]@{
        Name = "Base"
        Preselected = $True
        Configs = @(
            "$PSScriptRoot\winget\developer-mode.winget"
            "$PSScriptRoot\winget\powershell.winget"
            "$PSScriptRoot\winget\windows-settings.winget"
            "$PSScriptRoot\winget\windows-settings-personalisation.winget"
            "$PSScriptRoot\winget\windows-settings-privacy.winget"
            "$PSScriptRoot\winget\windows-services.winget"
            "$PSScriptRoot\winget\power-plan.winget"
            "$PSScriptRoot\winget\browsers.winget"
            # "$PSScriptRoot\winget\powertoys.winget" # TODO: Fix this hanging
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
        )
        Scripts = @()
    }
    [PSCustomObject]@{
        Name = "Gaming"
        Configs = @(
            "$PSScriptRoot\winget\gaming.winget"
        )
        Scripts = @()
    }
    [PSCustomObject]@{
        Name = "Remove Teams and OneDrive"
        Preselected = $True
        Configs = @(
            "$PSScriptRoot\winget\remove-teams-onedrive.winget"
        )
        Scripts = @()
    }
)

$extras = @{
    "FFMPEG" = "Gyan.FFmpeg"
    "Flameshot" = "flameshot"
    "LibreOffice" = "TheDocumentFoundation.LibreOffice"
    "MullvadVPN" = "MullvadVPN.MullvadVPN"
    "OBS" = "OBSProject.OBSStudio"
    "Obsidian" = "Obsidian.Obsidian"
    "RegionToShare" = "9N4066W2R5Q4"
    "ScreenToGif" = "NickeManarin.ScreenToGif"
    "Spotify" = "9NCBCSZSJRSB"
    "TwinkleTray" = "xanderfrangos.twinkletray"
    "WinDirStat" = "WinDirStat.WinDirStat"
    "WireGuard" = "WireGuard.WireGuard"
}

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

function Initialize-Requirements {
    # Ensure that Gum is installed
    if (-not (Get-Command "gum" -ErrorAction SilentlyContinue)) {
        winget install --silent --accept-source-agreements --accept-package-agreements --source winget --no-upgrade charmbracelet.gum
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    }

    Write-Host -ForegroundColor Blue "Enabling WinGet configuration..."
    winget install --silent --accept-source-agreements --accept-package-agreements --source winget Microsoft.Dsc.Preview | Out-Null
    winget install --silent --no-upgrade --source winget Microsoft.VCRedist.2015+.x64 | Out-Null
    winget configure --enable
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

function Get-Inputs {
    param (
        [object]$Saved
    )

    if ($null -ne $Saved) {
        Write-Host -ForegroundColor Cyan "Using saved answers."
        return $Saved
    }

    $configOptions = @($configMap.Name)
    $preselectedOptions = ($configMap | Where-Object { $_.PSObject.Properties['Preselected'] -and $_.Preselected -eq $True } | Select-Object -ExpandProperty Name) -join ','
    $selectedOptionsRaw = gum choose --header "Select configuration to apply" --no-limit --selected "$preselectedOptions" $configOptions
    $selectedExtrasRaw = gum choose --header "Select extras to install" --no-limit --height ($extras.Count + 2) $extras.Keys
    $ImportSSHKey = $False
    gum confirm "Import SSH Key from Yubikey?"; if ($LASTEXITCODE -eq 0) {
        $ImportSSHKey = $True
    }
    $GitUserEmail = gum input --header "Git email address"
    $GitConfigureSigning = $False
    gum confirm "Configure commit signing?"; if ($LASTEXITCODE -eq 0) {
        $GitConfigureSigning = $True
    }
    $SetDefaultBrowser = $False
    $Browser = $null
    gum confirm "Set a default browser?"; if ($LASTEXITCODE -eq 0) {
        $SetDefaultBrowser = $True
        $Browser = gum choose --header "Select default browser" @('Firefox', 'Chrome', 'LibreWolf')
    }
    $CodingAgent = gum input --header "Coding agent (e.g. claude, opencode)" --placeholder "claude"

    $selectedOptions = if ($selectedOptionsRaw) { @($selectedOptionsRaw -split "`n" | Where-Object { $_ }) } else { @() }
    $selectedExtras = if ($selectedExtrasRaw) { @($selectedExtrasRaw -split "`n" | Where-Object { $_ }) } else { @() }

    $result = [PSCustomObject]@{
        SelectedOptions = $selectedOptions
        SelectedExtras = $selectedExtras
        ImportSSHKey = $ImportSSHKey
        GitUserEmail = $GitUserEmail
        GitConfigureSigning = $GitConfigureSigning
        SetDefaultBrowser = $SetDefaultBrowser
        Browser = $Browser
        CodingAgent = $CodingAgent
    }

    $result | ConvertTo-Json -Depth 5 | Set-Content -Path $answersPath
    Write-Host -ForegroundColor Cyan "Saved answers to $answersPath"
    return $result
}

function Install-SelectedItems {
    param (
        [object[]]$SelectedOptions,
        [object[]]$SelectedExtras
    )

    foreach ($option in $SelectedOptions) {
        $selectedConfig = $configMap | Where-Object { $_.Name -eq $option }
        foreach ($config in $selectedConfig.Configs) {
            Write-Host -ForegroundColor Blue "Installing configuration: $config"
            winget configure --suppress-initial-details --accept-configuration-agreements --disable-interactivity $config
            Write-Host -ForegroundColor Green "Configuration installed: $config"
        }
        foreach ($script in $selectedConfig.Scripts) {
            if ($script -match 'Remove-Bloatware') {
                $launchArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$script)
                if (-not $isAdmin) {
                    Write-Host -ForegroundColor Cyan "Not elevated; relaunching $script via UAC (Windows PowerShell 5.1)..."
                    $p = Start-Process powershell.exe -Verb RunAs -PassThru -Wait -ArgumentList $launchArgs
                }
                elseif ($PSVersionTable.PSEdition -ne 'Desktop') {
                    Write-Host -ForegroundColor Cyan "DISM requires Windows PowerShell 5.1; relaunching $script..."
                    & powershell.exe @launchArgs
                }
                else {
                    & $script
                }
                continue
            }
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

$saved = $null
if (-not $Reconfigure -and (Test-Path $answersPath)) {
    $saved = Get-Content $answersPath -Raw | ConvertFrom-Json
    Write-Host -ForegroundColor Cyan "Loaded saved answers from $answersPath"
}

$inputs = Get-Inputs -Saved $saved

$extrasLine = if ($inputs.SelectedExtras) { ($inputs.SelectedExtras | ForEach-Object { "- $_" }) -join "`n" } else { "- (none)" }
$browserLine = if ($inputs.SetDefaultBrowser) { "- $($inputs.Browser)" } else { "- (not set)" }
$agentLine = if ($inputs.CodingAgent) { "- $($inputs.CodingAgent)" } else { "- (none)" }
$optionsLine = ($inputs.SelectedOptions | ForEach-Object { "- $_" }) -join "`n"

$summary = @(
    "### Configuration",
    $optionsLine
    "### Extras",
    $extrasLine
    "### Git",
    "- Email: $($inputs.GitUserEmail)",
    "- Commit signing: $($inputs.GitConfigureSigning)"
    "### SSH",
    "- Import from Yubikey: $($inputs.ImportSSHKey)"
    "### Default browser",
    $browserLine
    "### Coding agent",
    $agentLine
) -join "`n`n"

gum format $summary
gum confirm "Proceed with these settings?"; if ($LASTEXITCODE -ne 0) {
    Write-Host -ForegroundColor Yellow "Aborted."
    exit 1
}

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
