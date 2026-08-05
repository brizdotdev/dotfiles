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
# Cached shell integrations
################################################################################
# starship/zoxide/mise/gh each need an external process spawn to print their
# PowerShell integration script. Process creation is expensive on this machine
# (~64ms floor, Defender + MDE + DLP scan every spawn) and `mise` additionally
# does a periodic "new version available" network check that blocks for ~2s.
#
# Their output is static for a given binary, so cache it on disk and invalidate
# on the executable's size + mtime.
#
# Returns the path to a cached .ps1, or $null if the tool isn't installed. The
# CALLER must dot-source it at profile top level so definitions land in global
# scope.
$script:InitCacheDir = Join-Path $env:LOCALAPPDATA 'pwsh-init-cache'

function Get-CachedInitScript {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Generate
    )

    $cmd = Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1
    if (-not $cmd) { return $null }

    $exe = Get-Item -LiteralPath $cmd.Source -ErrorAction SilentlyContinue
    if (-not $exe) { return $null }
    # WinGet installs many tools as reparse-point links under WinGet\Links. Those
    # report Length 0 and their own mtime does not track the real binary, so
    # follow the link before stamping.
    if ($exe.LinkTarget) {
        $target = Get-Item -LiteralPath $exe.LinkTarget -ErrorAction SilentlyContinue
        if ($target) { $exe = $target }
    }

    $stamp = '{0:x}-{1:x}' -f $exe.Length, $exe.LastWriteTimeUtc.Ticks
    $cacheFile = Join-Path $script:InitCacheDir "$Name.$stamp.ps1"

    if (-not (Test-Path -LiteralPath $cacheFile)) {
        if (-not (Test-Path -LiteralPath $script:InitCacheDir)) {
            $null = New-Item -ItemType Directory -Path $script:InitCacheDir -Force
        }
        # Drop stale generations for this tool.
        Get-ChildItem -LiteralPath $script:InitCacheDir -Filter "$Name.*.ps1" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue

        # Join the raw output rather than piping to Out-String, which can wrap
        # long lines at the host width and corrupt the script.
        $text = @(& $Generate) -join [Environment]::NewLine
        if ([string]::IsNullOrWhiteSpace($text)) { return $null }

        # Write via a temp file so a shell killed mid-write can't leave a
        # truncated cache behind for every later shell to source.
        $tmp = "$cacheFile.$PID.tmp"
        Set-Content -LiteralPath $tmp -Value $text -Encoding utf8NoBOM
        Move-Item -LiteralPath $tmp -Destination $cacheFile -Force
    }

    return $cacheFile
}

################################################################################
# Remove stupid aliases
################################################################################
Remove-Item alias:cat -Force
Remove-Item alias:cp -Force
Remove-Item alias:echo -Force
Remove-Item alias:history -Force
Remove-Item alias:ls -Force
Remove-Item alias:mv -Force
Remove-Item alias:rm -Force
Remove-Item alias:sl -Force
Remove-Item alias:sort -Force

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
function Test-CommandLineResolves {
    param([string]$Line)

    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Line, [ref]$null, [ref]$parseErrors)
    # A line that doesn't parse can't have run either.
    if ($parseErrors.Count -gt 0) { return $false }

    foreach ($cmd in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)) {
        # Null for dynamic invocation such as `& $exe`, which we can't judge, so
        # give it the benefit of the doubt.
        $name = $cmd.GetCommandName()
        if (-not $name) { continue }
        if (-not (Get-Command -Name $name -ErrorAction Ignore)) { return $false }
    }

    return $true
}

function Initialize-PSReadLine {

    # `Get-Module -ListAvailable` walks every directory in $env:PSModulePath and
    # stats every manifest it finds, which costs 400-600ms here and is never
    # cached. An interactive ConsoleHost has already imported PSReadLine by the
    # time this profile runs, so check the LOADED module list instead (~0.2ms).
    if (-not $isInteractiveShell -or -not (Get-Module -Name PSReadLine)) {
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

        try {
            # Setting a custom handler REPLACES PSReadLine's built-in detection of
            # passwords/tokens/keys, so delegate to it first rather than losing it.
            $option = [Microsoft.PowerShell.PSConsoleReadLine]::GetDefaultAddToHistoryOption($line)
            if ($option -ne [Microsoft.PowerShell.AddToHistoryOption]::MemoryAndFile) {
                return $option
            }

            if ($line -match '(?i)connectionstring') {
                return [Microsoft.PowerShell.AddToHistoryOption]::SkipAdding
            }

            # Typos and unknown commands stay recallable with Up-arrow for the rest
            # of this session, but never reach the history file.
            if (-not (Test-CommandLineResolves $line)) {
                return [Microsoft.PowerShell.AddToHistoryOption]::MemoryOnly
            }

            return [Microsoft.PowerShell.AddToHistoryOption]::MemoryAndFile
        }
        catch {
            # Never drop history because of a bug in here.
            return [Microsoft.PowerShell.AddToHistoryOption]::MemoryAndFile
        }
    }
}
Initialize-PSReadLine

################################################################################
# Startup
################################################################################

# Set encoding to UTF-8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# `starship init powershell` only prints ANOTHER Invoke-Expression that runs
# starship.exe a second time with --print-full-init, so ask for the full init
# directly and skip a whole process spawn.
$InitScript = Get-CachedInitScript -Name 'starship' -Generate { & starship init powershell --print-full-init }
if ($InitScript) {
    function Invoke-Starship-TransientFunction {
        &starship module character
    }
    . $InitScript
    # starship's init resets PromptText, so re-apply the vi cursor indicator.
    if ($isInteractiveShell -and (Get-Module -Name PSReadLine)) {
        Set-PSReadLineOption -ViModeIndicator Cursor
    }
}

$InitScript = Get-CachedInitScript -Name 'zoxide' -Generate { zoxide init powershell }
if ($InitScript) {
    . $InitScript
    Remove-Item alias:cd -Force
    Set-Alias -Name "cd" -Value "z"
}

$InitScript = Get-CachedInitScript -Name 'mise' -Generate { & mise activate pwsh }
if ($InitScript) {
    . $InitScript
}

Remove-Variable -Name InitScript -ErrorAction SilentlyContinue

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
    # Completions
    ################################################################################
    # Deferred: these only affect tab completion, which is unusable until after
    # the first prompt anyway. Argument completers are engine-global, so
    # registering them from this event handler still works.

    $GhInit = Get-CachedInitScript -Name 'gh' -Generate { gh completion -s powershell }
    if ($GhInit) { . $GhInit }

    if (Get-Command -Name dotnet -CommandType Application -ErrorAction SilentlyContinue) {
        Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
            param($wordToComplete, $commandAst, $cursorPosition)
            $null = $wordToComplete
            dotnet complete --position $cursorPosition $commandAst.ToString() |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
        }
    }

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
