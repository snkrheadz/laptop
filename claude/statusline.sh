#!/bin/bash
# Claude Code Status Line Script
# Displays: Model | Directory | Git Branch | Daily Cost | Token Info | Context Info
#
# Installation:
#   1. Symlink to ~/.claude/statusline.sh
#   2. Add to ~/.claude/settings.json:
#      "statusLine": { "type": "command", "command": "~/.claude/statusline.sh", "padding": 0 }

input=$(cat)

# Check jq dependency
if ! command -v jq &>/dev/null; then
    echo "[statusline] jq not found"
    exit 0
fi

# === Helper function: Format number to K notation ===
format_k() {
    local num=$1
    if [ "$num" -ge 1000 ]; then
        awk "BEGIN {printf \"%.1fk\", $num/1000}"
    else
        echo "$num"
    fi
}

# JSON parsing (requires jq)
MODEL=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir // "."')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
SESSION_ID=$(echo "$input" | jq -r '.session_id // "unknown"')

# Extract directory name only
DIR_NAME="${CURRENT_DIR##*/}"

# Get Git branch
GIT_BRANCH=""
if git -C "$CURRENT_DIR" rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git -C "$CURRENT_DIR" branch --show-current 2>/dev/null)
    if [ -n "$BRANCH" ]; then
        GIT_BRANCH=" | 🌿 $BRANCH"
    fi
fi

# === Daily cumulative cost calculation ===
TODAY=$(date +%Y-%m-%d)
USAGE_DIR="$HOME/.claude/usage"
USAGE_FILE="$USAGE_DIR/$TODAY.json"

# Create directory
mkdir -p "$USAGE_DIR"

# Initialize today's file if it doesn't exist
if [ ! -f "$USAGE_FILE" ]; then
    echo '{"sessions":{}}' > "$USAGE_FILE"
fi

# Update session cost and calculate daily total (with file lock for concurrent writes)
LOCK_FILE="$USAGE_FILE.lock"
exec 200>"$LOCK_FILE"
flock -w 2 200 2>/dev/null || true

jq --arg sid "$SESSION_ID" --argjson cost "$COST" '
    .sessions[$sid] = $cost
' "$USAGE_FILE" > "$USAGE_FILE.tmp" 2>/dev/null && mv "$USAGE_FILE.tmp" "$USAGE_FILE"

DAILY_TOTAL=$(jq --arg sid "$SESSION_ID" --argjson cost "$COST" '
    .sessions[$sid] = $cost |
    [.sessions | to_entries[] | .value] | add // 0
' "$USAGE_FILE" 2>/dev/null || echo "0")

exec 200>&-

# Cost display
DAILY_DISPLAY=$(printf '$%.2f' "$DAILY_TOTAL")

# === Token and Context calculation ===
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
USAGE=$(echo "$input" | jq -r '.context_window.current_usage // null')

TOKEN_DISPLAY=""
CONTEXT_DISPLAY=""

if [ "$USAGE" != "null" ] && [ "$CONTEXT_SIZE" != "0" ]; then
    # Extract token values
    INPUT_TOKENS=$(echo "$USAGE" | jq -r '.input_tokens // 0')
    OUTPUT_TOKENS=$(echo "$USAGE" | jq -r '.output_tokens // 0')
    CACHE_CREATE=$(echo "$USAGE" | jq -r '.cache_creation_input_tokens // 0')
    CACHE_READ=$(echo "$USAGE" | jq -r '.cache_read_input_tokens // 0')

    # Calculate total tokens
    TOTAL_TOKENS=$((INPUT_TOKENS + OUTPUT_TOKENS + CACHE_CREATE + CACHE_READ))

    # Token display: 🎫 In:8.5k Out:1.2k C:2.0k Tot:11.7k
    TOKEN_DISPLAY="🎫 In:$(format_k "$INPUT_TOKENS") Out:$(format_k "$OUTPUT_TOKENS") C:$(format_k "$CACHE_READ") Tot:$(format_k "$TOTAL_TOKENS")"

    # Context percentage calculation
    CONTEXT_PERCENT=$((TOTAL_TOKENS * 100 / CONTEXT_SIZE))

    # Usable context = ~95% of context_window_size (Claude's internal limit)
    USABLE_SIZE=$((CONTEXT_SIZE * 95 / 100))
    USABLE_PERCENT=$((TOTAL_TOKENS * 100 / USABLE_SIZE))

    # Context display: 🧠 200.0k 8% (9%)
    CONTEXT_DISPLAY="🧠 $(format_k "$CONTEXT_SIZE") ${CONTEXT_PERCENT}% (${USABLE_PERCENT}%)"
fi

# Final output
if [ -n "$TOKEN_DISPLAY" ] && [ -n "$CONTEXT_DISPLAY" ]; then
    echo "[$MODEL] 📁 $DIR_NAME$GIT_BRANCH | 💰 $DAILY_DISPLAY | $TOKEN_DISPLAY | $CONTEXT_DISPLAY"
else
    echo "[$MODEL] 📁 $DIR_NAME$GIT_BRANCH | 💰 $DAILY_DISPLAY"
fi
