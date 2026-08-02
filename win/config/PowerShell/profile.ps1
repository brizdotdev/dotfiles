################################################################################
# Utility Functions
################################################################################
function Test-InteractiveShell {
    try {
        return $Host.Name -eq 'ConsoleHost' -and
        -not [Console]::IsInputRedirected -and
        -not [Console]::IsOutputRedirected
    }
    catch {
        return $false
    }
}
$isInteractiveShell = Test-InteractiveShell

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

function Test-Command {
    param([Parameter(Mandatory)][string]$Name)
    $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function pkill {
    param([Parameter(Mandatory)][string]$Name)
    Get-Process -Name $Name -ErrorAction SilentlyContinue | Stop-Process -Force
}

function Resolve-Editor {
    if ($EDITOR_Override) {
        return $EDITOR_Override
    }

    foreach ($candidate in 'nvim', 'vim.exe', 'vi.exe', 'code', 'codium', 'notepad++', 'sublime_text') {
        if (Test-Command $candidate) {
            return $candidate
        }
    }

    return 'notepad'
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

$EDITOR = Resolve-Editor
Set-Alias -Name "v" -Value $EDITOR
Set-Alias -Name "vi" -Value $EDITOR
Set-Alias -Name "vim" -Value $EDITOR
Set-Alias -Name "g" -Value git
Set-Alias -Name "ex" -Value explorer
Set-Alias -Name "lg" -Value lazygit
Set-Alias -Name "mkdir" -Value mkdir.exe
if ($env:CODING_AGENT) {
    Set-Alias -Name "cc" -Value $env:CODING_AGENT
}

if (Test-Command bat) {
    function cat { bat @args }
}
else {
    function cat { Get-Content @args }
}

if (Test-Command eza) {
    function l { eza -1 --icons auto @args }
    function ll { eza -lh --icons auto @args }
    function la { eza -alh --icons auto @args }
    function ls { eza --icons auto @args }
}
else {
    function l { Get-ChildItem @args }
    function ll { Get-ChildItem -Force @args }
    function la { Get-ChildItem -Force @args }
    function ls { Get-ChildItem @args }
}

function pst { Get-Clipboard }

################################################################################
# PSReadLine
################################################################################
function Initialize-PSReadLine {

    if (-not $isInteractiveShell -or -not (Get-Module -ListAvailable -Name PSReadLine)) {
        return
    }

    $psreadlineOptions = @{
        PredictionSource              = 'HistoryAndPlugin'
        MaximumHistoryCount           = 10000
        HistoryNoDuplicates           = $true
        HistorySearchCursorMovesToEnd = $true
        EditMode                      = 'Vi'
        ViModeIndicator               = 'Cursor'
        BellStyle                     = 'None'
        TerminateOrphanedConsoleApps  = $true
    }
    Set-PSReadLineOption @psreadlineOptions

    Set-PSReadLineKeyHandler -Key Alt+Enter -Function AcceptNextSuggestionWord
    Set-PSReadLineKeyHandler -Key F2 -Function SwitchPredictionView
    Set-PSReadLineKeyHandler -Chord Ctrl+Tab -Function TabCompleteNext
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

    Set-PSReadLineOption -AddToHistoryHandler {
        param([string]$line)
        $line -notmatch '(?i)connectionstring'
    }
}
Initialize-PSReadLine

################################################################################
# Completions
################################################################################
function Register-CustomCompletion {
    if (-not $isInteractiveShell) {
        return
    }
    if (Test-Command dotnet) {
        Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
            param($wordToComplete, $commandAst, $cursorPosition)
            $null = $wordToComplete
            dotnet complete --position $cursorPosition $commandAst.ToString() |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }
    }
}

################################################################################
# Startup
################################################################################

# Set encoding to UTF-8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

if (Get-Command -Name "starship" -ErrorAction SilentlyContinue) {
    function Invoke-Starship-TransientFunction {
        &starship module character
    }
    Invoke-Expression (&starship init powershell)
}

if (Get-Command -Name "zoxide" -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
    Remove-Item alias:cd -Force
    Set-Alias -Name "cd" -Value "z"
}

if (Get-Command -Name "mise" -ErrorAction SilentlyContinue) {
    (&mise activate pwsh) | Out-String | Invoke-Expression
}

if (Get-Command -Name "gh" -ErrorAction SilentlyContinue) {
    gh completion -s powershell | Out-String | Invoke-Expression
}

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
