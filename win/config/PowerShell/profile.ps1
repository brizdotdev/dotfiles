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

# Yazi (https://yazi-rs.github.io/docs/quick-start)
function y {
	$tmp = (New-TemporaryFile).FullName
	yazi.exe @args --cwd-file="$tmp"
	$cwd = Get-Content -Path $tmp -Encoding UTF8
	if ($cwd -and $cwd -ne $PWD.Path -and (Test-Path -LiteralPath $cwd -PathType Container)) {
		Set-Location -LiteralPath (Resolve-Path -LiteralPath $cwd).Path
	}
	Remove-Item -Path $tmp
}

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

if (Get-Command -Name "nvim" -ErrorAction SilentlyContinue) {
    Set-Alias -Name "v" -Value nvim
    Set-Alias -Name "vi" -Value nvim
    Set-Alias -Name "vim" -Value nvim
} elseif (Get-Command -Name "vim" -ErrorAction SilentlyContinue) {
    Set-Alias -Name "v" -Value vim
    Set-Alias -Name "vi" -Value vim
}
Set-Alias -Name "g" -Value git
Set-Alias -Name "ex" -Value explorer
Set-Alias -Name "lg" -Value lazygit
Set-Alias -Name "cat" -Value bat
Set-Alias -Name "mkdir" -Value mkdir.exe
Set-Alias -Name "ls" -Value eza

################################################################################
# PSReadLine
################################################################################
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
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
    Import-Module PSFzf
    Set-PsFzfOption -TabExpansion

    ################################################################################
    # Env
    ################################################################################
    $env:FZF_DEFAULT_OPTS = "--layout=reverse --multi --cycle"
    # https://github.com/ryanoasis/nerd-fonts/wiki/FAQ-and-Troubleshooting#less-settings
    $env:LESSUTFCHARDEF = "e000-f8ff:p,f0001-fffff:p"

    ## Exec profile.local.ps1 if it exists
    $LocalProfile = Join-Path $PSScriptRoot -ChildPath "profile.local.ps1"
    if (Test-Path $LocalProfile) {
        & $LocalProfile
    }

}

# TODO: CTT PowerShell profile