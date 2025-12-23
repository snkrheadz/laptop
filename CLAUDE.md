# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

macOS laptop setup repository with dotfiles management, auto-sync, and security features.

## Commands

```bash
# Full installation (backup, symlinks, brew packages, security tools, auto-sync)
./install.sh

# Rollback to previous configuration
./rollback.sh

# Manual operations
brew bundle dump --force --file=Brewfile  # Dump current Homebrew packages
brew bundle --file=Brewfile               # Install packages from Brewfile
./scripts/auto-sync.sh                    # Run auto-sync manually

# Security checks
pre-commit install                        # Setup pre-commit hooks
pre-commit run --all-files                # Run all pre-commit checks
gitleaks detect --source=. --no-git       # Scan for secrets
```

## Architecture

```
├── install.sh          # Main installer (creates backup, symlinks, installs packages)
├── rollback.sh         # Restore from backup
├── scripts/
│   └── auto-sync.sh    # Hourly auto-sync via launchd
├── Brewfile            # Homebrew packages, casks, VSCode extensions
│
├── zsh/                # Shell config → ~/.zshrc, ~/.aliases, ~/.zsh/
├── git/                # Git config → ~/.gitconfig, ~/.gitmessage, ~/.gitignore
├── tmux/               # Tmux config → ~/.tmux.conf
├── tig/                # Tig config → ~/.tigrc
├── fzf/                # FZF config → ~/.fzf.zsh, ~/.fzf.bash
├── mycli/              # mycli config → ~/.myclirc
│
├── .pre-commit-config.yaml   # Pre-commit hooks config
├── .gitleaks.toml            # Gitleaks secret scanning config
└── .gitignore                # Enhanced security-focused gitignore
```

## Key Features

- **Auto-sync**: launchd agent runs `auto-sync.sh` every hour to commit and push changes
- **Backup/Rollback**: `install.sh` creates timestamped backups; `rollback.sh` restores them
- **Security**: gitleaks + pre-commit hooks scan for secrets before commit
- **Secrets**: Store API keys in `~/.secrets.env` (gitignored, created by install.sh)
