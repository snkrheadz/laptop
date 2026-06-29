#!/bin/bash
# Stop hook: surface ground-truth git/GitHub state when the model claimed a
# git action this turn, so false-success reports (phantom commits/pushes/PRs)
# get caught against reality instead of self-report.
#
# Design (kept near-silent on purpose):
#   - Only speaks up when the LAST assistant message claims a commit/push/PR/merge.
#   - Injects actual `git` (and best-effort `gh pr`) state via additionalContext,
#     which continues the turn once so the model reconciles its claim vs truth.
#   - `stop_hook_active` guard prevents an infinite stop->continue loop.
# Always exits 0; never blocks.

input=$(cat)

stop_hook_active="" cwd="" transcript=""
eval "$(echo "$input" | jq -r '
  @sh "stop_hook_active=\(.stop_hook_active // false)",
  @sh "cwd=\(.cwd // "")",
  @sh "transcript=\(.transcript_path // "")"
' 2>/dev/null)"

# Already in a hook-triggered continuation -> stop cleanly (no loop).
[[ "$stop_hook_active" == "true" ]] && exit 0

# Only meaningful inside a git repo.
[[ -n "$cwd" ]] || exit 0
git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Pull the last assistant text block from the transcript.
last_text=""
if [[ -n "$transcript" && -f "$transcript" ]]; then
    last_text=$(tail -n 80 "$transcript" 2>/dev/null | jq -rs '
        [ .[] | select(.type=="assistant") ] as $a
        | if ($a|length) > 0
          then ($a[-1].message.content // [] | map(select(.type=="text") | .text) | join("\n"))
          else "" end
    ' 2>/dev/null)
fi
[[ -n "$last_text" ]] || exit 0

# Did the model claim a git/GitHub mutation? If not, stay silent.
if ! echo "$last_text" | grep -iqE 'commit|push|pull request| pr #|opened (a|the) pr|created (a|the) pr|merg|コミット|プッシュ|マージ|プルリク|pr を'; then
    exit 0
fi

# Gather ground truth.
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
head_line=$(git -C "$cwd" log -1 --format='%h %s (%cr)' 2>/dev/null)
dirty=$(git -C "$cwd" status --porcelain 2>/dev/null)
ab=$(git -C "$cwd" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)
behind=$(echo "$ab" | awk '{print $1}')
ahead=$(echo "$ab" | awk '{print $2}')

pr_line=""
if command -v gh >/dev/null 2>&1; then
    pr_line=$(cd "$cwd" && timeout 8 gh pr view --json number,state,url \
        -q '"PR #\(.number) \(.state) — \(.url)"' 2>/dev/null)
fi

# Build the objective report.
report="Ground-truth git state at stop (hook-injected, objective — NOT self-reported):"$'\n'
report+="- branch: ${branch:-unknown}"$'\n'
report+="- HEAD: ${head_line:-<no commits>}"$'\n'
if [[ -n "$ahead$behind" ]]; then
    report+="- vs upstream: ahead ${ahead:-0}, behind ${behind:-0}"$'\n'
else
    report+="- vs upstream: no upstream tracking branch"$'\n'
fi
if [[ -n "$dirty" ]]; then
    report+="- working tree: DIRTY ($(echo "$dirty" | wc -l | tr -d ' ') changed path(s))"$'\n'
else
    report+="- working tree: clean"$'\n'
fi
if [[ -n "$pr_line" ]]; then
    report+="- $pr_line"$'\n'
else
    report+="- gh pr: no open PR found for current branch"$'\n'
fi
report+=$'\n'"Reconcile your last message against this. If you claimed a commit/push/PR that this does not reflect, say so plainly and correct it — do not restate the claim as done."

jq -nc --arg ctx "$report" \
    '{hookSpecificOutput:{hookEventName:"Stop", additionalContext:$ctx}}'

exit 0
