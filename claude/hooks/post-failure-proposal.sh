#!/bin/bash
# PostToolUseFailure hook: Capture tool failures and propose governance rules
# Fires only on Bash/Write/Edit failures (no overhead on success).
# Records test/build/lint failures to ~/.claude/governance/proposals/ for later analysis.

# Read failure result from stdin and extract all fields in one jq call
input=$(cat)
is_interrupt="" tool_name="" error="" command="" cwd=""
eval "$(echo "$input" | jq -r '
  @sh "is_interrupt=\(.is_interrupt // false)",
  @sh "tool_name=\(.tool_name // "unknown")",
  @sh "error=\(.error // "")",
  @sh "command=\(.tool_input.command // "unknown")",
  @sh "cwd=\(.cwd // "unknown")"
' 2>/dev/null)"

# Skip user interrupts (Ctrl+C)
if [[ "$is_interrupt" == "true" ]]; then
    exit 0
fi

# For Bash failures, check if the command is relevant (test/build/lint)
if [[ "$tool_name" == "Bash" ]]; then

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

timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
proposal_file="$proposals_dir/$(echo "$timestamp" | tr -d ':T-' | cut -c1-15).json"

# Truncate error to avoid massive files and write proposal as proper JSON in one jq call
echo "$error" | head -50 | jq -Rsn \
  --arg ts "$timestamp" \
  --arg tn "$tool_name" \
  --arg ft "$failure_type" \
  --arg cmd "$command" \
  --arg cwd "$cwd" \
  '{
    timestamp: $ts,
    tool_name: $tn,
    failure_type: $ft,
    command: $cmd,
    cwd: $cwd,
    error: input,
    status: "pending",
    proposed_rule: null,
    reviewed_at: null
  }' > "$proposal_file"

# Don't block Claude's workflow
exit 0
