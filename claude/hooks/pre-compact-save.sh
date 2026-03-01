#!/bin/bash
# PreCompact hook: Save working state before context compaction
# Writes to ~/.claude/pre-compact-context.md (overwritten each time)
# Always exits 0 to never block compaction.

input=$(cat)

context_file="$HOME/.claude/pre-compact-context.md"

# Extract available fields from PreCompact input
cwd=$(echo "$input" | jq -r '.cwd // "unknown"' 2>/dev/null)
summary=$(echo "$input" | jq -r '.summary // ""' 2>/dev/null)

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

    # Include tasks/todo.md if it exists in the working directory
    todo_file="$cwd/tasks/todo.md"
    if [[ -f "$todo_file" ]]; then
        echo "## Active Tasks (tasks/todo.md)"
        head -50 "$todo_file"
        echo ""
    fi

    # Include custom instructions hint
    claude_md="$cwd/CLAUDE.md"
    if [[ -f "$claude_md" ]]; then
        echo "## Project Instructions"
        echo "CLAUDE.md exists at: $claude_md"
        echo ""
    fi
} > "$context_file"

# Never block compaction
exit 0
