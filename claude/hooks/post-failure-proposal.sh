#!/bin/bash
# PostToolUseFailure hook: Capture tool failures and propose governance rules
# Fires only on Bash/Write/Edit failures (no overhead on success).
# Records test/build/lint failures to ~/.claude/governance/proposals/ for later analysis.

# Read failure result from stdin
input=$(cat)

# Skip user interrupts (Ctrl+C)
is_interrupt=$(echo "$input" | jq -r '.is_interrupt // false' 2>/dev/null)
if [[ "$is_interrupt" == "true" ]]; then
    exit 0
fi

# Extract tool name and error info
tool_name=$(echo "$input" | jq -r '.tool_name // "unknown"' 2>/dev/null)
error=$(echo "$input" | jq -r '.error // ""' 2>/dev/null)

# For Bash failures, check if the command is relevant (test/build/lint)
if [[ "$tool_name" == "Bash" ]]; then
    command=$(echo "$input" | jq -r '.tool_input.command // "unknown"' 2>/dev/null)

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
elif [[ "$tool_name" == "Write" ]] || [[ "$tool_name" == "Edit" ]]; then
    failure_type="file_operation"
    command="$tool_name"
else
    exit 0
fi

# Generate proposal file
proposals_dir="$HOME/.claude/governance/proposals"
mkdir -p "$proposals_dir"

timestamp=$(date +%Y-%m-%d-%H%M%S)
proposal_file="$proposals_dir/${timestamp}.json"

# Truncate error to avoid massive files
truncated_error=$(echo "$error" | head -50)

# Get working directory context
cwd=$(echo "$input" | jq -r '.cwd // "unknown"' 2>/dev/null)

# Write proposal
cat > "$proposal_file" << PROPOSAL_EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "tool_name": "$tool_name",
  "failure_type": "$failure_type",
  "command": $(echo "$command" | jq -Rs .),
  "cwd": $(echo "$cwd" | jq -Rs .),
  "error": $(echo "$truncated_error" | jq -Rs .),
  "status": "pending",
  "proposed_rule": null,
  "reviewed_at": null
}
PROPOSAL_EOF

# Don't block Claude's workflow
exit 0
