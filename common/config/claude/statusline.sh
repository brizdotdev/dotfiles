#!/usr/bin/env bash
# Claude Code status line — pure bash, no third-party statusline tools.
# Requires: jq, awk; git and stty are used when available.
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

set -uo pipefail
export LC_ALL=C          # byte semantics everywhere; UTF-8 is handled by hand
shopt -s extglob

# ---------------------------------------------------------------- CONFIG ----

BAR_WIDTH=10                        # context-bar slider width
BAR_FILLED=$'\xe2\x94\x81'          # U+2501 heavy horizontal
BAR_EMPTY=$'\xe2\x94\x80'           # U+2500 light horizontal
GRADIENT_STOPS='255,95,109 255,195,113'   # gradient:morning (#ff5f6d -> #ffc371)

FLEX_RESERVE=40                     # flexMode: full-minus-40
SESSION_MIN_COLS=170                # hide the session group below this width
EXTRA_MIN_COLS=275                  # show tokens/cache/speed/usage above this width
SEPARATOR=' - '                     # defaultSeparator: "-"
MERGE_GLUE=' '                      # joins merged items (model -> context bar)

ICON_COMPACTION=$'\xef\x80\xa1'     # U+F021 nerd font cog
ICON_CLOCK=$'\xef\x94\xa0'          # U+F520 nf-oct-stopwatch (session duration)
ICON_WORKTREE=$'\xf0\x96\xa0\xb0'   # U+16830
ICON_TOKENS=$'\xef\x8a\x92'         # U+F292 nf-fa-hashtag     — tokens this session
ICON_CACHE=$'\xef\x87\x80'          # U+F1C0 nf-fa-database    — cache hit rate
ICON_SPEED=$'\xef\x83\xa4'          # U+F0E4 nf-fa-tachometer  — token speed
LABEL_FIVE_HOUR='5h'                # no icon says "5 hours"; a label is clearer
LABEL_SEVEN_DAY='7d'                # likewise for the weekly window

# ANSI-16 foreground codes (30-37 normal, 90-97 bright) -> follow terminal theme
C_MODEL=36        # cyan  — "model [effort]"
C_EFFORT=36       # cyan  — effort alone, when no model name is reported
C_FAST=93         # bright yellow — fast mode
C_COMPACTION=33   # yellow
C_CWD=34          # blue
C_WORKTREE=95     # bright magenta
C_ADDED=32        # green — "+N" lines added
C_REMOVED=31      # red   — "-N" lines removed
C_CLOCK=30        # black
C_SESSION=93      # bright yellow — "session name [id]"
C_TOKENS=30       # black — total tokens this session
C_CACHE=30        # black — cache hit rate
C_SPEED=30        # black — session-average token speed
C_USAGE=30        # black — 5-hour and 7-day rate-limit usage

CWD_SEGMENTS=2                      # current-working-dir: trailing segments
FAST_LABEL=$'\xe2\x9a\xa1'          # U+26A1 lightning bolt; shown only in fast mode
FAST_LABEL_WIDTH=2                  # emoji are double-width; keeps flex maths honest

ESC=$'\e'
SENTINEL=$'\x01'                    # internal marker for a flex separator

# ------------------------------------------------------------- UTILITIES ----

# Visible width of *unstyled* text: we run under LC_ALL=C, so ${#s} counts
# bytes; dropping UTF-8 continuation bytes turns that into a character count.
# (Stripping SGR escapes here with an extglob pattern is quadratic in bash, so
# styled strings are measured by bookkeeping during assembly instead.)
plainlen() {
    local s=${1//[$'\x80'-$'\xbf']/}
    printf '%s' "${#s}"
}

# Truncate a styled string to `max` visible columns, keeping escape sequences
# intact and appending "..." (mirrors ccstatusline's truncateStyledText).
# Works on ESC-delimited chunks so long lines stay cheap.
truncate_styled() {
    local s=$1 max=$2
    (( max <= 0 )) && return
    (( max <= 3 )) && { printf '%.*s' "$max" '...'; return; }

    local target=$(( max - 3 )) out='' w=0 seg esc plain run i n c idx=0
    local -a segs=()
    mapfile -t -d "$ESC" segs < <(printf '%s' "$s")

    for seg in "${segs[@]}"; do
        if (( idx > 0 )); then
            if [[ $seg =~ ^(\[[0-9\;]*[a-zA-Z]) ]]; then
                esc=${BASH_REMATCH[1]}
                out+=$ESC$esc
                plain=${seg#"$esc"}
            else
                plain=$seg
            fi
        else
            plain=$seg
        fi
        (( idx++ ))
        [[ -n $plain ]] || continue

        run=$(plainlen "$plain")
        if (( w + run <= target )); then
            out+=$plain
            (( w += run ))
            continue
        fi
        # this run overflows: copy it character by character until full
        i=0 n=${#plain}
        while (( i < n && w < target )); do
            c=${plain:i:1}
            (( i++ ))
            while (( i < n )) && [[ ${plain:i:1} == [$'\x80'-$'\xbf'] ]]; do
                c+=${plain:i:1}
                (( i++ ))
            done
            out+=$c
            (( w++ ))
        done
        break
    done
    printf '%s...' "$out"
}

# Terminal width. Claude Code pipes our stdio, so walk up the process tree
# until an ancestor still owns a pty (the same trick ccstatusline uses).
# CLAUDE_STATUSLINE_WIDTH overrides everything; empty output means "unknown",
# which disables flex padding and truncation.
term_width() {
    if [[ ${CLAUDE_STATUSLINE_WIDTH:-} =~ ^[1-9][0-9]*$ ]]; then
        printf '%s' "$CLAUDE_STATUSLINE_WIDTH"
        return
    fi

    local pid=$$ depth stat ppid fd dev rows cols
    for (( depth = 0; depth < 8; depth++ )); do
        [[ -r /proc/$pid/stat ]] || break
        stat=$(< "/proc/$pid/stat")
        stat=${stat##*') '}                   # comm may contain spaces
        ppid=${stat#* }
        ppid=${ppid%% *}
        [[ $ppid =~ ^[0-9]+$ ]] || break
        (( ppid <= 1 )) && break
        pid=$ppid

        for fd in 2 1 0; do
            dev=$(readlink "/proc/$pid/fd/$fd" 2>/dev/null) || continue
            [[ $dev == /dev/pts/* || $dev == /dev/tty[0-9]* ]] || continue
            read -r rows cols < <(stty -F "$dev" size 2>/dev/null)
            if [[ ${cols:-} =~ ^[1-9][0-9]*$ ]]; then
                printf '%s' "$cols"
                return
            fi
        done
    done

    cols=$(tput cols 2>/dev/null)
    [[ $cols =~ ^[1-9][0-9]*$ ]] && printf '%s' "$cols"
}

# JS-style Math.round on a decimal string.
round() { awk -v x="${1:-0}" 'BEGIN { printf "%d", int(x + 0.5) }'; }

# ccstatusline's formatTokens(count, decimals): 1234 -> "1.2k", 1500000 -> "1.5M".
# decimals defaults to 1; the context bar passes 0 for a compact whole-number k.
format_tokens() {
    awk -v c="${1:-0}" -v d="${2:-1}" 'BEGIN {
        if (c >= 1000000 - 500 / (10 ^ d)) { printf "%.1fM", c / 1000000 }
        else if (c >= 1000)                { printf "%.*fk", d, c / 1000 }
        else                               { printf "%d", c }
    }'
}

# ----------------------------------------------------------- INPUT PARSE ----

INPUT=$(cat)

read -r -d '' JQ <<'JQEOF'
def n: (if type == "string" then (tonumber? // null) else . end)
     | (if type == "number" then (if . < 0 then 0 else . end) else null end);

. as $d
| ($d.context_window // {}) as $cw
| ((($cw.context_window_size | n) // 0) | if . > 0 then . else null end) as $ws
| $cw.current_usage as $cu
| ($cu | type) as $cut
| (if $cut == "number" then ($cu | n)
   elif $cut == "object" then
     (($cu.input_tokens | n) // 0) + (($cu.output_tokens | n) // 0)
     + (($cu.cache_creation_input_tokens | n) // 0) + (($cu.cache_read_input_tokens | n) // 0)
   else null end) as $cuTotal
| (if $cut == "number" then ($cu | n)
   elif $cut == "object" then
     (($cu.input_tokens | n) // 0)
     + (($cu.cache_creation_input_tokens | n) // 0) + (($cu.cache_read_input_tokens | n) // 0)
   else null end) as $ctxLen
| ($cw.used_percentage | n) as $up
| (if ($up != null and $ws != null) then ($up / 100 * $ws) else null end) as $upTok
| ($ctxLen // $cuTotal // $upTok) as $used
| [
    ($d.cwd // ""),
    ($d.model | if type == "string" then . else ((.display_name // .id) // "") end
              | sub("\\s*\\(.*\\)$"; "")),
    (if ($d.effort | type) == "object" and ($d.effort | has("level"))
     then (if ($d.effort.level | type) == "string" then "v" + $d.effort.level else "n" end)
     else "" end),
    ($d.session_id // ""),
    ($d.session_name // ""),
    ($d.transcript_path // ""),
    (if $used == null then "" else ($used | floor) end),
    (if $ws == null then "" else $ws end),
    (($d.cost.total_duration_ms | n) // ""),
    (($d.cwd // $d.workspace.current_dir // $d.workspace.project_dir) // ""),
    (if $d.fast_mode == true then "1" else "" end),
    (($d.cost.total_lines_added | n) // ""),
    (($d.cost.total_lines_removed | n) // ""),
    (($d.rate_limits.five_hour.used_percentage | n) // ""),
    (($d.rate_limits.seven_day.used_percentage | n) // "")
  ]
| map(tostring) | join("\u0000") + "\u0000"
JQEOF

FIELDS=()
mapfile -t -d '' FIELDS < <(printf '%s' "$INPUT" | jq -j "$JQ" 2>/dev/null)

CWD=${FIELDS[0]:-}
MODEL=${FIELDS[1]:-}
EFFORT_RAW=${FIELDS[2]:-}
SESSION_ID=${FIELDS[3]:-}
SESSION_NAME=${FIELDS[4]:-}
TRANSCRIPT=${FIELDS[5]:-}
CTX_USED=${FIELDS[6]:-}
CTX_TOTAL=${FIELDS[7]:-}
DURATION_MS=${FIELDS[8]:-}
GIT_CWD=${FIELDS[9]:-}
FAST_MODE=${FIELDS[10]:-}
LINES_ADDED=${FIELDS[11]:-}
LINES_REMOVED=${FIELDS[12]:-}
FIVE_HOUR_PCT=${FIELDS[13]:-}
SEVEN_DAY_PCT=${FIELDS[14]:-}

# ----------------------------------------------------------- WIDGET DATA ----

# Thinking effort: status JSON first, then the transcript, then settings.json.
effort_from_transcript() {
    [[ -n $TRANSCRIPT && -r $TRANSCRIPT ]] || return 1
    local line content
    line=$(grep -aE '<local-command-stdout>Set (effort level|model) to' "$TRANSCRIPT" 2>/dev/null | tail -n1)
    [[ -n $line ]] || return 1
    content=$(printf '%s' "$line" |
        jq -r 'if (.message.content? | type) == "string" then .message.content else empty end' 2>/dev/null)
    [[ -n $content ]] || return 1
    if [[ $content =~ Set\ effort\ level\ to\ ([a-zA-Z0-9-]+) ]]; then
        printf '%s' "${BASH_REMATCH[1],,}"
        return 0
    fi
    if [[ $content =~ Set\ model\ to.*\ with\ ([a-zA-Z0-9-]+)\ effort ]]; then
        printf '%s' "${BASH_REMATCH[1],,}"
        return 0
    fi
    return 1
}

resolve_effort() {
    case $EFFORT_RAW in
        v*) printf '%s' "${EFFORT_RAW#v}"; return ;;
        n)  printf 'default'; return ;;
    esac

    local level settings
    if level=$(effort_from_transcript); then
        printf '%s' "$level"
        return
    fi
    settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
    if [[ -r $settings ]]; then
        level=$(jq -r '.effortLevel // empty' "$settings" 2>/dev/null)
        [[ -n $level ]] && { printf '%s' "${level,,}"; return; }
    fi
    printf 'default'
}

# Compaction events, written to the transcript as compact_boundary markers.
compaction_count() {
    [[ -n $TRANSCRIPT && -r $TRANSCRIPT ]] || { printf '0'; return; }
    local c
    c=$(grep -aF '"compact_boundary"' "$TRANSCRIPT" 2>/dev/null |
        grep -acEv '"isSidechain": ?true')
    printf '%s' "${c:-0}"
}

# /rename title, when the status JSON does not already carry one.
session_name_from_transcript() {
    [[ -n $TRANSCRIPT && -r $TRANSCRIPT ]] || return
    grep -aF '"custom-title"' "$TRANSCRIPT" 2>/dev/null | tail -n1 |
        jq -r 'select(.type == "custom-title") | .customTitle // empty' 2>/dev/null
}

# Last N path segments, ".../"-prefixed when anything was dropped.
shorten_path() {
    local path=$1 n=$2 p i
    local -a parts kept=()
    local IFS=/
    read -r -a parts <<< "$path"
    for p in "${parts[@]}"; do [[ -n $p ]] && kept+=("$p"); done
    (( ${#kept[@]} <= n )) && { printf '%s' "$path"; return; }
    local out=''
    for (( i = ${#kept[@]} - n; i < ${#kept[@]}; i++ )); do out+="/${kept[i]}"; done
    printf '...%s' "$out"
}

# Worktree name, or nothing at all when we are not inside a git work tree
# (ccstatusline's "hide when no git" behaviour) so no stray icon is left over.
git_worktree() {
    [[ -n $GIT_CWD ]] || return
    command -v git >/dev/null 2>&1 || return

    local inside gitdir
    { read -r inside; read -r gitdir; } < <(
        GIT_OPTIONAL_LOCKS=0 git -C "$GIT_CWD" rev-parse --is-inside-work-tree --git-dir 2>/dev/null
    )
    [[ ${inside:-} == 'true' && -n ${gitdir:-} ]] || return

    gitdir=${gitdir//\\//}
    if [[ $gitdir == '.git' || $gitdir == */.git ]]; then
        printf 'main'
    elif [[ $gitdir == *'.git/worktrees/'* ]]; then
        printf '%s' "${gitdir##*.git/worktrees/}"
    elif [[ $gitdir == *'/worktrees/'* ]]; then
        printf '%s' "${gitdir##*/worktrees/}"
    fi
}

# One streaming pass over the transcript for the wide-terminal extras: token
# totals (with ccstatusline's stop_reason de-dup rule so streamed partials are
# not double counted), the cache read/write split, and the user -> assistant
# intervals the session-average speed is built from. Sidechain (subagent) turns
# are excluded from the speed intervals, as ccstatusline does.
# Prints: totalTokens cacheRead cacheCreation activeDurationMs speedTokens
read -r -d '' METRICS_JQ <<'METRICSEOF'
def ms:
  if type == "string" then
    (capture("^(?<b>[0-9T:-]+)(\\.(?<f>[0-9]+))?Z?$") // null) as $c
    | if $c == null then null
      else (($c.b + "Z") | fromdateiso8601) * 1000 + ((($c.f // "0") + "000") | .[0:3] | tonumber)
      end
  else null end;

reduce inputs as $l (
  { usage: [], reqs: [], lastUser: null, hasStop: false };
  if ($l | type) != "object" then .
  else
    (if ($l.message.usage | type) == "object"
     then .usage += [{ u: $l.message.usage, s: $l.message.stop_reason, has: ($l.message | has("stop_reason")) }]
          | .hasStop = (.hasStop or ($l.message | has("stop_reason")))
     else . end)
    | if $l.isApiErrorMessage == true or $l.isSidechain == true then .
      elif $l.type == "user" then .lastUser = ($l.timestamp | ms)
      elif $l.type == "assistant" and ($l.message.usage | type) == "object" then
        ($l.timestamp | ms) as $t
        | .reqs += [{
            i: ($l.message.usage.input_tokens // 0),
            o: ($l.message.usage.output_tokens // 0),
            iv: (if $t != null and .lastUser != null and $t > .lastUser
                 then { s: .lastUser, e: $t } else null end)
          }]
      else . end
  end
)
| . as $st
| ( if $st.hasStop
    then [ $st.usage | to_entries[] | select((.value.s != null and .value.s != false)
             or (.value.s == null and .value.has and .key == (($st.usage | length) - 1))) | .value.u ]
    else [ $st.usage[].u ] end ) as $counted
| ([$counted[].input_tokens // 0] | add // 0) as $in
| ([$counted[].output_tokens // 0] | add // 0) as $out
| ([$counted[].cache_read_input_tokens // 0] | add // 0) as $read
| ([$counted[].cache_creation_input_tokens // 0] | add // 0) as $create
| ([$st.reqs[] | select(.iv != null) | .iv] | sort_by(.s)
   | reduce .[] as $i ([];
       if length == 0 then [$i]
       elif $i.s <= .[-1].e then .[0:-1] + [{ s: .[-1].s, e: ([.[-1].e, $i.e] | max) }]
       else . + [$i] end)
   | [.[] | .e - .s] | add // 0) as $durMs
| ([$st.reqs[] | .i + .o] | add // 0) as $speedTokens
| [ ($in + $out + $read + $create), $read, $create, $durMs, $speedTokens ]
| map(tostring) | join(" ")
METRICSEOF

# Formats the five wide-terminal extras in one awk call, one per line; an empty
# line means "no data, hide the item".
format_extras() {   # total read create durMs speedTokens fiveHour% sevenDay%
    awk -v tot="$1" -v rd="$2" -v cr="$3" -v dur="$4" -v stok="$5" -v five="$6" -v seven="$7" '
        function tokens(c) {
            if (c >= 1000000 - 50) return sprintf("%.1fM", c / 1000000)
            if (c >= 1000)         return sprintf("%.1fk", c / 1000)
            return sprintf("%d", c)
        }
        function speed(t) {
            if (t >= 1000) return sprintf("%.1fk t/s", t / 1000)
            return sprintf("%.1f t/s", t)
        }
        function pct(p) {
            if (p < 0) p = 0; if (p > 100) p = 100
            return sprintf("%.1f%%", p)
        }
        BEGIN {
            if (tot == "") { print ""; print ""; print "" }
            else {
                print tokens(tot)
                print (rd + cr > 0) ? sprintf("%.1f%%", rd / (rd + cr) * 100) : "0.0%"
                print (dur > 0) ? speed(stok / (dur / 1000)) : "\342\200\224"
            }
            print (five  == "") ? "" : pct(five)
            print (seven == "") ? "" : pct(seven)
        }'
}

# cost.total_duration_ms -> "<1m" / "45m" / "2hr" / "2hr 15m"
session_clock() {
    [[ $DURATION_MS =~ ^[0-9]+$ ]] || return
    local mins=$(( DURATION_MS / 60000 ))
    (( mins < 1 )) && { printf '<1m'; return; }
    local h=$(( mins / 60 )) m=$(( mins % 60 ))
    if (( h == 0 )); then printf '%dm' "$m"
    elif (( m == 0 )); then printf '%dhr' "$h"
    else printf '%dhr %dm' "$h" "$m"
    fi
}

# -------------------------------------------------------------- GRADIENT ----

# Per-character true-colour gradient, interpolated in OKLab like ccstatusline.
# Takes the characters as separate arguments; whitespace stays uncoloured.
gradient_text() {
    local -a chars=("$@")
    local c visible=0
    for c in "${chars[@]}"; do [[ $c == ' ' ]] || (( visible++ )); done
    (( visible == 0 )) && { printf '%s' "${chars[*]}"; return; }

    local -a rgb=()
    mapfile -t rgb < <(awk -v n="$visible" -v stops="$GRADIENT_STOPS" '
        function srgb2lin(c,   x) { x = c / 255; return (x <= 0.04045) ? x / 12.92 : ((x + 0.055) / 1.055) ^ 2.4 }
        function lin2srgb(c,   v) { v = (c <= 0.0031308) ? 12.92 * c : 1.055 * (c ^ (1 / 2.4)) - 0.055
                                    if (v < 0) v = 0; if (v > 1) v = 1; return int(v * 255 + 0.5) }
        function cbrt(x) { return (x < 0) ? -((-x) ^ (1 / 3)) : x ^ (1 / 3) }
        BEGIN {
            ns = split(stops, S, " ")
            for (i = 1; i <= ns; i++) {
                split(S[i], P, ",")
                lr = srgb2lin(P[1]); lg = srgb2lin(P[2]); lb = srgb2lin(P[3])
                l = cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
                m = cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
                s = cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)
                L[i] = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
                A[i] = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
                B[i] = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
            }
            den = (n > 1) ? n - 1 : 1
            for (i = 0; i < n; i++) {
                scaled = (i / den) * (ns - 1)
                lo = int(scaled); if (lo > ns - 2) lo = ns - 2; if (lo < 0) lo = 0
                f = scaled - lo
                ll = L[lo + 1] + (L[lo + 2] - L[lo + 1]) * f
                aa = A[lo + 1] + (A[lo + 2] - A[lo + 1]) * f
                bb = B[lo + 1] + (B[lo + 2] - B[lo + 1]) * f
                lc = ll + 0.3963377774 * aa + 0.2158037573 * bb
                mc = ll - 0.1055613458 * aa - 0.0638541728 * bb
                sc = ll - 0.0894841775 * aa - 1.2914855480 * bb
                l3 = lc ^ 3; m3 = mc ^ 3; s3 = sc ^ 3
                printf "%d;%d;%d\n", lin2srgb(4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3),
                                     lin2srgb(-1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3),
                                     lin2srgb(-0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3)
            }
        }')

    local out='' idx=0
    for c in "${chars[@]}"; do
        if [[ $c == ' ' ]]; then
            out+=' '
        else
            out+="${ESC}[38;2;${rgb[idx]:-255;255;255}m$c"
            (( idx++ ))
        fi
    done
    printf '%s' "$out"
}

# First gradient stop — colours the separator that follows the bar.
gradient_head() {
    local first=${GRADIENT_STOPS%% *}
    printf '%s[38;2;%sm' "$ESC" "${first//,/;}"
}

# -------------------------------------------------------------- ASSEMBLY ----

E_TXT=() E_LEN=() E_CLR=() E_FLEX=() E_MERGE=()

add_widget() {   # colour-code text [visible-length]
    local code=$1 text=$2
    [[ -n $text ]] || return
    local len=${3:-}
    [[ -n $len ]] || len=$(plainlen "$text")
    E_TXT+=("${ESC}[${code}m${text}${ESC}[39m")
    E_LEN+=("$len")
    E_CLR+=("${ESC}[${code}m")
    E_FLEX+=(0)
    E_MERGE+=(0)
}

add_styled() {   # pre-coloured-text visible-length separator-colour-prefix
    E_TXT+=("$1${ESC}[39m")
    E_LEN+=("$2")
    E_CLR+=("$3")
    E_FLEX+=(0)
    E_MERGE+=(0)
}

add_flex() { E_TXT+=('') E_LEN+=(0) E_CLR+=('') E_FLEX+=(1) E_MERGE+=(0); }

# Join the item just added to the next one with MERGE_GLUE instead of SEPARATOR.
merge_last() {
    local last=$(( ${#E_MERGE[@]} - 1 ))
    (( last >= 0 )) && E_MERGE[last]=1
}

# --- widgets ----------------------------------------------------------------

# Probed once: the flex maths below needs it too. Empty means "unknown", in
# which case the session group is kept rather than hidden on a guess.
TERM_COLS=$(term_width)
SHOW_SESSION=1
[[ $TERM_COLS =~ ^[0-9]+$ ]] && (( TERM_COLS < SESSION_MIN_COLS )) && SHOW_SESSION=0

# model and thinking effort share one item: "Opus 5 [high]"
effort=$(resolve_effort)
if [[ -n $MODEL && -n $effort ]]; then
    add_widget "$C_MODEL" "$MODEL [$effort]"
elif [[ -n $MODEL ]]; then
    add_widget "$C_MODEL" "$MODEL"
else
    add_widget "$C_EFFORT" "$effort"
fi
merge_last          # no " - " between the model and what follows

# fast mode, shown only while it is on
[[ $FAST_MODE == '1' ]] && { add_widget "$C_FAST" "$FAST_LABEL" "$FAST_LABEL_WIDTH"; merge_last; }

# context bar: minimal slider + "used/total (pct%)" under the morning gradient
if [[ $CTX_USED =~ ^[0-9]+$ && $CTX_TOTAL =~ ^[0-9]+$ ]] && (( CTX_TOTAL > 0 )); then
    pct=$(awk -v u="$CTX_USED" -v t="$CTX_TOTAL" 'BEGIN {
        p = u / t * 100; if (p < 0) p = 0; if (p > 100) p = 100; printf "%.4f", p }')
    filled=$(awk -v p="$pct" -v w="$BAR_WIDTH" 'BEGIN { printf "%d", int(p / 100 * w + 0.5) }')

    bar_chars=()
    for (( i = 0; i < BAR_WIDTH; i++ )); do
        if (( i < filled )); then bar_chars+=("$BAR_FILLED"); else bar_chars+=("$BAR_EMPTY"); fi
    done

    tail_text=" $(format_tokens "$CTX_USED" 0)/$(format_tokens "$CTX_TOTAL" 0) ($(round "$pct")%)"
    for (( i = 0; i < ${#tail_text}; i++ )); do bar_chars+=("${tail_text:i:1}"); done

    add_styled "$(gradient_text "${bar_chars[@]}")" \
               "$(( BAR_WIDTH + ${#tail_text} ))" \
               "$(gradient_head)"
fi

add_widget "$C_COMPACTION" "$ICON_COMPACTION $(compaction_count)"

add_flex

[[ -n $CWD ]] && add_widget "$C_CWD" "$(shorten_path "$CWD" "$CWD_SEGMENTS")"
worktree=$(git_worktree)
[[ -n $worktree ]] && add_widget "$C_WORKTREE" "${ICON_WORKTREE}${worktree}"

# lines changed this session; each half is omitted while it is still zero
if [[ $LINES_ADDED =~ ^[0-9]+$ ]] && (( LINES_ADDED > 0 )); then
    add_widget "$C_ADDED" "+$LINES_ADDED"
    merge_last
fi
if [[ $LINES_REMOVED =~ ^[0-9]+$ ]] && (( LINES_REMOVED > 0 )); then
    add_widget "$C_REMOVED" "-$LINES_REMOVED"
fi

# Right-hand session group: duration and name/id. Dropped entirely on narrow
# terminals, along with its flex separator, so the cwd group moves to the edge
# instead of leaving a dead gap where the group used to be.
if (( SHOW_SESSION )); then
    add_flex

    clock=$(session_clock)
    [[ -n $clock ]] && add_widget "$C_CLOCK" "$ICON_CLOCK $clock"
    # session name and id share one item: "my-session [abc123...]"
    [[ -z $SESSION_NAME ]] && SESSION_NAME=$(session_name_from_transcript)
    if [[ -n $SESSION_NAME && -n $SESSION_ID ]]; then
        add_widget "$C_SESSION" "$SESSION_NAME [$SESSION_ID]"
    elif [[ -n $SESSION_NAME ]]; then
        add_widget "$C_SESSION" "$SESSION_NAME"
    else
        add_widget "$C_SESSION" "$SESSION_ID"
    fi

    # Wide terminals only: token total, cache hit rate, session-average speed,
    # and the 5-hour / 7-day rate-limit usage. The first three need a full
    # transcript pass, so the width gate keeps that cost off narrow layouts.
    if [[ $TERM_COLS =~ ^[0-9]+$ ]] && (( TERM_COLS > EXTRA_MIN_COLS )); then
        metrics=''
        [[ -n $TRANSCRIPT && -r $TRANSCRIPT ]] &&
            metrics=$(jq -nrj -f <(printf '%s' "$METRICS_JQ") "$TRANSCRIPT" 2>/dev/null)
        read -r m_total m_read m_create m_dur m_speed <<< "${metrics:-}"

        mapfile -t EXTRAS < <(format_extras "${m_total:-}" "${m_read:-0}" "${m_create:-0}" \
                                            "${m_dur:-0}" "${m_speed:-0}" \
                                            "$FIVE_HOUR_PCT" "$SEVEN_DAY_PCT")
        [[ -n ${EXTRAS[0]:-} ]] && add_widget "$C_TOKENS" "$ICON_TOKENS ${EXTRAS[0]}"
        [[ -n ${EXTRAS[1]:-} ]] && add_widget "$C_CACHE"  "$ICON_CACHE ${EXTRAS[1]}"
        [[ -n ${EXTRAS[2]:-} ]] && add_widget "$C_SPEED"  "$ICON_SPEED ${EXTRAS[2]}"
        [[ -n ${EXTRAS[3]:-} ]] && add_widget "$C_USAGE"  "$LABEL_FIVE_HOUR ${EXTRAS[3]}"
        [[ -n ${EXTRAS[4]:-} ]] && add_widget "$C_USAGE"  "$LABEL_SEVEN_DAY ${EXTRAS[4]}"
    fi
fi

# --- join, flex, truncate ---------------------------------------------------

out='' total=0 nflex=0 prev=-1
for (( i = 0; i < ${#E_TXT[@]}; i++ )); do
    if (( E_FLEX[i] )); then
        out+=$SENTINEL
        (( nflex++ ))
        prev=$i
        continue
    fi
    if (( prev >= 0 )) && (( ! E_FLEX[prev] )); then
        if (( E_MERGE[prev] )); then
            out+=$MERGE_GLUE
            (( total += ${#MERGE_GLUE} ))
        else
            out+="${E_CLR[prev]}${SEPARATOR}${ESC}[39m"
            (( total += ${#SEPARATOR} ))
        fi
    fi
    out+=${E_TXT[i]}
    (( total += E_LEN[i] ))
    prev=$i
done

width=$TERM_COLS
if [[ $width =~ ^[0-9]+$ ]]; then
    (( width -= FLEX_RESERVE ))
    (( width < 0 )) && width=0
else
    width=0
fi

if (( nflex > 0 )); then
    if (( width > 0 )); then
        space=$(( width - total ))
        (( space < 0 )) && space=0
        per=$(( space / nflex ))
        extra=$(( space % nflex ))
        result='' idx=0
        while [[ $out == *"$SENTINEL"* ]]; do
            head=${out%%"$SENTINEL"*}
            out=${out#*"$SENTINEL"}
            pad=$per
            (( idx < extra )) && (( pad++ ))
            printf -v spaces '%*s' "$pad" ''
            result+="$head$spaces"
            (( total += pad ))
            (( idx++ ))
        done
        out=$result$out
    else
        out=${out//"$SENTINEL"/ }
        (( total += nflex ))
    fi
fi

# `total` is the exact visible width (widgets + separators + flex padding).
if (( width > 0 )) && (( total > width )); then
    out=$(truncate_styled "$out" "$width")
fi

printf '%s%s[0m\n' "$out" "$ESC"
