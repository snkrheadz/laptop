#!/bin/bash
# Notification hook: speak a short voice cue matched to the notification reason.
# Replaces the former inline `say 'Claude needs input'` command in settings.json,
# which was invisible to verify.sh's hook-wiring gate (no hooks/*.sh path to
# grep) and wrong for completion events: since v2.1.198 the Notification event
# also fires on agent_completed, which the fixed message announced as "needs
# input" (audit #127 finding 2).
#
# Branches on the stdin JSON's notification_type (the field Notification
# matchers match against; verified against the v2.1.220 binary):
#   agent_completed  → "Claude finished a task"
#   auth_success     → silent (nothing actionable to announce)
#   anything else    → "Claude needs input" (permission_prompt, idle_prompt,
#                      elicitation_*, agent_needs_input, unknown values)
# Fail-open: missing jq or unparseable stdin falls back to the previous
# behavior ("Claude needs input"); missing `say` is a no-op. Always exits 0.

input=$(cat)

ntype=""
if command -v jq &>/dev/null; then
    ntype=$(printf '%s' "$input" | jq -r '.notification_type // ""' 2>/dev/null)
fi

case "$ntype" in
    agent_completed) msg="Claude finished a task" ;;
    auth_success)    msg="" ;;
    *)               msg="Claude needs input" ;;
esac

if [ -n "$msg" ] && command -v say &>/dev/null; then
    say "$msg" 2>/dev/null
fi

exit 0
