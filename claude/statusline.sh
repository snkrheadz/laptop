#!/bin/bash
# Claude Code Status Line Script
# Displays: Model | Directory | Git Branch | Daily Cost | Context Remaining
#
# Installation:
#   1. Symlink to ~/.claude/statusline.sh
#   2. Add to ~/.claude/settings.json:
#      "statusLine": { "type": "command", "command": "~/.claude/statusline.sh", "padding": 0 }

input=$(cat)

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

# Update session cost and calculate daily total
DAILY_TOTAL=$(jq --arg sid "$SESSION_ID" --argjson cost "$COST" '
    .sessions[$sid] = $cost |
    [.sessions | to_entries[] | .value] | add // 0
' "$USAGE_FILE")

# Update file (save session info)
jq --arg sid "$SESSION_ID" --argjson cost "$COST" '
    .sessions[$sid] = $cost
' "$USAGE_FILE" > "$USAGE_FILE.tmp" && mv "$USAGE_FILE.tmp" "$USAGE_FILE"

# Cost display
DAILY_DISPLAY=$(printf '$%.2f' "$DAILY_TOTAL")

# Context remaining calculation
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
USAGE=$(echo "$input" | jq -r '.context_window.current_usage // null')

CONTEXT_DISPLAY=""
if [ "$USAGE" != "null" ] && [ "$CONTEXT_SIZE" != "0" ]; then
    INPUT_TOKENS=$(echo "$USAGE" | jq -r '.input_tokens // 0')
    CACHE_CREATE=$(echo "$USAGE" | jq -r '.cache_creation_input_tokens // 0')
    CACHE_READ=$(echo "$USAGE" | jq -r '.cache_read_input_tokens // 0')
    CURRENT_TOKENS=$((INPUT_TOKENS + CACHE_CREATE + CACHE_READ))
    REMAINING=$((CONTEXT_SIZE - CURRENT_TOKENS))
    REMAINING_K=$((REMAINING / 1000))
    CONTEXT_DISPLAY=" | 📊 ${REMAINING_K}k"
fi

echo "[$MODEL] 📁 $DIR_NAME$GIT_BRANCH | 💰 $DAILY_DISPLAY (Today)$CONTEXT_DISPLAY"
