################################################################################
# Utility Functions
################################################################################
${function:~} = { Set-Location ~ }

function Show-History {
    Get-Content (Get-PSReadlineOption).HistorySavePath
}
Set-Alias -Name "history" -Value Show-History -Option AllScope

function Reload-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}
Set-Alias -Name "refreshpath" -Value Reload-Path -Option AllScope

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
function ultrawide {
    Import-Module ChangeScreenResolution
    Set-ScreenResolution -Width 3440 -Height 1440
    Remove-Module ChangeScreenResolution
}
Set-Alias -Name "uw" -Value ultrawide -Option AllScope

function Copy-Pwd {
    $(pwd).Path | clip.exe
}

function tmux([string]$a) {
    wsl -- tmux -f /home/brizzz/.tmux-pwsh.conf $a
}

function fzf-vim()
{
    vim $(fzf)
}

## Exec profile.local.ps1 if it exists
$LocalProfile = Join-Path $PSScriptRoot -ChildPath "profile.local.ps1"
if (Test-Path $LocalProfile) {
    & $LocalProfile
}

################################################################################
# Aliases
################################################################################
# Correct PowerShell Aliases if tools are available (aliases win if set)
# WGet: Use `wget.exe` if available
if (Get-Command wget.exe -ErrorAction SilentlyContinue | Test-Path) {
    rm alias:wget -ErrorAction SilentlyContinue
}

# Directory Listing: Use `ls.exe` if available
if (Get-Command ls.exe -ErrorAction SilentlyContinue | Test-Path) {
    rm alias:ls -ErrorAction SilentlyContinue
    # Set `ls` to call `ls.exe` and always use --color
    ${function:ls} = { ls.exe --color @args }
    # List all files in long format
    ${function:l} = { ls -lF @args }
    # List all files in long format, including hidden files
    ${function:la} = { ls -laF @args }
    # List only directories
    ${function:lsd} = { Get-ChildItem -Directory -Force @args }
} else {
    # List all files, including hidden files
    ${function:la} = { ls -Force @args }
    # List only directories
    ${function:lsd} = { Get-ChildItem -Directory -Force @args }
}

# curl: Use `curl.exe` if available
if (Get-Command curl.exe -ErrorAction SilentlyContinue | Test-Path) {
    rm alias:curl -ErrorAction SilentlyContinue
    # Set `ls` to call `ls.exe` and always use --color
    ${function:curl} = { curl.exe @args }
    # Gzip-enabled `curl`
    ${function:gurl} = { curl --compressed @args }
} else {
    # Gzip-enabled `curl`
    ${function:gurl} = { curl -TransferEncoding GZip }
}
del alias:sl -Force
del alias:rm -Force
del alias:sort -Force
del alias:cat -Force

Set-Alias -Name "clear" -Value Clear-Host -Option AllScope
Set-Alias -Name "c" -Value Clear-Host -Option AllScope
Set-Alias -Name "v" -Value nvim
Set-Alias -Name "vi" -Value nvim
Set-Alias -Name "vim" -Value nvim
Set-Alias -Name "g" -Value git
Set-Alias -Name "got" -Value git
Set-Alias -Name "gut" -Value git
Set-Alias -Name "gat" -Value git
Set-Alias -Name "ex" -Value explorer
Set-Alias -Name "expl" -Value explorer
Set-Alias -Name "lg" -Value lazygit
Set-Alias -Name "t" -Value tmux
Set-Alias -Name "dck" -Value docker
Set-Alias -Name "dckr" -Value docker
Set-Alias -Name "dn" -Value dotnet
Set-Alias -Name "cat" -Value bat
Set-Alias -Name "z" -Value zoxide
Set-Alias -Name "mkdir" -Value mkdir.exe

################################################################################
# Imports
################################################################################
Import-Module posh-git
Import-Module DockerCompletion
Import-Module CompletionPredictor

################################################################################
# Env
################################################################################
$env:FZF_DEFAULT_OPTS = "--layout=reverse --multi --cycle"

################################################################################
# PSReadLine
################################################################################
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PsFzfOption -TabExpansion
Set-PSReadLineOption -EditMode Vi
Set-PSReadLineKeyHandler -Key Alt+Enter -Function AcceptNextSuggestionWord
Set-PSReadLineKeyHandler -Key F2 -Function SwitchPredictionView

################################################################################
# Startup
################################################################################

# Set encoding to UTF-8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

Invoke-Expression (& {
    $hook = if ($PSVersionTable.PSVersion.Major -lt 6) { 'prompt' } else { 'pwd' }
    (zoxide init --hook $hook powershell | Out-String)
})

function Invoke-Starship-TransientFunction {
    &starship module character
  }

Invoke-Expression (&starship init powershell)
