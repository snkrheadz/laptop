#!/bin/bash
# Claude Code Status Line Script
# Displays: Model | Dir+Branch | Duration | Cost(session/daily) | Lines | Braille Token Bar
# Token bar: 🧠 ⣿⣿⡇⠀⠀ PCT% IN:⣿⡇ CR:⣿⣿ OUT:⡀⠀ Nk left
#   Braille dots (⠀–⣿) show fill level; TrueColor gradient green→yellow→red by context %
#
# Installation:
#   1. Symlink to ~/.claude/statusline.sh
#   2. Add to ~/.claude/settings.json:
#      "statusLine": { "type": "command", "command": "~/.claude/statusline.sh", "padding": 0 }

input=$(cat)

if ! command -v jq &>/dev/null; then
    echo "jq not found"
    exit 0
fi

# === ANSI Colors ===
RESET=$'\033[0m'

# === Braille Dots helpers (matches Pattern 5 sample) ===
# BRAILLE[0]=space(empty) … BRAILLE[7]=⣿(full)
BRAILLE=(' ' '⣀' '⣄' '⣤' '⣦' '⣶' '⣷' '⣿')
DIM=$'\033[2m'

# TrueColor gradient matching the Python sample:
#   pct<50 : r=int(pct*5.1), g=200, b=80  (green)
#   pct>=50: r=255, g=max(200-(pct-50)*4,0), b=60  (orange→red)
gradient() {
    local pct=$1 r g
    if [ "$pct" -lt 50 ]; then
        r=$((pct * 51 / 10))
        printf '\033[38;2;%d;200;80m' "$r"
    else
        g=$((200 - (pct - 50) * 4))
        [ "$g" -lt 0 ] && g=0
        printf '\033[38;2;255;%d;60m' "$g"
    fi
}

# Build Braille bar matching the Python braille_bar() logic exactly
braille_bar() {
    local pct=$1 width=${2:-8} bar="" i idx frac_num
    [ "$pct" -lt 0 ] && pct=0
    [ "$pct" -gt 100 ] && pct=100
    for ((i = 0; i < width; i++)); do
        if [ $((pct * width)) -ge $((100 * (i + 1))) ]; then
            bar+="${BRAILLE[7]}"
        elif [ $((pct * width)) -le $((100 * i)) ]; then
            bar+="${BRAILLE[0]}"
        else
            frac_num=$((pct * width - 100 * i))
            idx=$((frac_num * 7 / 100))
            [ "$idx" -gt 7 ] && idx=7
            bar+="${BRAILLE[$idx]}"
        fi
    done
    printf '%s' "$bar"
}

# === Extract all values in a single jq call ===
eval "$(echo "$input" | jq -r '
  "MODEL=" + (.model.display_name // "Unknown" | @sh),
  "CURRENT_DIR=" + (.workspace.current_dir // "." | @sh),
  "COST=" + (.cost.total_cost_usd // 0 | tostring | @sh),
  "SESSION_ID=" + (.session_id // "unknown" | @sh),
  "DURATION_MS=" + (.cost.total_duration_ms // 0 | tostring | @sh),
  "LINES_ADDED=" + (.cost.total_lines_added // 0 | tostring | @sh),
  "LINES_REMOVED=" + (.cost.total_lines_removed // 0 | tostring | @sh),
  "USED_PCT=" + (.context_window.used_percentage // 0 | tostring | @sh),
  "CTX_SIZE=" + (.context_window.context_window_size // 0 | tostring | @sh),
  "EXCEEDS_200K=" + (.exceeds_200k_tokens // false | tostring | @sh),
  "INPUT_TOKENS=" + (.context_window.current_usage.input_tokens // 0 | tostring | @sh),
  "CACHE_READ=" + (.context_window.current_usage.cache_read_input_tokens // 0 | tostring | @sh),
  "CACHE_CREATE=" + (.context_window.current_usage.cache_creation_input_tokens // 0 | tostring | @sh),
  "OUTPUT_TOKENS=" + (.context_window.current_usage.output_tokens // 0 | tostring | @sh),
  "TOTAL_INPUT_TOKENS=" + (.context_window.total_input_tokens // 0 | tostring | @sh),
  "TOTAL_OUTPUT_TOKENS=" + (.context_window.total_output_tokens // 0 | tostring | @sh),
  "REMAINING_PCT=" + (.context_window.remaining_percentage // 0 | tostring | @sh),
  "VIM_MODE=" + (.vim.mode // "" | @sh),
  "AGENT_NAME=" + (.agent.name // "" | @sh),
  "FIVE_HOUR_PCT=" + (.rate_limits.five_hour.used_percentage // -1 | tostring | @sh),
  "SEVEN_DAY_PCT=" + (.rate_limits.seven_day.used_percentage // -1 | tostring | @sh)
')" 2>/dev/null

# Fallback defaults if jq parsing failed
: "${MODEL:=Unknown}" "${CURRENT_DIR:=.}" "${COST:=0}" "${SESSION_ID:=unknown}"
: "${DURATION_MS:=0}" "${LINES_ADDED:=0}" "${LINES_REMOVED:=0}"
: "${USED_PCT:=0}" "${CTX_SIZE:=0}" "${EXCEEDS_200K:=false}"
: "${INPUT_TOKENS:=0}" "${CACHE_READ:=0}" "${CACHE_CREATE:=0}"
: "${OUTPUT_TOKENS:=0}" "${TOTAL_INPUT_TOKENS:=0}" "${TOTAL_OUTPUT_TOKENS:=0}" "${REMAINING_PCT:=0}"
: "${FIVE_HOUR_PCT:=-1}" "${SEVEN_DAY_PCT:=-1}"

DIR_NAME="${CURRENT_DIR##*/}"

# === Git branch with 5s cache ===
GIT_BRANCH=""
CACHE_FILE="/tmp/statusline-git-${DIR_NAME}"
if [ -f "$CACHE_FILE" ] && [ $(($(date +%s) - $(stat -f%m "$CACHE_FILE" 2>/dev/null || echo 0))) -lt 5 ]; then
    GIT_BRANCH=$(<"$CACHE_FILE")
else
    if git -C "$CURRENT_DIR" rev-parse --git-dir &>/dev/null; then
        GIT_BRANCH=$(git -C "$CURRENT_DIR" branch --show-current 2>/dev/null)
    fi
    printf '%s' "$GIT_BRANCH" > "$CACHE_FILE"
fi

BRANCH_DISPLAY=""
if [ -n "$GIT_BRANCH" ]; then
    if [ ${#GIT_BRANCH} -gt 20 ]; then
        GIT_BRANCH="${GIT_BRANCH:0:17}..."
    fi
    BRANCH_DISPLAY=" 🌿${GIT_BRANCH}"
fi

# === Duration formatting ===
format_duration() {
    local ms=$1
    local secs=$((ms / 1000))
    if [ "$secs" -ge 3600 ]; then
        printf '%dh%dm' $((secs / 3600)) $((secs % 3600 / 60))
    elif [ "$secs" -ge 60 ]; then
        printf '%dm' $((secs / 60))
    else
        printf '%ds' "$secs"
    fi
}

# === Format token count: 500→500, 8000→8k, 1500000→1.5M ===
format_tokens() {
    local n=$1
    if [ "$n" -ge 1000000 ]; then
        awk -v n="$n" 'BEGIN { printf "%.1fM", n/1000000 }'
    elif [ "$n" -ge 1000 ]; then
        printf '%dk' $((n / 1000))
    else
        printf '%d' "$n"
    fi
}

# === Daily cumulative cost tracking ===
TODAY=$(date +%Y-%m-%d)
USAGE_DIR="$HOME/.claude/usage"
USAGE_FILE="$USAGE_DIR/$TODAY.json"
mkdir -p "$USAGE_DIR"

if [ ! -f "$USAGE_FILE" ]; then
    echo '{"sessions":{}}' > "$USAGE_FILE"
fi

LOCK_FILE="$USAGE_FILE.lock"
exec 200>"$LOCK_FILE"
flock -w 2 200 2>/dev/null || true

jq --arg sid "$SESSION_ID" --argjson cost "$COST" \
    --argjson tin "$TOTAL_INPUT_TOKENS" --argjson tout "$TOTAL_OUTPUT_TOKENS" \
    '.sessions[$sid] = $cost | .tokens[$sid] = {in: $tin, out: $tout}' \
    "$USAGE_FILE" > "$USAGE_FILE.tmp" 2>/dev/null \
    && mv "$USAGE_FILE.tmp" "$USAGE_FILE"

DAILY_TOTAL=$(jq '[.sessions | to_entries[] | .value] | add // 0' "$USAGE_FILE" 2>/dev/null || echo "0")

exec 200>&-

# === Build output segments ===
SEGMENTS=()

# [1] Model
SEGMENTS+=("$MODEL")

# [2] Directory + Branch
SEGMENTS+=("${DIR_NAME}${BRANCH_DISPLAY}")

# [3] Session duration
SEGMENTS+=("⏱ $(format_duration "$DURATION_MS")")

# [4] Cost: session / daily
SEGMENTS+=("💰$(printf '$%.2f/$%.2f' "$COST" "$DAILY_TOTAL")")

# [5] Lines changed (skip if zero)
if [ "$LINES_ADDED" -gt 0 ] || [ "$LINES_REMOVED" -gt 0 ]; then
    SEGMENTS+=("+${LINES_ADDED}-${LINES_REMOVED}")
fi

# [6] Braille context bar — matches Python fmt(): {DIM}label{R} {gradient_bar} {pct}%
if [ "$CTX_SIZE" -gt 0 ]; then
    PCT=${USED_PCT%%.*}
    PCT=${PCT:-0}
    CTX_COLOR=$(gradient "$PCT")
    CTX_BAR=$(braille_bar "$PCT" 8)
    SEGMENTS+=("${DIM}ctx${RESET} ${CTX_COLOR}${CTX_BAR}${RESET} ${PCT}%")
fi

# [7] 5h rate limit bar (only if data exists)
if [ "$FIVE_HOUR_PCT" -ge 0 ] 2>/dev/null; then
    FH_PCT=${FIVE_HOUR_PCT%%.*}
    FH_COLOR=$(gradient "$FH_PCT")
    FH_BAR=$(braille_bar "$FH_PCT" 8)
    SEGMENTS+=("${DIM}5h${RESET} ${FH_COLOR}${FH_BAR}${RESET} ${FH_PCT}%")
fi

# [8] 7d rate limit bar (only if data exists)
if [ "$SEVEN_DAY_PCT" -ge 0 ] 2>/dev/null; then
    SD_PCT=${SEVEN_DAY_PCT%%.*}
    SD_COLOR=$(gradient "$SD_PCT")
    SD_BAR=$(braille_bar "$SD_PCT" 8)
    SEGMENTS+=("${DIM}7d${RESET} ${SD_COLOR}${SD_BAR}${RESET} ${SD_PCT}%")
fi

# [8] Vim mode (if active)
if [ -n "$VIM_MODE" ]; then
    SEGMENTS+=("$VIM_MODE")
fi

# [9] Agent name (if running as subagent)
if [ -n "$AGENT_NAME" ]; then
    SEGMENTS+=("🤖${AGENT_NAME}")
fi

# === Join segments with " | " and output ===
OUTPUT=""
for ((i = 0; i < ${#SEGMENTS[@]}; i++)); do
    [ $i -gt 0 ] && OUTPUT+=" | "
    OUTPUT+="${SEGMENTS[$i]}"
done

printf '%s\n' "$OUTPUT"
