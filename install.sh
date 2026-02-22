#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/com.dotfiles.autosync.plist"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Helper function to safely create symlinks
# Removes existing symlink/file before creating new one to avoid nested links
# shellcheck disable=SC2329  # Function is used in create_symlinks, setup_claude_agents, setup_claude_skills
safe_ln() {
    local target="$1"
    local link_name="$2"
    rm -rf "$link_name"
    ln -sf "$target" "$link_name"
}

# Check if running on macOS
check_macos() {
    if [ "$(uname)" != "Darwin" ]; then
        log_error "This script is designed for macOS only"
        exit 1
    fi
}

# Install Xcode Command Line Tools
install_xcode_cli() {
    log_info "Checking Xcode Command Line Tools..."
    if ! xcode-select -p &>/dev/null; then
        log_info "Installing Xcode Command Line Tools..."
        xcode-select --install
        log_warning "Please complete Xcode CLI installation and run this script again"
        exit 0
    fi
    log_success "Xcode Command Line Tools installed"
}

# Install Homebrew
install_homebrew() {
    log_info "Checking Homebrew..."
    if ! command -v brew &>/dev/null; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for Apple Silicon
        if [ -f "/opt/homebrew/bin/brew" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi
    log_success "Homebrew installed"
}

# Create backup of existing files
create_backup() {
    log_info "Creating backup at $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"

    local files_to_backup=(
        "$HOME/.zshrc"
        "$HOME/.aliases"
        "$HOME/.gitconfig"
        "$HOME/.gitmessage"
        "$HOME/.gitignore"
        "$HOME/.git_template"
        "$HOME/.tmux.conf"
        "$HOME/.tigrc"
        "$HOME/.fzf.zsh"
        "$HOME/.fzf.bash"
        "$HOME/.zsh"
        "$HOME/.claude/statusline.sh"
        "$HOME/.claude/CLAUDE.md"
        "$HOME/.claude/commands"
        "$HOME/.claude/hooks"
        "$HOME/.claude/agents/verify-shell.md"
        "$HOME/.claude/agents/diagnose-dotfiles.md"
        "$HOME/.claude/agents/migration-assistant.md"
        "$HOME/.claude/settings.json"
        "$HOME/.claude/skills"
    )

    for file in "${files_to_backup[@]}"; do
        if [ -e "$file" ] && [ ! -L "$file" ]; then
            local dest
            dest="$BACKUP_DIR/$(basename "$file")"
            cp -R "$file" "$dest"
            log_info "Backed up: $file"
        fi
    done

    # Save backup location for rollback
    echo "$BACKUP_DIR" > "$HOME/.dotfiles_last_backup"
    log_success "Backup completed at $BACKUP_DIR"
}

# Create symlinks for all managed agent files
setup_claude_agents() {
    log_info "Setting up Claude agents..."

    mkdir -p "$HOME/.claude/agents"

    # Clean up stale symlinks from agents moved to catalog
    for link in "$HOME/.claude/agents"/*.md; do
        if [ -L "$link" ] && [ ! -e "$link" ]; then
            rm "$link"
            log_info "Cleaned up stale symlink: $(basename "$link")"
        fi
    done

    # Dynamically find all agent files (*.md files in agents directory)
    for agent_file in "$DOTFILES_DIR/claude/agents"/*.md; do
        if [ -f "$agent_file" ]; then
            local agent_name
            agent_name=$(basename "$agent_file")
            safe_ln "$agent_file" "$HOME/.claude/agents/$agent_name"
        fi
    done

    log_success "Claude agents configured (global: 2, catalog: $(find "$DOTFILES_DIR/claude/agent-catalog" -name '*.md' 2>/dev/null | wc -l | tr -d ' '))"
}

# Create symbolic links
create_symlinks() {
    log_info "Creating symbolic links..."

    # zsh
    safe_ln "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
    safe_ln "$DOTFILES_DIR/zsh/.aliases" "$HOME/.aliases"
    safe_ln "$DOTFILES_DIR/zsh" "$HOME/.zsh"

    # git
    safe_ln "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"
    safe_ln "$DOTFILES_DIR/git/.gitmessage" "$HOME/.gitmessage"
    safe_ln "$DOTFILES_DIR/git/.gitignore" "$HOME/.gitignore"
    safe_ln "$DOTFILES_DIR/git/.git_template" "$HOME/.git_template"

    # tmux
    safe_ln "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"

    # tig
    safe_ln "$DOTFILES_DIR/tig/.tigrc" "$HOME/.tigrc"

    # fzf
    safe_ln "$DOTFILES_DIR/fzf/.fzf.zsh" "$HOME/.fzf.zsh"
    safe_ln "$DOTFILES_DIR/fzf/.fzf.bash" "$HOME/.fzf.bash"

    # ghostty
    mkdir -p "$HOME/.config/ghostty"
    safe_ln "$DOTFILES_DIR/ghostty/config" "$HOME/.config/ghostty/config"

    # mise
    mkdir -p "$HOME/.config/mise"
    safe_ln "$DOTFILES_DIR/mise/config.toml" "$HOME/.config/mise/config.toml"

    # claude
    mkdir -p "$HOME/.claude"
    mkdir -p "$HOME/.claude/usage"
    safe_ln "$DOTFILES_DIR/claude/statusline.sh" "$HOME/.claude/statusline.sh"

    # claude hooks
    mkdir -p "$HOME/.claude/hooks"
    safe_ln "$DOTFILES_DIR/claude/hooks/validate-shell.sh" "$HOME/.claude/hooks/validate-shell.sh"
    safe_ln "$DOTFILES_DIR/claude/hooks/save-to-obsidian.js" "$HOME/.claude/hooks/save-to-obsidian.js"
    safe_ln "$DOTFILES_DIR/claude/hooks/session-context.sh" "$HOME/.claude/hooks/session-context.sh"
    safe_ln "$DOTFILES_DIR/claude/hooks/pre-tool-guard.sh" "$HOME/.claude/hooks/pre-tool-guard.sh"

    # claude CLAUDE.md (user global)
    safe_ln "$DOTFILES_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

    # claude settings.json
    safe_ln "$DOTFILES_DIR/claude/settings.json" "$HOME/.claude/settings.json"

    log_success "Symbolic links created"
}

# Create symlinks for all managed skill directories
setup_claude_skills() {
    log_info "Setting up Claude skills..."

    mkdir -p "$HOME/.claude/skills"

    # Dynamically find all skill directories (directories containing SKILL.md)
    for skill_dir in "$DOTFILES_DIR/claude/skills"/*/; do
        if [ -f "${skill_dir}SKILL.md" ]; then
            local skill_name
            skill_name=$(basename "$skill_dir")
            safe_ln "$DOTFILES_DIR/claude/skills/$skill_name" "$HOME/.claude/skills/$skill_name"
        fi
    done

    log_success "Claude skills configured"
}

# Install Homebrew packages
install_brew_packages() {
    log_info "Installing Homebrew packages from Brewfile..."
    brew bundle --file="$DOTFILES_DIR/Brewfile"
    log_success "Homebrew packages installed"
}

# Setup security tools (gitleaks + pre-commit)
setup_security() {
    log_info "Setting up security tools..."

    # Install gitleaks
    if ! command -v gitleaks &>/dev/null; then
        brew install gitleaks
    fi

    # Install pre-commit
    if ! command -v pre-commit &>/dev/null; then
        brew install pre-commit
    fi

    # Setup pre-commit hooks in dotfiles repo
    cd "$DOTFILES_DIR"
    if [ -f ".pre-commit-config.yaml" ]; then
        pre-commit install
    fi

    log_success "Security tools configured"
}

# Setup launchd auto-sync
setup_autosync() {
    log_info "Setting up auto-sync..."

    mkdir -p "$HOME/Library/LaunchAgents"

    # Create launchd plist
    cat > "$LAUNCHD_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.dotfiles.autosync</string>
    <key>ProgramArguments</key>
    <array>
        <string>$DOTFILES_DIR/scripts/auto-sync.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>3600</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/.dotfiles_autosync.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.dotfiles_autosync.error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
EOF

    # Load the launchd agent
    launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
    launchctl load "$LAUNCHD_PLIST"

    log_success "Auto-sync configured (runs every hour)"
}

# Setup mise and install runtimes
setup_mise() {
    log_info "Setting up mise..."

    # Install mise if not present
    if ! command -v mise &>/dev/null; then
        brew install mise
    fi

    # Trust the config file
    mise trust "$HOME/.config/mise/config.toml" 2>/dev/null || true

    # Install all tools defined in config
    log_info "Installing runtimes (go, node, python, ruby)..."
    mise install

    log_success "mise configured with runtimes"
}

# Create secrets.env template
create_secrets_template() {
    if [ ! -f "$HOME/.secrets.env" ]; then
        log_info "Creating secrets.env template..."
        cat > "$HOME/.secrets.env" << 'EOF'
# API Keys and Secrets
# This file is gitignored and should never be committed
# Add your API keys here:

# export OPENAI_API_KEY=""
# export ANTHROPIC_API_KEY=""
# export GITHUB_TOKEN=""
EOF
        chmod 600 "$HOME/.secrets.env"
        log_success "Created ~/.secrets.env template"
    fi
}

# Main installation
main() {
    echo ""
    echo "=========================================="
    echo "       Dotfiles Installation Script      "
    echo "=========================================="
    echo ""

    check_macos
    install_xcode_cli
    install_homebrew
    create_backup
    create_symlinks
    setup_claude_agents
    setup_claude_skills
    install_brew_packages
    setup_mise
    setup_security
    setup_autosync
    create_secrets_template

    echo ""
    log_success "Installation complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Restart your terminal or run: source ~/.zshrc"
    echo "  2. Add your API keys to ~/.secrets.env"
    echo "  3. Run 'rollback.sh' if you need to restore previous settings"
    echo "  4. Run 'claude-agents preset dev' in each project to add agents"
    echo ""
}

main "$@"
