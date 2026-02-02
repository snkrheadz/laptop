#!/bin/bash
# PostToolUse hook: Auto-format code on Write|Edit
# Runs appropriate formatter based on file extension

# Read tool input from stdin
input=$(cat)

# Extract file_path from JSON input
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Exit if no file path
if [[ -z "$file_path" ]]; then
    exit 0
fi

# Check if file exists
if [[ ! -f "$file_path" ]]; then
    exit 0
fi

# Format based on file extension
case "$file_path" in
    *.ts|*.tsx|*.js|*.jsx|*.json|*.md|*.css|*.scss|*.html)
        # Prettier for web files
        if command -v npx &> /dev/null; then
            npx prettier --write "$file_path" 2>/dev/null || true
        fi
        ;;
    *.go)
        # gofmt for Go files
        if command -v gofmt &> /dev/null; then
            gofmt -w "$file_path" 2>/dev/null || true
        fi
        ;;
    *.py)
        # ruff for Python files (faster than black)
        if command -v ruff &> /dev/null; then
            ruff format "$file_path" 2>/dev/null || true
        fi
        ;;
    *.rb)
        # rubocop for Ruby files
        if command -v rubocop &> /dev/null; then
            rubocop -a "$file_path" 2>/dev/null || true
        fi
        ;;
    *.rs)
        # rustfmt for Rust files
        if command -v rustfmt &> /dev/null; then
            rustfmt "$file_path" 2>/dev/null || true
        fi
        ;;
esac

# Always exit successfully (formatting is best-effort)
exit 0
