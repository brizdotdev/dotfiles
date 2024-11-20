################################################################################
# Utility Functions
################################################################################
function history {
    Get-Content (Get-PSReadlineOption).HistorySavePath
}

function Reload-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function which($command) {
    Get-Command -Name $command -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

# Change the screen resolution to 1920x1080
# Useful for when I need to screenshare because my main monitor is 3440x1440
function fullhd {
    Import-Module ChangeScreenResolution
    Set-ScreenResolution -Width 1920 -Height 1080
    Remove-Module ChangeScreenResolution
}

# Restore resolution to 3440x1440
function uw {
    Import-Module ChangeScreenResolution
    Set-ScreenResolution -Width 3440 -Height 1440
    Remove-Module ChangeScreenResolution
}

function Copy-Pwd {
    $(Get-Location).Path | clip.exe
}

function fzf-vim() {
    vim $(fzf)
}

################################################################################
# Import Modules
################################################################################
Import-Module Microsoft.PowerShell.Utility
Import-Module Microsoft.PowerShell.Management

################################################################################
# Remove stupid aliases
################################################################################
Remove-Item alias:history -Force
Remove-Item alias:ls -Force
Remove-Item alias:sl -Force
Remove-Item alias:rm -Force
Remove-Item alias:sort -Force
Remove-Item alias:cat -Force
Remove-Item alias:mv -Force
Remove-Item alias:echo -Force

################################################################################
# Aliases
################################################################################

Set-Alias -Name "v" -Value nvim
Set-Alias -Name "vim" -Value nvim
Set-Alias -Name "g" -Value git
Set-Alias -Name "ex" -Value explorer
Set-Alias -Name "lg" -Value lazygit
Set-Alias -Name "cat" -Value bat
Set-Alias -Name "mkdir" -Value mkdir.exe
Set-Alias -Name "ls" -Value lsd

################################################################################
# PSReadLine
################################################################################
Import-Module PSReadLine
Import-Module PSFzf
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PsFzfOption -TabExpansion
Set-PSReadLineOption -EditMode Vi
$OnViModeChange = [scriptblock] {
    if ($args[0] -eq 'Command') {
        # Set the cursor to a blinking block.
        Write-Host -NoNewLine "`e[2 q"
    }
    else {
        # Set the cursor to a blinking line.
        Write-Host -NoNewLine "`e[5 q"
    }
}
Set-PSReadLineOption -ViModeIndicator Script -ViModeChangeHandler $OnViModeChange
Set-PSReadLineKeyHandler -Key Alt+Enter -Function AcceptNextSuggestionWord
Set-PSReadLineKeyHandler -Key F2 -Function SwitchPredictionView
Set-PSReadlineKeyHandler -Chord CTRL+Tab -Function TabCompleteNext

################################################################################
# Startup
################################################################################

# Set encoding to UTF-8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

function Invoke-Starship-TransientFunction {
    &starship module character
}

Invoke-Expression (&starship init powershell)

Invoke-Expression (& { (zoxide init powershell | Out-String) })

# fastfetch

$null = Register-EngineEvent -SourceIdentifier 'PowerShell.OnIdle' -MaxTriggerCount 1 -Action {

    ################################################################################
    # Imports
    ################################################################################
    Import-Module posh-git
    $GitPromptSettings.EnableFileStatus = $false
    Import-Module DockerCompletion
    Import-Module CompletionPredictor

    ################################################################################
    # Env
    ################################################################################
    $env:FZF_DEFAULT_OPTS = "--layout=reverse --multi --cycle"

    ## Exec profile.local.ps1 if it exists
    $LocalProfile = Join-Path $PSScriptRoot -ChildPath "profile.local.ps1"
    if (Test-Path $LocalProfile) {
        & $LocalProfile
    }

}