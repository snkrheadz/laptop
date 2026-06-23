#!/bin/bash
# PreToolUse hook: Block Bash commands that access sensitive files
# This provides defense-in-depth alongside deny rules in settings.json
# Also enforces: merge base branch before creating a PR
# Note: on exit 2 only stderr is fed back to the model, so every BLOCKED
# message below must be redirected with >&2

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
if [ "$tool_name" != "Bash" ]; then
    exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
if [ -z "$command" ]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# gh pr create guard: block self-branch, stale-base, and empty-diff PRs
# ---------------------------------------------------------------------------
if printf '%s' "$command" | tr ';&' '\n' | grep -qE '^[[:space:]]*gh[[:space:]]+pr[[:space:]]+create'; then
    # Determine working dir from hook input or fallback to cwd
    hook_cwd=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null)
    work_dir="${hook_cwd:-$(pwd)}"

    # Only apply inside a git repo
    if git -C "$work_dir" rev-parse --git-dir > /dev/null 2>&1; then
        current_branch=$(git -C "$work_dir" branch --show-current 2>/dev/null)

        # Detect base branch from --base flag (space or = form), or default to main/master
        base_branch=$(echo "$command" | sed -nE 's/.*--base[[:space:]=]+([^[:space:]]+).*/\1/p' | head -1)
        # Strip surrounding quotes so --base="main" resolves as a valid ref
        base_branch=${base_branch//[\"\']/}
        # Discard unexpanded shell variable references (e.g. "$base") — fall through to auto-detect
        case "$base_branch" in \$*) base_branch="" ;; esac
        if [ -z "$base_branch" ]; then
            if git -C "$work_dir" show-ref --verify --quiet "refs/remotes/origin/main"; then
                base_branch="main"
            elif git -C "$work_dir" show-ref --verify --quiet "refs/remotes/origin/master"; then
                base_branch="master"
            fi
        fi

        if [ -n "$base_branch" ]; then
            # Guard 1: cannot PR a branch into itself (auto-sync may have committed to base directly)
            if [ "$current_branch" = "$base_branch" ]; then
                {
                    echo "BLOCKED: Current branch is '$base_branch' — cannot open a PR targeting the same branch."
                    echo ""
                    echo "auto-sync may have committed your changes directly to $base_branch."
                    echo "Check recent commits: git log --oneline -5"
                } >&2
                exit 2
            fi

            # Fetch latest base branch
            git -C "$work_dir" fetch origin "$base_branch" --quiet 2>/dev/null

            # Guard 2: ensure base branch is merged before opening a PR (no stale diff)
            behind=$(git -C "$work_dir" rev-list --count "HEAD..origin/$base_branch" 2>/dev/null || echo "0")
            if [ "$behind" -gt 0 ]; then
                {
                    echo "BLOCKED: Current branch '$current_branch' is $behind commit(s) behind origin/$base_branch."
                    echo ""
                    echo "Merge the base branch before creating the PR to avoid stale diffs:"
                    echo "  git merge origin/$base_branch"
                    echo ""
                    echo "Or, if you want to rebase instead:"
                    echo "  git rebase origin/$base_branch"
                } >&2
                exit 2
            fi

            # Guard 3: ensure there are commits to PR (non-empty diff)
            ahead=$(git -C "$work_dir" rev-list --count "origin/$base_branch..HEAD" 2>/dev/null || echo "0")
            if [ "$ahead" -eq 0 ]; then
                {
                    echo "BLOCKED: No commits found ahead of origin/$base_branch — the PR would be empty."
                    echo ""
                    echo "auto-sync may have already pushed your changes directly to $base_branch."
                    echo "Check: git log --oneline -5 origin/$base_branch"
                } >&2
                exit 2
            fi
        fi
    fi
fi
# ---------------------------------------------------------------------------

# Sensitive file patterns to block
SENSITIVE_PATTERNS=(
    "$HOME/.secrets.env"
    "$HOME/.aws/credentials"
    "$HOME/.ssh/id_"
    "$HOME/.kube/config"
    "$HOME/.docker/config.json"
    "$HOME/.gnupg/"
    "$HOME/.netrc"
)

for pattern in "${SENSITIVE_PATTERNS[@]}"; do
    if [[ "$command" == *"$pattern"* ]]; then
        {
            echo "BLOCKED: Command accesses sensitive file matching: ${pattern}"
            echo "Use environment variables or dedicated secret managers instead."
        } >&2
        exit 2
    fi
done

# Block pipe-to-shell patterns
if echo "$command" | grep -qE '(curl|wget)\s.*\|\s*(bash|sh|zsh)'; then
    echo "BLOCKED: Pipe-to-shell execution detected. Download and review scripts before executing." >&2
    exit 2
fi

exit 0
