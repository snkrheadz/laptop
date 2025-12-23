#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

LAUNCHD_PLIST="$HOME/Library/LaunchAgents/com.dotfiles.autosync.plist"
LAST_BACKUP_FILE="$HOME/.dotfiles_last_backup"

# List available backups
list_backups() {
    log_info "Available backups:"
    if [ -d "$HOME/.dotfiles_backup" ]; then
        ls -1 "$HOME/.dotfiles_backup" | while read -r backup; do
            echo "  - $backup"
        done
    else
        log_warning "No backups found"
    fi
}

# Remove symlinks
remove_symlinks() {
    log_info "Removing symbolic links..."

    local symlinks=(
        "$HOME/.zshrc"
        "$HOME/.aliases"
        "$HOME/.zsh"
        "$HOME/.gitconfig"
        "$HOME/.gitmessage"
        "$HOME/.gitignore"
        "$HOME/.git_template"
        "$HOME/.tmux.conf"
        "$HOME/.tigrc"
        "$HOME/.fzf.zsh"
        "$HOME/.fzf.bash"
    )

    for link in "${symlinks[@]}"; do
        if [ -L "$link" ]; then
            rm "$link"
            log_info "Removed: $link"
        fi
    done

    log_success "Symbolic links removed"
}

# Restore from backup
restore_backup() {
    local backup_dir="$1"

    if [ ! -d "$backup_dir" ]; then
        log_error "Backup directory not found: $backup_dir"
        exit 1
    fi

    log_info "Restoring from backup: $backup_dir"

    for file in "$backup_dir"/*; do
        if [ -e "$file" ]; then
            local filename=$(basename "$file")
            local dest="$HOME/$filename"

            cp -R "$file" "$dest"
            log_info "Restored: $dest"
        fi
    done

    log_success "Backup restored"
}

# Disable auto-sync
disable_autosync() {
    log_info "Disabling auto-sync..."

    if [ -f "$LAUNCHD_PLIST" ]; then
        launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
        rm "$LAUNCHD_PLIST"
        log_success "Auto-sync disabled"
    else
        log_info "Auto-sync was not configured"
    fi
}

# Main
main() {
    echo ""
    echo "=========================================="
    echo "        Dotfiles Rollback Script         "
    echo "=========================================="
    echo ""

    # Show available backups
    list_backups
    echo ""

    # Determine which backup to use
    local backup_dir=""

    if [ -n "$1" ]; then
        # Backup specified as argument
        backup_dir="$HOME/.dotfiles_backup/$1"
    elif [ -f "$LAST_BACKUP_FILE" ]; then
        # Use last backup
        backup_dir=$(cat "$LAST_BACKUP_FILE")
        log_info "Using last backup: $backup_dir"
    else
        log_error "No backup specified and no last backup found"
        echo ""
        echo "Usage: $0 [backup_name]"
        echo "Example: $0 20231223_120000"
        exit 1
    fi

    echo ""
    read -p "Are you sure you want to rollback? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Rollback cancelled"
        exit 0
    fi

    disable_autosync
    remove_symlinks
    restore_backup "$backup_dir"

    echo ""
    log_success "Rollback complete!"
    echo ""
    echo "Please restart your terminal to apply changes."
    echo ""
}

main "$@"
