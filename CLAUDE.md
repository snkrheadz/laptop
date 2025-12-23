# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

macOS laptop setup repository with dotfiles management, auto-sync, and security features.

## Commands

```bash
# Full installation (backup, symlinks, brew packages, security tools, auto-sync)
make install

# Rollback to previous configuration
make rollback

# Manual operations
make brew-dump        # Dump current Homebrew packages to Brewfile
make brew-install     # Install packages from Brewfile
make sync             # Run auto-sync manually
make security-check   # Run gitleaks and pre-commit checks
make setup-hooks      # Install pre-commit hooks
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
├── asdf/               # asdf config → ~/.asdfrc
├── mycli/              # mycli config → ~/.myclirc
├── alacritty/          # Alacritty config → ~/.config/alacritty/
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
