#!/usr/bin/env pwsh
# Claude Code status line — pure PowerShell 7, no third-party statusline tools.
# PowerShell port of statusline.sh; git is used when available, nothing else.
#
#   Model [effort] fast ctxbar - compactions  <flex>  cwd - worktree - +N -N
#     <flex>  clock - name [id] - tokens - cache% - speed - 5h% - 7d%
#
# Width-gated: the session group needs SESSION_MIN_COLS, and the
# tokens/cache/speed/usage tail needs more than EXTRA_MIN_COLS.
#
#   * every colour is a plain ANSI-16 code so the line follows the terminal
#     theme; only the context bar keeps its true-colour "morning" gradient
#
# Tweakables live in the CONFIG block below.

Set-StrictMode -Off
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference    = 'SilentlyContinue'
# Invariant culture so "-f" never emits a comma decimal separator.
[System.Threading.Thread]::CurrentThread.CurrentCulture = [cultureinfo]::InvariantCulture

# ---------------------------------------------------------------- CONFIG ----

$BAR_WIDTH  = 10                              # context-bar slider width
$BAR_FILLED = [string][char]0x2501            # U+2501 heavy horizontal
$BAR_EMPTY  = [string][char]0x2500            # U+2500 light horizontal
$GRADIENT_STOPS = @(@(255, 95, 109), @(255, 195, 113))  # gradient:morning (#ff5f6d -> #ffc371)

$FLEX_RESERVE     = 40                        # flexMode: full-minus-40
$SESSION_MIN_COLS = 170                       # hide the session group below this width
$EXTRA_MIN_COLS   = 275                       # show tokens/cache/speed/usage above this width
$SEPARATOR        = ' - '                     # defaultSeparator: "-"
$MERGE_GLUE       = ' '                       # joins merged items (model -> context bar)

$ICON_COMPACTION = [string][char]0xF021       # U+F021 nerd font cog
$ICON_CLOCK      = [string][char]0xF520       # U+F520 nf-oct-stopwatch (session duration)
$ICON_WORKTREE   = ''
$ICON_TOKENS     = [string][char]0xF292       # U+F292 nf-fa-hashtag    - tokens this session
$ICON_CACHE      = [string][char]0xF1C0       # U+F1C0 nf-fa-database   - cache hit rate
$ICON_SPEED      = [string][char]0xF0E4       # U+F0E4 nf-fa-tachometer - token speed
$LABEL_FIVE_HOUR = '5h'                       # no icon says "5 hours"; a label is clearer
$LABEL_SEVEN_DAY = '7d'                       # likewise for the weekly window

# ANSI-16 foreground codes (30-37 normal, 90-97 bright) -> follow terminal theme
$C_MODEL      = 36   # cyan  - "model [effort]"
$C_EFFORT     = 36   # cyan  - effort alone, when no model name is reported
$C_FAST       = 93   # bright yellow - fast mode
$C_COMPACTION = 33   # yellow
$C_CWD        = 34   # blue
$C_WORKTREE   = 95   # bright magenta
$C_ADDED      = 32   # green - "+N" lines added
$C_REMOVED    = 31   # red   - "-N" lines removed
$C_CLOCK      = 90   # grey
$C_SESSION    = 93   # bright yellow - "session name [id]"
$C_TOKENS     = 90   # grey  - total tokens this session
$C_CACHE      = 90   # grey  - cache hit rate
$C_SPEED      = 90   # grey  - session-average token speed
$C_USAGE      = 90   # grey  - 5-hour and 7-day rate-limit usage

$CWD_SEGMENTS     = 2                         # current-working-dir: trailing segments
$FAST_LABEL       = [string][char]0x26A1      # U+26A1 lightning bolt; shown only in fast mode
$FAST_LABEL_WIDTH = 2                         # emoji are double-width; keeps flex maths honest

$ESC      = [string][char]27
$SENTINEL_CH = [char]1                        # internal marker for a flex separator
$SENTINEL    = [string]$SENTINEL_CH           # searched as a char: ICU string search ignores U+0001
$EMDASH   = [string][char]0x2014

# System.Text.Json value kinds, hoisted out of the transcript hot loop.
$KObj   = [System.Text.Json.JsonValueKind]::Object
$KNum   = [System.Text.Json.JsonValueKind]::Number
$KStr   = [System.Text.Json.JsonValueKind]::String
$KTrue  = [System.Text.Json.JsonValueKind]::True
$KFalse = [System.Text.Json.JsonValueKind]::False
$KNull  = [System.Text.Json.JsonValueKind]::Null

# ------------------------------------------------------------- UTILITIES ----

# Visible width of *unstyled* text, counted in code points so a surrogate pair
# still scores 1. Styled strings are measured by bookkeeping during assembly.
function Get-PlainLength {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    $n = 0
    for ($i = 0; $i -lt $Text.Length; $i++) {
        if ([char]::IsHighSurrogate($Text[$i]) -and ($i + 1) -lt $Text.Length) { $i++ }
        $n++
    }
    return $n
}

# Split a string into code points, so gradient colouring and truncation never
# cut a surrogate pair in half.
function Split-CodePoints {
    param([string]$Text)
    $out = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $Text.Length; $i++) {
        if ([char]::IsHighSurrogate($Text[$i]) -and ($i + 1) -lt $Text.Length) {
            $out.Add($Text.Substring($i, 2)); $i++
        } else {
            $out.Add([string]$Text[$i])
        }
    }
    return , $out
}

# Truncate a styled string to `max` visible columns, keeping escape sequences
# intact and appending "..." (mirrors ccstatusline's truncateStyledText).
# Works on ESC-delimited chunks so long lines stay cheap.
function Format-TruncatedStyled {
    param([string]$Text, [int]$Max)
    if ($Max -le 0) { return '' }
    if ($Max -le 3) { return '...'.Substring(0, $Max) }

    $target = $Max - 3
    $sb = [System.Text.StringBuilder]::new()
    $w = 0
    $segs = $Text.Split([char]27)

    for ($idx = 0; $idx -lt $segs.Length; $idx++) {
        $plain = $segs[$idx]
        if ($idx -gt 0) {
            $m = [regex]::Match($plain, '^\[[0-9;]*[a-zA-Z]')
            if ($m.Success) {
                [void]$sb.Append($ESC).Append($m.Value)
                $plain = $plain.Substring($m.Length)
            }
        }
        if ($plain.Length -eq 0) { continue }

        $run = Get-PlainLength $plain
        if (($w + $run) -le $target) {
            [void]$sb.Append($plain)
            $w += $run
            continue
        }
        # this run overflows: copy it code point by code point until full
        foreach ($c in (Split-CodePoints $plain)) {
            if ($w -ge $target) { break }
            [void]$sb.Append($c)
            $w++
        }
        break
    }
    return $sb.ToString() + '...'
}

# Console width via GetConsoleScreenBufferInfo on a fresh CONOUT$ handle, which
# reaches a real console even when stdout is a pipe. Last resort only: it works
# in plain conhost but returns 0 under a ConPTY-style terminal (measured: no
# CONOUT$ is reachable when Claude Code runs us), so COLUMNS is tried first.
#
# Declared via Reflection.Emit (~20ms) rather than Add-Type (~500ms, which
# invokes the C# compiler) — this runs on every status line render.
function Get-ConsoleWidthNative {
    try {
        $asm = [System.Reflection.Emit.AssemblyBuilder]::DefineDynamicAssembly(
                   [System.Reflection.AssemblyName]::new('SLConsoleProbe'),
                   [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
        $tb = $asm.DefineDynamicModule('m').DefineType('SLK', 'Public, Class')
        $null = $tb.DefinePInvokeMethod('CreateFileW', 'kernel32.dll',
            'Public, Static, PinvokeImpl', 'Standard', [IntPtr],
            @([string], [uint32], [uint32], [IntPtr], [uint32], [uint32], [IntPtr]),
            'Winapi', [System.Runtime.InteropServices.CharSet]::Unicode)
        $null = $tb.DefinePInvokeMethod('GetConsoleScreenBufferInfo', 'kernel32.dll',
            'Public, Static, PinvokeImpl', 'Standard', [bool], @([IntPtr], [IntPtr]),
            'Winapi', [System.Runtime.InteropServices.CharSet]::Auto)
        $null = $tb.DefinePInvokeMethod('CloseHandle', 'kernel32.dll',
            'Public, Static, PinvokeImpl', 'Standard', [bool], @([IntPtr]),
            'Winapi', [System.Runtime.InteropServices.CharSet]::Auto)
        $k = $tb.CreateType()

        # GENERIC_READ|GENERIC_WRITE, FILE_SHARE_READ|WRITE, OPEN_EXISTING
        $h = $k::CreateFileW('CONOUT$', [uint32]0xC0000000, [uint32]3,
                             [IntPtr]::Zero, [uint32]3, [uint32]0, [IntPtr]::Zero)
        if ($h -eq [IntPtr]::Zero -or $h -eq [IntPtr](-1)) { return 0 }

        $buf = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(32)
        try {
            if (-not $k::GetConsoleScreenBufferInfo($h, $buf)) { return 0 }
            # CONSOLE_SCREEN_BUFFER_INFO byte offsets: dwSize 0, dwCursorPosition 4,
            # wAttributes 8, srWindow{Left 10, Top 12, Right 14, Bottom 16}.
            # srWindow (the visible window), not dwSize (the scrollback buffer).
            $left  = [System.Runtime.InteropServices.Marshal]::ReadInt16($buf, 10)
            $right = [System.Runtime.InteropServices.Marshal]::ReadInt16($buf, 14)
            $w = $right - $left + 1
            if ($w -gt 0) { return [int]$w }
            return 0
        } finally {
            [System.Runtime.InteropServices.Marshal]::FreeHGlobal($buf)
            $null = $k::CloseHandle($h)
        }
    } catch { return 0 }
}

# CLAUDE_STATUSLINE_WIDTH overrides everything; 0 means "unknown", which
# disables flex padding and truncation and keeps the session group rather than
# hiding it on a guess.
#
# Order matters. $Host.UI.RawUI.WindowSize.Width must NOT be consulted while
# stdout is redirected: it answers with a hardcoded 120 instead of failing, and
# that plausible-looking lie used to shadow the correct answer below it —
# squashing the line to 120-40 columns and hiding the whole session group.
# Under Claude Code on Windows the command runs through a shell that exports
# COLUMNS, which is both accurate and free, so it comes before the CONOUT$
# probe; that probe only pays off in a real Win32 console (plain conhost),
# where it is the sole way to measure a redirected statusline.
function Get-TerminalWidth {
    if ($env:CLAUDE_STATUSLINE_WIDTH -match '^[1-9][0-9]*$') { return [int]$env:CLAUDE_STATUSLINE_WIDTH }

    # Only trustworthy when stdout really is a console.
    if (-not [Console]::IsOutputRedirected) {
        try { $w = [Console]::WindowWidth;          if ($w -gt 0) { return [int]$w } } catch { }
        try { $w = $Host.UI.RawUI.WindowSize.Width; if ($w -gt 0) { return [int]$w } } catch { }
    }

    if ($env:COLUMNS -match '^[1-9][0-9]*$') { return [int]$env:COLUMNS }

    $w = Get-ConsoleWidthNative
    if ($w -gt 0) { return $w }

    return 0
}

# JS-style Math.round on a number.
function Get-Rounded {
    param([double]$X)
    return [int][math]::Floor($X + 0.5)
}

# ccstatusline's formatTokens(count, decimals): 1234 -> "1.2k", 1500000 -> "1.5M".
# decimals defaults to 1; the context bar passes 0 for a compact whole-number k.
function Format-Tokens {
    param([double]$Count, [int]$Decimals = 1)
    if ($Count -ge (1000000 - 500 / [math]::Pow(10, $Decimals))) { return '{0:F1}M' -f ($Count / 1000000) }
    if ($Count -ge 1000) { return [string]::Format("{0:F$Decimals}k", $Count / 1000) }
    return ([int][math]::Truncate($Count)).ToString()
}

# ----------------------------------------------------------- INPUT PARSE ----

# Read stdin as raw UTF-8; the console code page never gets a say.
$stdinReader = [System.IO.StreamReader]::new([Console]::OpenStandardInput(),
                                             [System.Text.UTF8Encoding]::new($false))
$rawInput = $stdinReader.ReadToEnd()
$D = $null
if (-not [string]::IsNullOrWhiteSpace($rawInput)) { $D = $rawInput | ConvertFrom-Json }

# Property access that tolerates a missing key at any depth.
function Get-Field {
    param($Obj, [string[]]$Path)
    $cur = $Obj
    foreach ($p in $Path) {
        if ($null -eq $cur) { return $null }
        $prop = $cur.PSObject.Properties[$p]
        if ($null -eq $prop) { return $null }
        $cur = $prop.Value
    }
    return $cur
}

# jq's `n`: coerce to a non-negative number, or null when that is impossible.
function Get-Number {
    param($Value)
    if ($null -eq $Value -or $Value -is [bool]) { return $null }
    $d = 0.0
    if ($Value -is [string]) {
        if (-not [double]::TryParse($Value, [System.Globalization.NumberStyles]::Float,
                                    [cultureinfo]::InvariantCulture, [ref]$d)) { return $null }
    } elseif ($Value -is [ValueType]) {
        try { $d = [double]$Value } catch { return $null }
    } else { return $null }
    if ($d -lt 0) { return 0.0 }
    return $d
}

$CWD          = [string](Get-Field $D 'cwd')
$SESSION_ID   = [string](Get-Field $D 'session_id')
$SESSION_NAME = [string](Get-Field $D 'session_name')
$TRANSCRIPT   = [string](Get-Field $D 'transcript_path')

$modelRaw = Get-Field $D 'model'
if ($modelRaw -is [string]) {
    $MODEL = $modelRaw
} else {
    $MODEL = [string](Get-Field $modelRaw 'display_name')
    if (-not $MODEL) { $MODEL = [string](Get-Field $modelRaw 'id') }
}
$MODEL = [regex]::Replace($MODEL, '\s*\(.*\)$', '')

# Effort as reported by the status JSON: "v<level>" when it names one, "n" when
# the object is there but the level is not, "" when there is no object at all.
$EFFORT_RAW = ''
$effortObj = Get-Field $D 'effort'
if ($null -ne $effortObj -and $effortObj.PSObject.Properties['level']) {
    $EFFORT_RAW = if ($effortObj.level -is [string]) { 'v' + $effortObj.level } else { 'n' }
}

$ctxWin = Get-Field $D 'context_window'
$CTX_TOTAL = Get-Number (Get-Field $ctxWin 'context_window_size')
if ($null -ne $CTX_TOTAL -and $CTX_TOTAL -le 0) { $CTX_TOTAL = $null }

# current_usage is either a bare number or the usage breakdown; the context bar
# wants what occupies the window (no output tokens), with the fuller totals and
# used_percentage as fallbacks.
$cu = Get-Field $ctxWin 'current_usage'
$cuTotal = $null
$ctxLen  = $null
if ($cu -is [ValueType] -and $cu -isnot [bool]) {
    $cuTotal = Get-Number $cu
    $ctxLen  = $cuTotal
} elseif ($null -ne $cu) {
    $ti = Get-Number (Get-Field $cu 'input_tokens')
    $to = Get-Number (Get-Field $cu 'output_tokens')
    $tc = Get-Number (Get-Field $cu 'cache_creation_input_tokens')
    $tr = Get-Number (Get-Field $cu 'cache_read_input_tokens')
    if ($null -eq $ti) { $ti = 0 }
    if ($null -eq $to) { $to = 0 }
    if ($null -eq $tc) { $tc = 0 }
    if ($null -eq $tr) { $tr = 0 }
    $cuTotal = $ti + $to + $tc + $tr
    $ctxLen  = $ti + $tc + $tr
}
$upPct = Get-Number (Get-Field $ctxWin 'used_percentage')
$upTok = $null
if ($null -ne $upPct -and $null -ne $CTX_TOTAL) { $upTok = $upPct / 100 * $CTX_TOTAL }

$CTX_USED = $ctxLen
if ($null -eq $CTX_USED) { $CTX_USED = $cuTotal }
if ($null -eq $CTX_USED) { $CTX_USED = $upTok }
if ($null -ne $CTX_USED) { $CTX_USED = [math]::Floor($CTX_USED) }

$DURATION_MS   = Get-Number (Get-Field $D 'cost', 'total_duration_ms')
$LINES_ADDED   = Get-Number (Get-Field $D 'cost', 'total_lines_added')
$LINES_REMOVED = Get-Number (Get-Field $D 'cost', 'total_lines_removed')
$FIVE_HOUR_PCT = Get-Number (Get-Field $D 'rate_limits', 'five_hour', 'used_percentage')
$SEVEN_DAY_PCT = Get-Number (Get-Field $D 'rate_limits', 'seven_day', 'used_percentage')

$GIT_CWD = $CWD
if (-not $GIT_CWD) { $GIT_CWD = [string](Get-Field $D 'workspace', 'current_dir') }
if (-not $GIT_CWD) { $GIT_CWD = [string](Get-Field $D 'workspace', 'project_dir') }

$FAST_MODE = ((Get-Field $D 'fast_mode') -eq $true)

# [System.IO.File] rather than Test-Path throughout: loading the provider
# cmdlets costs more than everything this script actually computes.
$HAS_TRANSCRIPT = [bool]($TRANSCRIPT -and [System.IO.File]::Exists($TRANSCRIPT))

# ----------------------------------------------------------- WIDGET DATA ----

# Thinking effort: status JSON first, then the transcript, then settings.json.
function Get-EffortFromTranscript {
    if (-not $HAS_TRANSCRIPT) { return $null }
    $hit = $null
    foreach ($l in [System.IO.File]::ReadLines($TRANSCRIPT)) {
        if ($l -match '<local-command-stdout>Set (effort level|model) to') { $hit = $l }
    }
    if (-not $hit) { return $null }
    $content = (Get-Field ($hit | ConvertFrom-Json) 'message', 'content')
    if ($content -isnot [string]) { return $null }
    $m = [regex]::Match($content, 'Set effort level to ([a-zA-Z0-9-]+)')
    if ($m.Success) { return $m.Groups[1].Value.ToLowerInvariant() }
    $m = [regex]::Match($content, 'Set model to.* with ([a-zA-Z0-9-]+) effort')
    if ($m.Success) { return $m.Groups[1].Value.ToLowerInvariant() }
    return $null
}

function Resolve-Effort {
    if ($EFFORT_RAW -eq 'n') { return 'default' }
    if ($EFFORT_RAW.StartsWith('v')) { return $EFFORT_RAW.Substring(1) }

    $level = Get-EffortFromTranscript
    if ($level) { return $level }

    $cfgDir = $env:CLAUDE_CONFIG_DIR
    if (-not $cfgDir) { $cfgDir = Join-Path $HOME '.claude' }
    $settings = Join-Path $cfgDir 'settings.json'
    if ([System.IO.File]::Exists($settings)) {
        $lvl = ([System.IO.File]::ReadAllText($settings) | ConvertFrom-Json).effortLevel
        if ($lvl -is [string] -and $lvl) { return $lvl.ToLowerInvariant() }
    }
    return 'default'
}

# Compaction events, written to the transcript as compact_boundary markers.
function Get-CompactionCount {
    if (-not $HAS_TRANSCRIPT) { return 0 }
    $n = 0
    foreach ($l in [System.IO.File]::ReadLines($TRANSCRIPT)) {
        if ($l.Contains('"compact_boundary"') -and $l -notmatch '"isSidechain": ?true') { $n++ }
    }
    return $n
}

# /rename title, when the status JSON does not already carry one.
function Get-SessionNameFromTranscript {
    if (-not $HAS_TRANSCRIPT) { return $null }
    $last = $null
    foreach ($l in [System.IO.File]::ReadLines($TRANSCRIPT)) {
        if ($l.Contains('"custom-title"')) { $last = $l }
    }
    if (-not $last) { return $null }
    $o = $last | ConvertFrom-Json
    if ($o.type -eq 'custom-title' -and $o.customTitle) { return [string]$o.customTitle }
    return $null
}

# Last N path segments, "..."-prefixed when anything was dropped.
function Format-ShortPath {
    param([string]$Path, [int]$Segments)
    $sep = if ($Path.Contains('\')) { '\' } else { '/' }
    $kept = $Path.Split([char[]]@('\', '/'), [System.StringSplitOptions]::RemoveEmptyEntries)
    if ($kept.Count -le $Segments) { return $Path }
    return '...' + $sep + ($kept[($kept.Count - $Segments)..($kept.Count - 1)] -join $sep)
}

# Worktree name, or nothing at all when we are not inside a git work tree
# (ccstatusline's "hide when no git" behaviour) so no stray icon is left over.
function Get-GitWorktree {
    if (-not $GIT_CWD) { return $null }

    $env:GIT_OPTIONAL_LOCKS = '0'
    # No Get-Command probe: a missing git just throws, which we swallow anyway.
    $res = $null
    try { $res = @(& git -C $GIT_CWD rev-parse --is-inside-work-tree --git-dir 2>$null) } catch { return $null }
    if ($LASTEXITCODE -ne 0 -or $res.Count -lt 2) { return $null }
    if ($res[0].Trim() -ne 'true') { return $null }

    $gitdir = $res[1].Trim().Replace('\', '/')
    if (-not $gitdir) { return $null }
    if ($gitdir -eq '.git' -or $gitdir.EndsWith('/.git')) { return 'main' }
    $i = $gitdir.LastIndexOf('.git/worktrees/')
    if ($i -ge 0) { return $gitdir.Substring($i + 15) }
    $i = $gitdir.LastIndexOf('/worktrees/')
    if ($i -ge 0) { return $gitdir.Substring($i + 11) }
    return $null
}

# cost.total_duration_ms -> "<1m" / "45m" / "2hr" / "2hr 15m"
function Format-SessionClock {
    if ($null -eq $DURATION_MS) { return $null }
    $mins = [int][math]::Floor($DURATION_MS / 60000)
    if ($mins -lt 1) { return '<1m' }
    $h = [int][math]::Floor($mins / 60)
    $m = $mins % 60
    if ($h -eq 0) { return "${m}m" }
    if ($m -eq 0) { return "${h}hr" }
    return "${h}hr ${m}m"
}

# ------------------------------------------------------- TRANSCRIPT PASS ----

# ISO-8601 timestamp -> epoch milliseconds, or null.
function ConvertTo-EpochMs {
    param([string]$Stamp)
    if ([string]::IsNullOrEmpty($Stamp)) { return $null }
    $dto = [datetimeoffset]::MinValue
    $styles = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor
              [System.Globalization.DateTimeStyles]::AdjustToUniversal
    if ([datetimeoffset]::TryParse($Stamp, [cultureinfo]::InvariantCulture, $styles, [ref]$dto)) {
        return [double]$dto.ToUnixTimeMilliseconds()
    }
    return $null
}

# Numeric JSON property of a JsonElement, defaulting to 0.
# The [ref] target must already hold a JsonElement or PowerShell cannot bind the
# `out JsonElement` overload — hence the ::new() seeds throughout this section.
function Get-JsonNumber {
    param($Element, [string]$Name)
    $p = [System.Text.Json.JsonElement]::new()
    if ($Element.TryGetProperty($Name, [ref]$p) -and $p.ValueKind -eq $KNum) { return $p.GetDouble() }
    return 0.0
}

# One streaming pass over the transcript for the wide-terminal extras: token
# totals (with ccstatusline's stop_reason de-dup rule so streamed partials are
# not double counted), the cache read/write split, and the user -> assistant
# intervals the session-average speed is built from. Sidechain (subagent) turns
# are excluded from the speed intervals, as ccstatusline does.
# Returns @{ Total; Read; Create; DurationMs; SpeedTokens } or $null.
function Get-TranscriptMetrics {
    if (-not $HAS_TRANSCRIPT) { return $null }

    $usage = [System.Collections.Generic.List[object]]::new()
    $reqs  = [System.Collections.Generic.List[object]]::new()
    $lastUser = $null
    $hasStop = $false

    $msg = [System.Text.Json.JsonElement]::new()
    $usg = [System.Text.Json.JsonElement]::new()
    $sub = [System.Text.Json.JsonElement]::new()
    $sr  = [System.Text.Json.JsonElement]::new()

    foreach ($line in [System.IO.File]::ReadLines($TRANSCRIPT)) {
        if ($line.Length -lt 2 -or $line[0] -ne '{') { continue }
        $doc = $null
        try { $doc = [System.Text.Json.JsonDocument]::Parse($line) } catch { continue }
        try {
            $root = $doc.RootElement
            if ($root.ValueKind -ne $KObj) { continue }

            $u = $null
            if ($root.TryGetProperty('message', [ref]$msg) -and $msg.ValueKind -eq $KObj) {
                if ($msg.TryGetProperty('usage', [ref]$usg) -and $usg.ValueKind -eq $KObj) { $u = $usg }
            }

            if ($null -ne $u) {
                # jq semantics: a present-but-null stop_reason still sets hasStop,
                # and only the final entry may be counted on the strength of it.
                $has = $msg.TryGetProperty('stop_reason', [ref]$sr)
                $stop = $null
                if ($has) {
                    $hasStop = $true
                    if ($sr.ValueKind -eq $KStr) { $stop = $sr.GetString() }
                    elseif ($sr.ValueKind -eq $KFalse) { $stop = $false }
                    elseif ($sr.ValueKind -ne $KNull) { $stop = $true }   # any other truthy kind
                }
                $usage.Add([pscustomobject]@{
                    Input   = Get-JsonNumber $u 'input_tokens'
                    Output  = Get-JsonNumber $u 'output_tokens'
                    Read    = Get-JsonNumber $u 'cache_read_input_tokens'
                    Create  = Get-JsonNumber $u 'cache_creation_input_tokens'
                    Stop    = $stop
                    HasStop = $has
                })
            }

            if ($root.TryGetProperty('isApiErrorMessage', [ref]$sub) -and $sub.ValueKind -eq $KTrue) { continue }
            if ($root.TryGetProperty('isSidechain', [ref]$sub) -and $sub.ValueKind -eq $KTrue) { continue }

            if (-not ($root.TryGetProperty('type', [ref]$sub) -and $sub.ValueKind -eq $KStr)) { continue }
            $type = $sub.GetString()

            $ts = $null
            if ($root.TryGetProperty('timestamp', [ref]$sub) -and $sub.ValueKind -eq $KStr) {
                $ts = ConvertTo-EpochMs $sub.GetString()
            }

            if ($type -eq 'user') {
                $lastUser = $ts
            } elseif ($type -eq 'assistant' -and $null -ne $u) {
                $iv = $null
                if ($null -ne $ts -and $null -ne $lastUser -and $ts -gt $lastUser) {
                    $iv = [pscustomobject]@{ Start = $lastUser; End = $ts }
                }
                $reqs.Add([pscustomobject]@{
                    Input    = Get-JsonNumber $u 'input_tokens'
                    Output   = Get-JsonNumber $u 'output_tokens'
                    Interval = $iv
                })
            }
        } finally {
            $doc.Dispose()
        }
    }

    if ($usage.Count -eq 0 -and $reqs.Count -eq 0) { return $null }

    # Streamed partials repeat the usage block; when any entry carries a
    # stop_reason, count only the terminal ones (plus a trailing null).
    $counted = [System.Collections.Generic.List[object]]::new()
    if ($hasStop) {
        for ($i = 0; $i -lt $usage.Count; $i++) {
            $e = $usage[$i]
            $keep = if ($null -ne $e.Stop) { $e.Stop -ne $false }
                    else { $e.HasStop -and $i -eq ($usage.Count - 1) }
            if ($keep) { $counted.Add($e) }
        }
    } else {
        $counted.AddRange($usage)
    }

    $in = 0.0; $out = 0.0; $read = 0.0; $create = 0.0
    foreach ($e in $counted) {
        $in += $e.Input; $out += $e.Output; $read += $e.Read; $create += $e.Create
    }

    # Union of the user -> assistant intervals: overlapping turns must not be
    # billed twice against the session-average speed.
    $durMs = 0.0
    $ivs = [System.Collections.Generic.List[object]]::new()
    foreach ($r in $reqs) { if ($null -ne $r.Interval) { $ivs.Add($r.Interval) } }
    $ivs.Sort({ param($x, $y) $x.Start.CompareTo($y.Start) })
    $merged = [System.Collections.Generic.List[object]]::new()
    foreach ($iv in $ivs) {
        if ($merged.Count -gt 0 -and $iv.Start -le $merged[-1].End) {
            $last = $merged[-1]
            if ($iv.End -gt $last.End) {
                $merged[$merged.Count - 1] = [pscustomobject]@{ Start = $last.Start; End = $iv.End }
            }
        } else {
            $merged.Add($iv)
        }
    }
    foreach ($m in $merged) { $durMs += $m.End - $m.Start }

    $speedTokens = 0.0
    foreach ($r in $reqs) { $speedTokens += $r.Input + $r.Output }

    return @{
        Total       = $in + $out + $read + $create
        Read        = $read
        Create      = $create
        DurationMs  = $durMs
        SpeedTokens = $speedTokens
    }
}

# Formats the five wide-terminal extras; $null means "no data, hide the item".
function Format-Extras {
    param($Metrics, $FiveHour, $SevenDay)

    function fmtTokens([double]$c) {
        if ($c -ge (1000000 - 50)) { return '{0:F1}M' -f ($c / 1000000) }
        if ($c -ge 1000)           { return '{0:F1}k' -f ($c / 1000) }
        return ([int][math]::Truncate($c)).ToString()
    }
    function fmtSpeed([double]$t) {
        if ($t -ge 1000) { return '{0:F1}k t/s' -f ($t / 1000) }
        return '{0:F1} t/s' -f $t
    }
    function fmtPct([double]$p) {
        if ($p -lt 0) { $p = 0 }
        if ($p -gt 100) { $p = 100 }
        return '{0:F1}%' -f $p
    }

    $tokens = $null; $cache = $null; $speed = $null
    if ($null -ne $Metrics) {
        $tokens = fmtTokens $Metrics.Total
        $rc = $Metrics.Read + $Metrics.Create
        $cache = if ($rc -gt 0) { '{0:F1}%' -f ($Metrics.Read / $rc * 100) } else { '0.0%' }
        $speed = if ($Metrics.DurationMs -gt 0) { fmtSpeed ($Metrics.SpeedTokens / ($Metrics.DurationMs / 1000)) }
                 else { $EMDASH }
    }
    return @(
        $tokens
        $cache
        $speed
        $(if ($null -ne $FiveHour) { fmtPct $FiveHour } else { $null })
        $(if ($null -ne $SevenDay) { fmtPct $SevenDay } else { $null })
    )
}

# -------------------------------------------------------------- GRADIENT ----

# Per-character true-colour gradient, interpolated in OKLab like ccstatusline.
# Takes the characters as a list; whitespace stays uncoloured.
function Format-GradientText {
    param([System.Collections.Generic.List[string]]$Chars)

    $visible = 0
    foreach ($c in $Chars) { if ($c -ne ' ') { $visible++ } }
    if ($visible -eq 0) { return -join $Chars }

    # Stops, converted once into OKLab. PowerShell variables are case-insensitive,
    # so these deliberately avoid single-letter names that the loop below reuses.
    # The colour maths is inlined rather than factored into helpers: at three
    # calls per character, call overhead would dominate the arithmetic.
    $ns = $GRADIENT_STOPS.Count
    $stopL = [double[]]::new($ns); $stopA = [double[]]::new($ns); $stopB = [double[]]::new($ns)
    for ($k = 0; $k -lt $ns; $k++) {
        $lin = [double[]]::new(3)
        for ($ch = 0; $ch -lt 3; $ch++) {
            $x = $GRADIENT_STOPS[$k][$ch] / 255
            $lin[$ch] = if ($x -le 0.04045) { $x / 12.92 } else { [math]::Pow(($x + 0.055) / 1.055, 2.4) }
        }
        $cl = [math]::Cbrt(0.4122214708 * $lin[0] + 0.5363325363 * $lin[1] + 0.0514459929 * $lin[2])
        $cm = [math]::Cbrt(0.2119034982 * $lin[0] + 0.6806995451 * $lin[1] + 0.1073969566 * $lin[2])
        $cs = [math]::Cbrt(0.0883024619 * $lin[0] + 0.2817188376 * $lin[1] + 0.6299787005 * $lin[2])
        $stopL[$k] = 0.2104542553 * $cl + 0.7936177850 * $cm - 0.0040720468 * $cs
        $stopA[$k] = 1.9779984951 * $cl - 2.4285922050 * $cm + 0.4505937099 * $cs
        $stopB[$k] = 0.0259040371 * $cl + 0.7827717662 * $cm - 0.8086757660 * $cs
    }

    $den = if ($visible -gt 1) { $visible - 1 } else { 1 }
    $rgb = [string[]]::new($visible)
    $chan = [int[]]::new(3)
    for ($i = 0; $i -lt $visible; $i++) {
        $scaled = ($i / $den) * ($ns - 1)
        $lo = [int][math]::Floor($scaled)
        if ($lo -gt $ns - 2) { $lo = $ns - 2 }
        if ($lo -lt 0) { $lo = 0 }
        $f = $scaled - $lo
        $ll = $stopL[$lo] + ($stopL[$lo + 1] - $stopL[$lo]) * $f
        $aa = $stopA[$lo] + ($stopA[$lo + 1] - $stopA[$lo]) * $f
        $bb = $stopB[$lo] + ($stopB[$lo + 1] - $stopB[$lo]) * $f
        $lc = $ll + 0.3963377774 * $aa + 0.2158037573 * $bb
        $mc = $ll - 0.1055613458 * $aa - 0.0638541728 * $bb
        $sc = $ll - 0.0894841775 * $aa - 1.2914855480 * $bb
        $l3 = $lc * $lc * $lc; $m3 = $mc * $mc * $mc; $s3 = $sc * $sc * $sc
        for ($ch = 0; $ch -lt 3; $ch++) {
            $lv = if ($ch -eq 0) { 4.0767416621 * $l3 - 3.3077115913 * $m3 + 0.2309699292 * $s3 }
                  elseif ($ch -eq 1) { -1.2684380046 * $l3 + 2.6097574011 * $m3 - 0.3413193965 * $s3 }
                  else { -0.0041960863 * $l3 - 0.7034186147 * $m3 + 1.7076147010 * $s3 }
            $v = if ($lv -le 0.0031308) { 12.92 * $lv } else { 1.055 * [math]::Pow($lv, 0.4166666666666667) - 0.055 }
            if ($v -lt 0) { $v = 0 } elseif ($v -gt 1) { $v = 1 }
            $chan[$ch] = [int][math]::Floor($v * 255 + 0.5)
        }
        $rgb[$i] = "$($chan[0]);$($chan[1]);$($chan[2])"
    }

    $sb = [System.Text.StringBuilder]::new()
    $idx = 0
    foreach ($c in $Chars) {
        if ($c -eq ' ') {
            [void]$sb.Append(' ')
        } else {
            [void]$sb.Append($ESC).Append('[38;2;').Append($rgb[$idx]).Append('m').Append($c)
            $idx++
        }
    }
    return $sb.ToString()
}

# First gradient stop - colours the separator that follows the bar.
function Get-GradientHead {
    $f = $GRADIENT_STOPS[0]
    return "$ESC[38;2;$($f[0]);$($f[1]);$($f[2])m"
}

# -------------------------------------------------------------- ASSEMBLY ----

$ITEMS = [System.Collections.Generic.List[hashtable]]::new()

function Add-Widget {
    param([int]$Code, [string]$Text, [int]$Length = -1)
    if ([string]::IsNullOrEmpty($Text)) { return }
    if ($Length -lt 0) { $Length = Get-PlainLength $Text }
    $ITEMS.Add(@{
        Text  = "$ESC[${Code}m$Text$ESC[39m"
        Len   = $Length
        Color = "$ESC[${Code}m"
        Flex  = $false
        Merge = $false
    })
}

function Add-Styled {
    param([string]$Text, [int]$Length, [string]$SeparatorColor)
    $ITEMS.Add(@{
        Text  = "$Text$ESC[39m"
        Len   = $Length
        Color = $SeparatorColor
        Flex  = $false
        Merge = $false
    })
}

function Add-Flex {
    $ITEMS.Add(@{ Text = ''; Len = 0; Color = ''; Flex = $true; Merge = $false })
}

# Join the item just added to the next one with MERGE_GLUE instead of SEPARATOR.
function Merge-Last {
    if ($ITEMS.Count -gt 0) { $ITEMS[$ITEMS.Count - 1].Merge = $true }
}

# --- widgets ----------------------------------------------------------------

# Probed once: the flex maths below needs it too. 0 means "unknown", in which
# case the session group is kept rather than hidden on a guess.
$TERM_COLS = Get-TerminalWidth
$SHOW_SESSION = -not ($TERM_COLS -gt 0 -and $TERM_COLS -lt $SESSION_MIN_COLS)

# model and thinking effort share one item: "Opus 5 [high]"
$effort = Resolve-Effort
if ($MODEL -and $effort) {
    Add-Widget $C_MODEL "$MODEL [$effort]"
} elseif ($MODEL) {
    Add-Widget $C_MODEL $MODEL
} else {
    Add-Widget $C_EFFORT $effort
}
Merge-Last          # no " - " between the model and what follows

# fast mode, shown only while it is on
if ($FAST_MODE) {
    Add-Widget $C_FAST $FAST_LABEL $FAST_LABEL_WIDTH
    Merge-Last
}

# context bar: minimal slider + "used/total (pct%)" under the morning gradient
if ($null -ne $CTX_USED -and $null -ne $CTX_TOTAL -and $CTX_TOTAL -gt 0) {
    $pct = $CTX_USED / $CTX_TOTAL * 100
    if ($pct -lt 0) { $pct = 0 }
    if ($pct -gt 100) { $pct = 100 }
    $filled = [int][math]::Floor($pct / 100 * $BAR_WIDTH + 0.5)

    $barChars = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $BAR_WIDTH; $i++) {
        $barChars.Add($(if ($i -lt $filled) { $BAR_FILLED } else { $BAR_EMPTY }))
    }

    $tail = ' ' + (Format-Tokens $CTX_USED 0) + '/' + (Format-Tokens $CTX_TOTAL 0) +
            ' (' + (Get-Rounded $pct) + '%)'
    foreach ($c in $tail.ToCharArray()) { $barChars.Add([string]$c) }

    Add-Styled (Format-GradientText $barChars) ($BAR_WIDTH + $tail.Length) (Get-GradientHead)
}

Add-Widget $C_COMPACTION "$ICON_COMPACTION $(Get-CompactionCount)"

Add-Flex

if ($CWD) { Add-Widget $C_CWD (Format-ShortPath $CWD $CWD_SEGMENTS) }
$worktree = Get-GitWorktree
if ($worktree) { Add-Widget $C_WORKTREE "$ICON_WORKTREE$worktree" }

# lines changed this session; each half is omitted while it is still zero
if ($null -ne $LINES_ADDED -and $LINES_ADDED -gt 0) {
    Add-Widget $C_ADDED ('+' + [int]$LINES_ADDED)
    Merge-Last
}
if ($null -ne $LINES_REMOVED -and $LINES_REMOVED -gt 0) {
    Add-Widget $C_REMOVED ('-' + [int]$LINES_REMOVED)
}

# Right-hand session group: duration and name/id. Dropped entirely on narrow
# terminals, along with its flex separator, so the cwd group moves to the edge
# instead of leaving a dead gap where the group used to be.
if ($SHOW_SESSION) {
    Add-Flex

    $clock = Format-SessionClock
    if ($clock) { Add-Widget $C_CLOCK "$ICON_CLOCK $clock" }

    # session name and id share one item: "my-session [abc123...]"
    if (-not $SESSION_NAME) { $SESSION_NAME = Get-SessionNameFromTranscript }
    if ($SESSION_NAME -and $SESSION_ID) {
        Add-Widget $C_SESSION "$SESSION_NAME [$SESSION_ID]"
    } elseif ($SESSION_NAME) {
        Add-Widget $C_SESSION $SESSION_NAME
    } else {
        Add-Widget $C_SESSION $SESSION_ID
    }

    # Wide terminals only: token total, cache hit rate, session-average speed,
    # and the 5-hour / 7-day rate-limit usage. The first three need a full
    # transcript pass, so the width gate keeps that cost off narrow layouts.
    if ($TERM_COLS -gt $EXTRA_MIN_COLS) {
        $extras = Format-Extras (Get-TranscriptMetrics) $FIVE_HOUR_PCT $SEVEN_DAY_PCT
        if ($extras[0]) { Add-Widget $C_TOKENS "$ICON_TOKENS $($extras[0])" }
        if ($extras[1]) { Add-Widget $C_CACHE  "$ICON_CACHE $($extras[1])" }
        if ($extras[2]) { Add-Widget $C_SPEED  "$ICON_SPEED $($extras[2])" }
        if ($extras[3]) { Add-Widget $C_USAGE  "$LABEL_FIVE_HOUR $($extras[3])" }
        if ($extras[4]) { Add-Widget $C_USAGE  "$LABEL_SEVEN_DAY $($extras[4])" }
    }
}

# --- join, flex, truncate ---------------------------------------------------

$sb = [System.Text.StringBuilder]::new()
$total = 0
$nflex = 0
$prev = $null
foreach ($it in $ITEMS) {
    if ($it.Flex) {
        [void]$sb.Append($SENTINEL)
        $nflex++
        $prev = $it
        continue
    }
    if ($null -ne $prev -and -not $prev.Flex) {
        if ($prev.Merge) {
            [void]$sb.Append($MERGE_GLUE)
            $total += $MERGE_GLUE.Length
        } else {
            [void]$sb.Append($prev.Color).Append($SEPARATOR).Append($ESC).Append('[39m')
            $total += $SEPARATOR.Length
        }
    }
    [void]$sb.Append($it.Text)
    $total += $it.Len
    $prev = $it
}
$out = $sb.ToString()

$width = 0
if ($TERM_COLS -gt 0) {
    $width = $TERM_COLS - $FLEX_RESERVE
    if ($width -lt 0) { $width = 0 }
}

if ($nflex -gt 0) {
    if ($width -gt 0) {
        $space = $width - $total
        if ($space -lt 0) { $space = 0 }
        $per = [int][math]::Floor($space / $nflex)
        $extra = $space % $nflex
        $res = [System.Text.StringBuilder]::new()
        $idx = 0
        while ($true) {
            $at = $out.IndexOf($SENTINEL_CH)
            if ($at -lt 0) { break }
            $pad = $per
            if ($idx -lt $extra) { $pad++ }
            [void]$res.Append($out.Substring(0, $at)).Append(' ' * $pad)
            $out = $out.Substring($at + 1)
            $total += $pad
            $idx++
        }
        $out = $res.ToString() + $out
    } else {
        $out = $out.Replace($SENTINEL, ' ')
        $total += $nflex
    }
}

# `total` is the exact visible width (widgets + separators + flex padding).
if ($width -gt 0 -and $total -gt $width) {
    $out = Format-TruncatedStyled $out $width
}

# Write UTF-8 bytes straight to stdout so nerd-font glyphs survive any code page.
$stdout = [System.IO.StreamWriter]::new([Console]::OpenStandardOutput(),
                                        [System.Text.UTF8Encoding]::new($false))
$stdout.Write($out + $ESC + "[0m`n")
$stdout.Flush()

