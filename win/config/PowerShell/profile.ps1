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
#
# The generated init builds STARSHIP_SESSION_KEY with `Get-Random -Count 16`.
# The first Get-Random of a session pays ~150ms of one-time RNG setup, which is
# nearly a fifth of this profile's entire startup, spent on a throwaway session
# id. A GUID's hex is random enough for that and costs nothing. Patch the cached
# copy so this happens once per starship version rather than once per shell, and
# only keep the patch if it actually applied and still parses.
$InitScript = Get-CachedInitScript -Name 'starship' -Generate {
    $init = @(& starship init powershell --print-full-init) -join [Environment]::NewLine

    $patched = $init -replace
    '(?m)^(\s*)\$ENV:STARSHIP_SESSION_KEY\s*=\s*-join .*$',
    '$1$$ENV:STARSHIP_SESSION_KEY = [guid]::NewGuid().ToString(''N'').Substring(0, 16)'

    if ($patched -ne $init) {
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseInput($patched, [ref]$null, [ref]$parseErrors)
        if ($parseErrors.Count -eq 0) { $init = $patched }
    }

    $init
}
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

## Exec profile.local.ps1 if it exists
# Runs inline rather than from the deferred handler below: an event action gets
# its own scope, so functions and aliases defined inside it never reach the
# prompt. Only $env: and $global: assignments survive that boundary, which is
# too sharp an edge for a general-purpose local override file.
$LocalProfile = Join-Path $PSScriptRoot -ChildPath "profile.local.ps1"
if (Test-Path $LocalProfile) {
    . $LocalProfile
}
Remove-Variable -Name LocalProfile -ErrorAction SilentlyContinue

################################################################################
# Deferred startup
################################################################################
# These imports cost ~3.3s in total on this machine - posh-git ~1330ms, PSFzf
# ~1250ms, DockerCompletion ~780ms, CompletionPredictor ~130ms - so none of them
# can sit on the path to the first prompt.
#
# The catch is that a PowerShell.OnIdle -Action handler runs on the runspace's
# own thread, so for as long as it works, PSReadLine cannot process a keystroke.
# Doing all four in a single firing froze input for seconds at a time, most
# noticeably right after a command finished. So keep a queue and drain it a
# slice per firing: once a firing has spent DeferredStartupBudgetMs it stops
# taking new work and hands the thread back, and the next idle gap picks up
# where it left off.
#
# A single Import-Module cannot be interrupted, so the budget is a floor rather
# than a cap - the longest unavoidable block is posh-git at ~1.3s. Order is
# cheapest-and-most-wanted first, so the first firing lands prediction and
# docker completion together and git completion follows in the next one.
$global:DeferredStartupBudgetMs = 250
$global:DeferredStartupErrors = @()

$global:DeferredStartupQueue = [System.Collections.Queue]::new(@(
        # Feeds the PredictionSource = HistoryAndPlugin set in Initialize-PSReadLine.
        { Import-Module CompletionPredictor }

        { Import-Module DockerCompletion }

        {
            Import-Module posh-git
            # starship already renders git status in the prompt, so posh-git is
            # only here for `git <Tab>` and its file-status scan is pure cost.
            $GitPromptSettings.EnableFileStatus = $false
        }

        {
            Import-Module PSFzf
            # Replaces the Tab handler bound in Initialize-PSReadLine, so it has
            # to land after it.
            Set-PsFzfOption -TabExpansion
        }

        {
            # These only affect tab completion, which is unusable until after the
            # first prompt anyway. Argument completers are engine-global, so
            # registering them from an event handler still reaches the prompt.
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
        }

        {
            $env:FZF_DEFAULT_OPTS = "--layout=reverse --multi --cycle"
            # https://github.com/ryanoasis/nerd-fonts/wiki/FAQ-and-Troubleshooting#less-settings
            $env:LESSUTFCHARDEF = "e000-f8ff:p,f0001-fffff:p"
        }
    ))

# MaxTriggerCount is a backstop, not the exit condition: the handler unregisters
# itself once the queue runs dry, and budgeted draining means that usually takes
# fewer firings than there are items. If the self-unregister ever fails, this
# still stops the subscription instead of waking every ~300ms forever.
$null = Register-EngineEvent -SourceIdentifier 'PowerShell.OnIdle' `
    -MaxTriggerCount $global:DeferredStartupQueue.Count -Action {

    $budget = [System.Diagnostics.Stopwatch]::StartNew()
    while ($global:DeferredStartupQueue.Count -gt 0 -and
        $budget.ElapsedMilliseconds -lt $global:DeferredStartupBudgetMs) {

        $item = $global:DeferredStartupQueue.Dequeue()
        try { & $item }
        catch {
            # An event action's errors are swallowed into its event job, so stash
            # them somewhere readable: `$DeferredStartupErrors` at the prompt.
            $global:DeferredStartupErrors += $_
        }
    }

    if ($global:DeferredStartupQueue.Count -eq 0) {
        Unregister-Event -SourceIdentifier 'PowerShell.OnIdle' -Force -ErrorAction SilentlyContinue
        Remove-Variable -Name DeferredStartupQueue, DeferredStartupBudgetMs `
            -Scope Global -ErrorAction SilentlyContinue
    }
}
