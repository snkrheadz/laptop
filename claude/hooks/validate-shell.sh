#!/bin/bash
# PostToolUse hook: Validate shell scripts with shellcheck
# This script runs after Write|Edit tools to check .sh files

# Read tool input from stdin
input=$(cat)

# Extract file_path from JSON input
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Exit if no file path or not a shell script
if [[ -z "$file_path" ]]; then
    exit 0
fi

# Only check .sh files
if [[ ! "$file_path" =~ \.sh$ ]]; then
    exit 0
fi

# Check if file exists
if [[ ! -f "$file_path" ]]; then
    exit 0
fi

# Check if shellcheck is available
if ! command -v shellcheck &> /dev/null; then
    echo "Warning: shellcheck is not installed. Run 'brew install shellcheck' to enable shell script validation." >&2
    exit 0
fi

# Run shellcheck
result=$(shellcheck -f gcc "$file_path" 2>&1)
exit_code=$?

if [[ $exit_code -ne 0 ]]; then
    echo "shellcheck found issues in $file_path:" >&2
    echo "$result" >&2
    # Exit 2 to block and show feedback to Claude
    exit 2
fi

# Success - no output needed
exit 0
