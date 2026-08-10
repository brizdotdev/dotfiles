################################################################################
# Setup script for my dotfiles
#
# The configs are split by security context and applied in two passes:
#
#   Machine pass  *.machine.winget  - run from a shell ALREADY elevated as an
#                                     admin account. A fully elevated WinGet
#                                     needs no elevated child process, so no
#                                     cross-user remoting happens.
#   User pass     *.user.winget     - run as yourself, NOT elevated. These
#                                     configs contain no elevated units, so
#                                     WinGet never spawns a child under another
#                                     account and never re-secures state under
#                                     your profile.
#
# Never run a pass in the wrong context: HKCU and profile paths resolve against
# whoever owns the process, and WinGet's cross-user elevation corrupts its own
# configuration database under the caller's profile.
#
# Order:  -Pass Answers (as you)  ->  -Pass Machine (as admin)  ->  -Pass User (as you)
################################################################################

param(
    [switch]$Reconfigure,
    [ValidateSet('Answers', 'Machine', 'User')]
    [string]$Pass
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$answersPath = "$PSScriptRoot\install.answers.json"

# Config names are base names; each resolves to <name>.machine.winget and/or
# <name>.user.winget. A missing variant just means that config has no units of
# that security context.
$configMap = @(
    [PSCustomObject]@{
        Name = "Base"
        Preselected = $True
        Configs = @(
            "developer-mode"
            "powershell"
            "windows-settings"
            "windows-services"
            "power-plan"
            "browsers"
            # "powertoys" # TODO: Fix this hanging
            "utils"
            "vscode"
            "windows-terminal-settings"
            "winget-settings"
            "windows-settings-personalisation"
            "windows-settings-privacy"
        )
        MachineScripts = @(
            "$PSScriptRoot\scripts\Remove-Bloatware.ps1"
        )
        UserScripts = @()
    }
    [PSCustomObject]@{
        Name = "Dev"
        Configs = @(
            "dev"
            "git"
            "fonts"
            "neovim"
        )
        MachineScripts = @()
        UserScripts = @()
    }
    [PSCustomObject]@{
        Name = "Gaming"
        Configs = @(
            "gaming"
        )
        MachineScripts = @()
        UserScripts = @()
    }
    [PSCustomObject]@{
        Name = "Remove Teams and OneDrive"
        Preselected = $True
        Configs = @(
            "remove-teams-onedrive"
        )
        MachineScripts = @()
        UserScripts = @()
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

if (-not $Pass) {
    $Pass = if ($isAdmin) { 'Machine' } else { 'User' }
    Write-Host -ForegroundColor Cyan "No -Pass given; running the $Pass pass (elevated: $isAdmin)."
}

function Assert-PassContext {
    if ($Pass -eq 'Machine' -and -not $isAdmin) {
        throw "The Machine pass must run from an elevated shell. Open PowerShell as administrator (entering your admin account's credentials at the UAC prompt) and re-run with -Pass Machine."
    }
    if ($Pass -ne 'Machine' -and $isAdmin) {
        throw "The $Pass pass must run as your own user in a NON-elevated shell. Running it elevated as another account writes HKCU values and profile files to that account instead of yours."
    }
}

function Assert-WinGetSource {
    # Microsoft.WinGet/Package units need the Microsoft.Winget.Source index package
    # registered for the account running them. MSIX deployment refuses to register a
    # package for an account with no interactive logon session (0x80073D19,
    # ERROR_DEPLOYMENT_BLOCKED_BY_USER_LOG_OFF) - which is what a UAC elevation with
    # another account's credentials produces: a token in your session, not a session.
    Write-Host -ForegroundColor Blue "Verifying WinGet source is usable for $($env:USERNAME)..."
    winget source update --name winget 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw @"
WinGet's package source could not be updated for '$($env:USERNAME)'.

If this failed with 0x80073D19, this account has no interactive logon session, so
Windows will not deploy MSIX packages for it. Elevating from another user's session
is not enough.

Fix: sign in to Windows directly as this account once, run 'winget source update'
there, then sign back in as your normal user and retry the Machine pass (or simply
run the Machine pass while signed in as this account).
"@
    }
    Write-Host -ForegroundColor Green "WinGet source OK"
}

function Initialize-Requirements {
    param([switch]$IncludeGum)

    if ($IncludeGum -and -not (Get-Command "gum" -ErrorAction SilentlyContinue)) {
        winget install --silent --accept-source-agreements --accept-package-agreements --source winget --no-upgrade charmbracelet.gum
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    }

    Write-Host -ForegroundColor Blue "Enabling WinGet configuration..."
    # Registers WinGet and DSC for whichever account runs this pass. The machine
    # pass needs its own registration: these are per-user MSIX registrations, and
    # an account without them fails process init with 0xC0000142.
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

function Get-SavedAnswers {
    if (-not (Test-Path $answersPath)) {
        throw "No saved answers at $answersPath. Run '.\install.ps1 -Pass Answers' as your own user first."
    }
    return Get-Content $answersPath -Raw | ConvertFrom-Json
}

function Invoke-ConfigPass {
    param (
        [ValidateSet('machine', 'user')]
        [string]$Context,
        [object[]]$SelectedOptions
    )

    foreach ($option in $SelectedOptions) {
        $selectedConfig = $configMap | Where-Object { $_.Name -eq $option }
        foreach ($base in $selectedConfig.Configs) {
            $path = "$PSScriptRoot\winget\$base.$Context.winget"
            # A missing variant means this config has no units of this context.
            if (-not (Test-Path $path)) { continue }
            Write-Host -ForegroundColor Blue "Applying [$Context] $base"
            # No --disable-interactivity: it would suppress prompts WinGet may
            # legitimately need (package installers requesting their own UAC).
            winget configure --suppress-initial-details --accept-configuration-agreements $path
            Write-Host -ForegroundColor Green "Applied [$Context] $base"
        }
    }
}

function Invoke-PassScripts {
    param (
        [ValidateSet('MachineScripts', 'UserScripts')]
        [string]$Property,
        [object[]]$SelectedOptions
    )

    foreach ($option in $SelectedOptions) {
        $selectedConfig = $configMap | Where-Object { $_.Name -eq $option }
        foreach ($script in $selectedConfig.$Property) {
            Write-Host -ForegroundColor Blue "Running $script"
            if ($script -match 'Remove-Bloatware' -and $PSVersionTable.PSEdition -ne 'Desktop') {
                # DISM cmdlets require Windows PowerShell 5.1
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script
                continue
            }
            & $script
        }
    }
}

function Install-Extras {
    param([object[]]$SelectedExtras)

    foreach ($extra in $SelectedExtras) {
        $packageId = $extras[$extra]
        # Plain `winget install` elevation is the installer's own UAC prompt, which
        # is unrelated to `winget configure` remoting and is safe from here.
        winget install --accept-package-agreements --accept-source-agreements $packageId
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

Assert-PassContext

switch ($Pass) {
    'Answers' {
        Initialize-Requirements -IncludeGum
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
        Write-Host -ForegroundColor Green "Answers saved. Next: run '.\install.ps1 -Pass Machine' from an elevated admin shell, then '.\install.ps1 -Pass User' here."
    }

    'Machine' {
        Initialize-Requirements
        Assert-WinGetSource
        $inputs = Get-SavedAnswers
        Invoke-ConfigPass -Context 'machine' -SelectedOptions $inputs.SelectedOptions
        Invoke-PassScripts -Property 'MachineScripts' -SelectedOptions $inputs.SelectedOptions
        Write-Host -ForegroundColor Green "Machine pass done. Next: run '.\install.ps1 -Pass User' as your own user."
    }

    'User' {
        Initialize-Requirements -IncludeGum
        $saved = $null
        if (-not $Reconfigure -and (Test-Path $answersPath)) {
            $saved = Get-Content $answersPath -Raw | ConvertFrom-Json
        }
        $inputs = Get-Inputs -Saved $saved

        Invoke-ConfigPass -Context 'user' -SelectedOptions $inputs.SelectedOptions
        Invoke-PassScripts -Property 'UserScripts' -SelectedOptions $inputs.SelectedOptions
        Install-Extras -SelectedExtras $inputs.SelectedExtras
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
        Write-Host -ForegroundColor Green "User pass done!"
    }
}

Read-Host
