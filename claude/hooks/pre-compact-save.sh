#!/bin/bash
# PreCompact hook: Save working state before context compaction
# Writes to ~/.claude/pre-compact-context.md (overwritten each time)
# Always exits 0 to never block compaction.

input=$(cat)

context_file="$HOME/.claude/pre-compact-context.md"

# Extract available fields from PreCompact input in one jq call
cwd="" summary=""
eval "$(echo "$input" | jq -r '
  @sh "cwd=\(.cwd // "unknown")",
  @sh "summary=\(.summary // "")"
' 2>/dev/null)"

# Build context snapshot
{
    echo "# Pre-Compact Context (auto-saved)"
    echo ""
    echo "**Saved at**: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "**Working directory**: $cwd"
    echo ""

    # Include compaction summary if available
    if [[ -n "$summary" ]] && [[ "$summary" != "null" ]]; then
        echo "## Compaction Summary"
        echo "$summary"
        echo ""
    fi

    # Include tasks/todo.md if available in the working directory
    if todo_content=$(head -50 "$cwd/tasks/todo.md" 2>/dev/null); then
        echo "## Active Tasks (tasks/todo.md)"
        echo "$todo_content"
        echo ""
    fi

    # Include custom instructions hint if CLAUDE.md exists
    if [[ -f "$cwd/CLAUDE.md" ]]; then
        echo "## Project Instructions"
        echo "CLAUDE.md exists at: $cwd/CLAUDE.md"
        echo ""
    fi
} > "$context_file"

# Never block compaction
exit 0
