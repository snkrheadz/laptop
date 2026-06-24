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

# Skip if a pause lock is active (set by scripts/autosync-pause.sh during PR creation
# or manual work). The lock auto-expires so a forgotten pause can't disable sync forever.
PAUSE_LOCK="$HOME/.cache/dotfiles-autosync.pause"

# Returns 0 if an unexpired pause lock is active; silently clears an expired lock.
# On success, sets PAUSE_EXPIRY to the lock's epoch deadline for logging.
pause_active() {
    [ -f "$PAUSE_LOCK" ] || return 1
    PAUSE_EXPIRY=$(cat "$PAUSE_LOCK" 2>/dev/null || echo 0)
    local now
    now=$(date +%s)
    if [[ "$PAUSE_EXPIRY" =~ ^[0-9]+$ ]] && [ "$now" -lt "$PAUSE_EXPIRY" ]; then
        return 0
    fi
    rm -f "$PAUSE_LOCK"
    return 1
}

if pause_active; then
    log "Paused until $(date -r "$PAUSE_EXPIRY" '+%H:%M:%S') — skipping sync"
    exit 0
fi

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

# Run gitleaks on staged files (catch secrets before commit).
# Use `protect --staged`: the legacy `detect --staged` form was removed in
# gitleaks 8.x and now exits non-zero with "unknown flag", which this script
# previously misreported as a secret detection. Keep stderr so a scan failure
# is distinguishable from an actual leak.
if command -v gitleaks &>/dev/null; then
    if ! gitleaks_out=$(gitleaks protect --staged --source="$DOTFILES_DIR" 2>&1); then
        log "ERROR: gitleaks aborted commit (secret found or scan failed):"
        log "$gitleaks_out"
        git reset HEAD 2>/dev/null || true
        exit 1
    fi
fi

# Re-check the pause lock right before the destructive commit/push: a pause set
# after the initial check (while brew dump and scans ran) must still take effect.
if pause_active; then
    log "Paused mid-run — unstaging and skipping commit"
    git reset HEAD 2>/dev/null || true
    exit 0
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
