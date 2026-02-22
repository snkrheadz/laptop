#!/bin/bash
# Claude Code Status Line Script
# Displays: Model | Dir+Branch | Duration | Cost(session/daily) | Lines | Tokens(I/O/CR/CC) | Context Bar
# Token labels: I=Input, O=Output, CR=CacheRead, CC=CacheCreate
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
RED=$'\033[31m'
YELLOW=$'\033[33m'
GREEN=$'\033[32m'
RESET=$'\033[0m'

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
  "AGENT_NAME=" + (.agent.name // "" | @sh)
')" 2>/dev/null

# Fallback defaults if jq parsing failed
: "${MODEL:=Unknown}" "${CURRENT_DIR:=.}" "${COST:=0}" "${SESSION_ID:=unknown}"
: "${DURATION_MS:=0}" "${LINES_ADDED:=0}" "${LINES_REMOVED:=0}"
: "${USED_PCT:=0}" "${CTX_SIZE:=0}" "${EXCEEDS_200K:=false}"
: "${INPUT_TOKENS:=0}" "${CACHE_READ:=0}" "${CACHE_CREATE:=0}"
: "${OUTPUT_TOKENS:=0}" "${TOTAL_INPUT_TOKENS:=0}" "${TOTAL_OUTPUT_TOKENS:=0}" "${REMAINING_PCT:=0}"

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

# [6] Token breakdown: I:Xk O:Xk CR:Xk CC:Xk (skip if no API call yet)
TOTAL_INPUT=$((INPUT_TOKENS + CACHE_READ + CACHE_CREATE))
if [ "$TOTAL_INPUT" -gt 0 ] || [ "$OUTPUT_TOKENS" -gt 0 ]; then
    SEGMENTS+=("I:$(format_tokens "$INPUT_TOKENS") O:$(format_tokens "$OUTPUT_TOKENS") CR:$(format_tokens "$CACHE_READ") CC:$(format_tokens "$CACHE_CREATE")")
fi

# [7] Context usage with progress bar and color
if [ "$CTX_SIZE" -gt 0 ]; then
    PCT=${USED_PCT%%.*}
    PCT=${PCT:-0}

    # Format context window size
    if [ "$CTX_SIZE" -ge 1000000 ]; then
        CTX_LABEL="$((CTX_SIZE / 1000000))M"
    elif [ "$CTX_SIZE" -ge 1000 ]; then
        CTX_LABEL="$((CTX_SIZE / 1000))k"
    else
        CTX_LABEL="$CTX_SIZE"
    fi

    # Build progress bar (10 chars wide)
    BAR_WIDTH=10
    FILLED=$((PCT * BAR_WIDTH / 100))
    [ "$FILLED" -gt "$BAR_WIDTH" ] && FILLED=$BAR_WIDTH
    EMPTY=$((BAR_WIDTH - FILLED))
    BAR=""
    for ((i = 0; i < FILLED; i++)); do BAR+="█"; done
    for ((i = 0; i < EMPTY; i++)); do BAR+="░"; done

    # Remaining tokens
    REMAINING_TOKENS=$((CTX_SIZE * REMAINING_PCT / 100))
    LEFT_LABEL="$(format_tokens "$REMAINING_TOKENS") left"

    # Icon + color based on usage level
    if [ "$EXCEEDS_200K" = "true" ]; then
        SEGMENTS+=("🔴 ${CTX_LABEL}+ ${PCT}% ${RED}${BAR}${RESET} ${LEFT_LABEL}")
    elif [ "$PCT" -ge 80 ]; then
        SEGMENTS+=("⚠️ ${CTX_LABEL} ${PCT}% ${RED}${BAR}${RESET} ${LEFT_LABEL}")
    elif [ "$PCT" -ge 60 ]; then
        SEGMENTS+=("🧠 ${CTX_LABEL} ${PCT}% ${YELLOW}${BAR}${RESET} ${LEFT_LABEL}")
    else
        SEGMENTS+=("🧠 ${CTX_LABEL} ${PCT}% ${GREEN}${BAR}${RESET} ${LEFT_LABEL}")
    fi
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
