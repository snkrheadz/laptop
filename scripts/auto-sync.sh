#!/bin/bash
# Auto-sync script for dotfiles
# Runs periodically via launchd to keep dotfiles synced

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_PREFIX="[dotfiles-autosync]"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_PREFIX $1"
}

cd "$DOTFILES_DIR"

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    log "ERROR: Not a git repository"
    exit 1
fi

# Update Brewfile
log "Updating Brewfile..."
if command -v brew &>/dev/null; then
    brew bundle dump --force --no-vscode --file=Brewfile 2>/dev/null || true
fi

# Run gitleaks scan (fail silently if not installed)
log "Running gitleaks scan..."
if command -v gitleaks &>/dev/null; then
    if ! gitleaks detect --source="$DOTFILES_DIR" --no-git 2>/dev/null; then
        log "WARNING: gitleaks detected potential secrets. Aborting sync."
        exit 1
    fi
fi

# Run pre-commit hooks (fail silently if not installed)
log "Running pre-commit hooks..."
if command -v pre-commit &>/dev/null && [ -f ".pre-commit-config.yaml" ]; then
    pre-commit run --all-files 2>/dev/null || true
fi

# Check for changes
if [ -z "$(git status --porcelain)" ]; then
    log "No changes detected"
    exit 0
fi

# Stage all changes
log "Staging changes..."
git add -A

# Run gitleaks on staged files (catch secrets before commit)
if command -v gitleaks &>/dev/null; then
    if ! gitleaks detect --staged --source="$DOTFILES_DIR" 2>/dev/null; then
        log "ERROR: gitleaks detected secrets in staged files. Aborting commit."
        git reset HEAD 2>/dev/null || true
        exit 1
    fi
fi

# Create commit
COMMIT_MSG="chore: auto-sync dotfiles $(date '+%Y-%m-%d %H:%M')"
log "Creating commit: $COMMIT_MSG"
git commit -m "$COMMIT_MSG" 2>/dev/null || true

# Push to remote
log "Pushing to remote..."
if git remote get-url origin &>/dev/null; then
    git push origin HEAD 2>/dev/null || log "WARNING: Failed to push (no network or auth issue)"
else
    log "No remote configured, skipping push"
fi

log "Auto-sync completed"
