#!/bin/bash
# Stop hook: fire a one-shot native notification when session or daily cost
# crosses a threshold. Cost isn't shown in statusline.sh anymore (it's not a
# signal for whether to keep trusting the agent's autonomous run) — this
# replaces that constant display with an on-crossing alert instead, reusing
# the daily usage file statusline.sh already maintains on every render.
#
# Thresholds are overridable via env: CLAUDE_COST_SESSION_THRESHOLD (default 5),
# CLAUDE_COST_DAILY_THRESHOLD (default 20). Fires at most once per threshold
# per session (state kept in /tmp, keyed by session_id) — never blocks.

input=$(cat)

command -v jq &>/dev/null || exit 0

session_id="unknown" cost="0"
eval "$(echo "$input" | jq -r '
  @sh "session_id=\(.session_id // "unknown")",
  @sh "cost=\(.cost.total_cost_usd // 0)"
' 2>/dev/null)"

SESSION_THRESHOLD="${CLAUDE_COST_SESSION_THRESHOLD:-5}"
DAILY_THRESHOLD="${CLAUDE_COST_DAILY_THRESHOLD:-20}"

TODAY=$(date +%Y-%m-%d)
USAGE_FILE="$HOME/.claude/usage/$TODAY.json"
daily=0
if [ -f "$USAGE_FILE" ]; then
    daily=$(jq '[.sessions | to_entries[] | .value] | add // 0' "$USAGE_FILE" 2>/dev/null)
    daily=${daily:-0}
fi

STATE_FILE="/tmp/claude-cost-alert-${session_id}"
notified_session=0
notified_daily=0
if [ -f "$STATE_FILE" ]; then
    read -r notified_session notified_daily < "$STATE_FILE" 2>/dev/null
    notified_session=${notified_session:-0}
    notified_daily=${notified_daily:-0}
fi

session_hit=$(awk -v c="$cost" -v t="$SESSION_THRESHOLD" 'BEGIN { print (c >= t) ? 1 : 0 }')
daily_hit=$(awk -v c="$daily" -v t="$DAILY_THRESHOLD" 'BEGIN { print (c >= t) ? 1 : 0 }')

if [ "$session_hit" = "1" ] && [ "$notified_session" = "0" ]; then
    session_fmt=$(awk -v c="$cost" 'BEGIN { printf "%.2f", c }')
    osascript -e "display notification \"session cost \$${session_fmt} crossed \$${SESSION_THRESHOLD}\" with title \"Claude Code\"" 2>/dev/null
    notified_session=1
fi

if [ "$daily_hit" = "1" ] && [ "$notified_daily" = "0" ]; then
    daily_fmt=$(awk -v c="$daily" 'BEGIN { printf "%.2f", c }')
    osascript -e "display notification \"daily cost \$${daily_fmt} crossed \$${DAILY_THRESHOLD}\" with title \"Claude Code\"" 2>/dev/null
    notified_daily=1
fi

printf '%s %s\n' "$notified_session" "$notified_daily" > "$STATE_FILE"

exit 0
