#!/bin/bash
# SessionStart hook: Inject project context at session start
# Outputs git branch, last commit, and active worktree count

# Get current directory from stdin (SessionStart provides workspace info)
input=$(cat)
current_dir=$(echo "$input" | jq -r '.session.cwd // "."' 2>/dev/null)

if [ -z "$current_dir" ] || [ "$current_dir" = "." ]; then
    current_dir="$(pwd)"
fi

# Only run in git repositories
if ! git -C "$current_dir" rev-parse --git-dir > /dev/null 2>&1; then
    exit 0
fi

branch=$(git -C "$current_dir" branch --show-current 2>/dev/null || echo "detached")
last_commit=$(git -C "$current_dir" log -1 --oneline 2>/dev/null || echo "no commits")
worktree_count=$(git -C "$current_dir" worktree list 2>/dev/null | wc -l | tr -d ' ')

echo "Project context: branch=${branch}, last_commit=\"${last_commit}\", active_worktrees=${worktree_count}"

# Restore pre-compact context if available (one-shot restore)
context_file="$HOME/.claude/pre-compact-context.md"
if [[ -f "$context_file" ]]; then
    echo ""
    echo "--- Restored from pre-compact snapshot ---"
    cat "$context_file"
    rm -f "$context_file"
fi
