# laptop

![](https://github.com/snkrheadz/laptop/actions/workflows/main.yml/badge.svg)

Personal macOS configuration management system with automated dotfiles synchronization, security scanning, and one-command setup/rollback capabilities.

## Core Components

This repository manages configurations for the following applications:

| Category        | Application     | Config Location            |
| --------------- | --------------- | -------------------------- |
| Shell           | Zsh + Oh-My-Zsh | `~/.zshrc`, `~/.zsh/`      |
| Terminal        | Ghostty         | `~/.config/ghostty/config` |
| Editor          | Neovim, Vim     | via Homebrew               |
| Version Control | Git, Tig        | `~/.gitconfig`, `~/.tigrc` |
| Multiplexer     | tmux            | `~/.tmux.conf`             |
| Fuzzy Finder    | fzf             | `~/.fzf.zsh`               |
| Packages        | Homebrew        | `Brewfile`                 |
| Runtimes        | mise            | `~/.config/mise/config.toml` |

**Brewfile includes:**

- 100+ CLI tools (aws, gh, ripgrep, bat, jq, etc.)
- 40+ GUI applications (Cursor, Ghostty, Arc, Raycast, etc.)
- 80+ VSCode/Cursor extensions

## Architecture

### Symlink Strategy

Configuration files reside in this repository and symlink to their standard locations:

```text
~/.zshrc          → laptop/zsh/.zshrc
~/.gitconfig      → laptop/git/.gitconfig
~/.config/ghostty → laptop/ghostty/config
```

**Why symlinks?**

- Git tracks actual content, not just symlink paths
- No specialized tooling required (stow, chezmoi, etc.)
- Easy to understand and debug
- Industry-standard approach

### Directory Structure

```text
laptop/
├── install.sh              # Main installer
├── rollback.sh             # Restore from backup
├── Brewfile                # Homebrew packages manifest
│
├── zsh/                    # Shell configuration
│   ├── .zshrc              # Main config (loads below in order)
│   ├── .aliases            # Shell aliases
│   ├── functions/          # Custom zsh functions
│   └── configs/            # Modular configs
│       ├── pre/            # Loaded first
│       ├── *.zsh           # Main configs (color, editor, history, etc.)
│       └── post/           # Loaded last (PATH, completion)
│
├── git/                    # Git configuration
│   ├── .gitconfig          # Main git config
│   ├── .gitignore          # Global gitignore
│   ├── .gitmessage         # Commit message template
│   └── .git_template/      # Git hooks template
│
├── ghostty/                # Ghostty terminal config
├── tmux/                   # tmux configuration
├── tig/                    # Tig (git TUI) config
├── fzf/                    # Fuzzy finder config
├── mise/                   # mise runtime manager config
│
├── scripts/
│   └── auto-sync.sh        # Hourly auto-sync script
│
├── .pre-commit-config.yaml # Pre-commit hooks
├── .gitleaks.toml          # Secret scanning rules
└── .gitignore              # Security-focused ignore patterns
```

## Security

### Three-Layer Protection

1. **Pre-commit Hooks** - Runs before every commit:
   - `gitleaks` - Scans for secrets and credentials
   - `detect-private-key` - Catches SSH/PGP keys
   - `trailing-whitespace`, `end-of-file-fixer` - Code hygiene

2. **Comprehensive .gitignore** - Blocks 30+ sensitive patterns:
   - Environment files (`.env`, `.secrets.env`)
   - Cloud credentials (AWS, GCP, Azure)
   - SSH/GPG keys (`id_rsa*`, `*.pem`)
   - Terraform state (`*.tfstate`, `*.tfvars`)

3. **Secrets Template** - API keys belong in `~/.secrets.env`:
   ```bash
   # ~/.secrets.env (gitignored, created by install.sh)
   export OPENAI_API_KEY=""
   export ANTHROPIC_API_KEY=""
   export GITHUB_TOKEN=""
   ```

### Security Scanning Commands

```bash
# Manual gitleaks scan
gitleaks detect --source=. --no-git

# Run all pre-commit hooks
pre-commit run --all-files
```

## Automation

### Auto-Sync (launchd)

An hourly `launchd` agent runs `scripts/auto-sync.sh`:

1. Regenerates `Brewfile` from current installations
2. Runs `gitleaks` scan (aborts if secrets detected)
3. Executes pre-commit hooks
4. Commits and pushes changes automatically

**Log files:**

- `~/.dotfiles_autosync.log` - Standard output
- `~/.dotfiles_autosync.error.log` - Errors

**Manual sync:**

```bash
./scripts/auto-sync.sh
```

## Installation

### New Machine Setup

```bash
# Clone repository
git clone https://github.com/snkrheadz/laptop.git ~/ghq/github.com/snkrheadz/laptop

# Run installer
cd ~/ghq/github.com/snkrheadz/laptop
./install.sh
```

**What install.sh does:**

1. Checks macOS and installs Xcode CLI tools
2. Installs Homebrew (if not present)
3. Creates timestamped backup of existing configs
4. Creates symlinks to repository configs
5. Installs all Homebrew packages from Brewfile
6. Sets up mise and installs runtimes (Go, Node.js, Python, Ruby)
7. Sets up gitleaks + pre-commit hooks
8. Configures launchd auto-sync agent
9. Creates `~/.secrets.env` template

### Rollback

```bash
# List available backups
./rollback.sh

# Restore specific backup
./rollback.sh 20231223_120000
```

**What rollback.sh does:**

1. Disables auto-sync launchd agent
2. Removes all symlinks
3. Restores files from backup

### Update Packages

```bash
# Dump current installations to Brewfile
brew bundle dump --force --file=Brewfile

# Install packages from Brewfile
brew bundle --file=Brewfile
```

## Runtime Management (mise)

[mise](https://mise.jdx.dev/) manages programming language runtimes (Go, Node.js, Python, Ruby).

### Installed Runtimes

| Runtime | Version |
|---------|---------|
| Go      | 1.24.3  |
| Node.js | 25.2.1  |
| Python  | 3.13.x  |
| Ruby    | 3.4.8   |

### Commands

```bash
# List installed runtimes
mise list

# Install all runtimes from config
mise install

# Install specific runtime
mise use go@1.23.1

# Update to latest versions
mise upgrade
```

### Configuration

Edit `mise/config.toml` to change versions:

```toml
[tools]
go = "1.24.3"
node = "25.2.1"
python = "3.13"
ruby = "3.4.8"
```

## Customization

### Local Overrides

Create `~/.zshrc_local` for machine-specific settings (automatically sourced, not tracked):

```bash
# ~/.zshrc_local
export WORK_PROJECT_PATH="/path/to/work"
alias deploy="./scripts/deploy-work.sh"
```

### Adding New Dotfiles

1. Add config file to appropriate directory (e.g., `tool/.toolrc`)
2. Update `install.sh` to create symlink:
   ```bash
   safe_ln "$DOTFILES_DIR/tool/.toolrc" "$HOME/.toolrc"
   ```
3. Update `rollback.sh` symlinks array
4. Commit and push

## Development Notes

### zsh Loading Order

```
1. zsh/functions/*        # Custom functions
2. zsh/configs/pre/*      # Pre-configs
3. zsh/configs/*.zsh      # Main configs
4. zsh/configs/post/*     # Post-configs (PATH, completion)
5. ~/.aliases             # Shell aliases
6. oh-my-zsh              # Plugins: git, zsh-autosuggestions
```

### Avoiding Conflicts

- Don't create functions with names that conflict with oh-my-zsh aliases
  - Example: `g` is already defined by the git plugin
- Run `alias` after installation to check for conflicts

### Symlink Safety

`install.sh` uses `safe_ln()` which removes existing symlinks before creating new ones. This prevents circular references when running install.sh multiple times.

## License

MIT
