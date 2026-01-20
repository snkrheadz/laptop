#!/bin/bash
# Auto-review PR after creation
# Triggered by PostToolUse hook on Bash commands
#
# Input (JSON from stdin):
# {
#   "tool_name": "Bash",
#   "tool_input": { "command": "gh pr create ..." },
#   "tool_output": "https://github.com/owner/repo/pull/123\n",
#   "session_id": "...",
#   "cwd": "..."
# }

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Check if this is a `gh pr create` command
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
if [[ ! "$COMMAND" =~ ^gh[[:space:]]+pr[[:space:]]+create ]]; then
  exit 0
fi

# Extract tool output (contains PR URL)
TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // empty' 2>/dev/null || true)

# Extract PR number from URL (e.g., https://github.com/owner/repo/pull/123)
PR_NUMBER=$(echo "$TOOL_OUTPUT" | grep -oE '/pull/[0-9]+' | grep -oE '[0-9]+' | head -1 || true)

# Fallback: try to get PR number from current branch
if [ -z "$PR_NUMBER" ]; then
  PR_NUMBER=$(gh pr view --json number --jq .number 2>/dev/null || true)
fi

if [ -z "$PR_NUMBER" ]; then
  exit 0
fi

# Get working directory from hook input or use git root
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
REPO_ROOT="${CWD:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# Run code review in background (non-blocking)
(
  cd "$REPO_ROOT"

  # Wait for PR to be fully created on GitHub API
  sleep 3

  # Execute code review using Claude CLI headless mode
  claude -p "Review PR #$PR_NUMBER. Analyze the diff, check for bugs, security issues, and code quality. Post your findings as a PR comment using 'gh pr comment'." \
    --allowedTools "Bash(gh *),Bash(git *),Read,Grep,Glob" \
    > /dev/null 2>&1 || true
) &

exit 0
