#!/bin/bash
# PostToolUse hook: Capture Bash failures and propose governance rules
# Runs after Bash tool execution. Records test/build/lint failures
# to ~/.claude/governance/proposals/ for later analysis.

# Read tool result from stdin
input=$(cat)

# Extract exit code from tool result
exit_code=$(echo "$input" | jq -r '.tool_result.exit_code // 0' 2>/dev/null)

# Success → exit immediately (< 10ms overhead)
if [[ "$exit_code" == "0" ]] || [[ "$exit_code" == "null" ]]; then
    exit 0
fi

# Extract command and output
command=$(echo "$input" | jq -r '.tool_input.command // "unknown"' 2>/dev/null)
output=$(echo "$input" | jq -r '.tool_result.stdout // ""' 2>/dev/null)
stderr=$(echo "$input" | jq -r '.tool_result.stderr // ""' 2>/dev/null)

# Only capture test/build/lint failures (not general command errors)
is_relevant=false
case "$command" in
    *jest*|*vitest*|*pytest*|*mocha*|*test*)
        failure_type="test"
        is_relevant=true
        ;;
    *tsc*|*webpack*|*next\ build*|*vite\ build*|*build*)
        failure_type="build"
        is_relevant=true
        ;;
    *eslint*|*prettier*|*rubocop*|*shellcheck*|*lint*)
        failure_type="lint"
        is_relevant=true
        ;;
    *mypy*|*pyright*|*typecheck*)
        failure_type="typecheck"
        is_relevant=true
        ;;
esac

if [[ "$is_relevant" != "true" ]]; then
    exit 0
fi

# Generate proposal file
proposals_dir="$HOME/.claude/governance/proposals"
mkdir -p "$proposals_dir"

timestamp=$(date +%Y-%m-%d-%H%M%S)
proposal_file="$proposals_dir/${timestamp}.json"

# Truncate output to avoid massive files
truncated_output=$(echo "$output" | head -50)
truncated_stderr=$(echo "$stderr" | head -50)

# Get working directory context
cwd=$(echo "$input" | jq -r '.tool_input.cwd // "unknown"' 2>/dev/null)

# Write proposal
cat > "$proposal_file" << PROPOSAL_EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "failure_type": "$failure_type",
  "exit_code": $exit_code,
  "command": $(echo "$command" | jq -Rs .),
  "cwd": $(echo "$cwd" | jq -Rs .),
  "stdout_excerpt": $(echo "$truncated_output" | jq -Rs .),
  "stderr_excerpt": $(echo "$truncated_stderr" | jq -Rs .),
  "status": "pending",
  "proposed_rule": null,
  "reviewed_at": null
}
PROPOSAL_EOF

# Don't block Claude's workflow
exit 0
