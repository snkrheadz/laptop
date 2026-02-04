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

# Runtime management (mise)
mise list                                 # List installed runtimes
mise install                              # Install runtimes from config
mise use go@1.24.3                        # Install/use specific version
```

## Architecture

```text
├── install.sh          # Main installer (creates backup, symlinks, installs packages)
├── rollback.sh         # Restore from backup
├── scripts/
│   └── auto-sync.sh    # Hourly auto-sync via launchd
├── Brewfile            # Homebrew packages, casks, VSCode extensions
│
├── zsh/                # Shell config → ~/.zshrc, ~/.aliases, ~/.zsh/
│   ├── .zshrc          # Main zsh config (loads functions → configs → aliases → oh-my-zsh)
│   ├── .aliases        # Shell aliases
│   ├── functions/      # Custom zsh functions: _git_delete_branch, change-extension,
│   │                   #   envup, mcd, pr-merge
│   └── configs/        # Modular zsh configs
│       ├── pre/        # Loaded first (before main configs)
│       ├── *.zsh       # Main configs (color, editor, history, etc.)
│       └── post/       # Loaded last (path.zsh, completion.zsh)
│
├── git/                # Git config → ~/.gitconfig, ~/.gitmessage, ~/.gitignore
├── tmux/               # Tmux config → ~/.tmux.conf
├── tig/                # Tig config → ~/.tigrc
├── fzf/                # FZF config → ~/.fzf.zsh, ~/.fzf.bash
├── ghostty/            # Ghostty config → ~/.config/ghostty/config
├── iterm2/             # iTerm2 config (com.googlecode.iterm2.plist)
├── mise/               # mise config → ~/.config/mise/config.toml
├── bin/                # Executable scripts (tat - tmux utility)
├── raycast/            # Raycast settings export (*.rayconfig)
│
├── claude/             # Claude Code config → ~/.claude/
│   ├── settings.json   # Claude Code settings (hooks, plugins, permissions)
│   ├── statusline.sh   # Status line display script
│   ├── CLAUDE.md       # User global instructions
│   ├── hooks/          # PostToolUse hooks: validate-shell.sh, save-to-obsidian.js
│   ├── agents/         # Subagents (17): verify-shell, code-architect, build-validator,
│   │                   #   aws-best-practices-advisor, diagnose-dotfiles, etc.
│   └── skills/         # Skills (9): claude-code-guide, quick-commit, merge-pr,
│                       #   review-changes, test-and-fix, db-query, etc.
│
├── .claude/            # Local skills (project-specific, NOT symlinked)
│   └── skills/         # Local skills (14): brew-manage, health-check, zsh-config, etc.
│
├── .github/
│   └── workflows/main.yml  # CI/CD (gitleaks + shellcheck)
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
- **Runtimes**: mise manages Go 1.24.3, Node.js 25.2.1/22.16.0, Python 3.13, Ruby 3.4.8

## Development Notes

### zsh Loading Order

The `.zshrc` loads configuration in this order:

1. `zsh/functions/*` - Custom functions
2. `zsh/configs/pre/*` - Pre-configs
3. `zsh/configs/*.zsh` - Main configs
4. `zsh/configs/post/*` - Post-configs (PATH, completion)
5. `~/.aliases` - Shell aliases
6. oh-my-zsh with plugins: `git`, `zsh-autosuggestions`

### Symlink Management

`install.sh` uses `safe_ln()` function to create symlinks. This removes existing symlinks/files before creating new ones to prevent circular references when running install.sh multiple times.

### Avoiding Conflicts

- Do not create functions with names that conflict with oh-my-zsh plugin aliases (e.g., `g` is used by git plugin)
- Check `alias` output after installation to identify potential conflicts

### Claude Code Configuration

The `claude/` directory contains Claude Code settings managed by this repository:

**Managed files** (symlinked to `~/.claude/`):
- `settings.json` - Hooks, plugins, permissions, statusLine config
- `statusline.sh` - Status line display script
- `CLAUDE.md` - User global instructions

**Hooks** (2):
- `hooks/validate-shell.sh` - PostToolUse hook for shellcheck
- `hooks/save-to-obsidian.js` - Saves context to Obsidian

**Agents** (17):
- `verify-shell`, `verify-app`, `build-validator` - Verification agents
- `code-architect`, `code-simplifier` - Code design agents
- `aws-best-practices-advisor`, `gcp-best-practices-advisor` - Cloud guidance
- `arxiv-ai-researcher`, `gemini-api-researcher`, `huggingface-spaces-researcher` - Research agents
- `strategic-research-analyst`, `nano-banana-pro-prompt-generator`
- `state-machine-diagram`, `migration-assistant`, `oncall-guide`
- `diagnose-dotfiles`, `verify-subagent-result`

**Skills** (9):
- `claude-code-guide` - Claude Code extension documentation
- `db-query` - Database query helper
- `first-principles` - First principles analysis
- `merge-pr` - PR merge with worktree cleanup
- `project-setup` - Project setup wizard
- `quick-commit` - Fast commit workflow
- `review-changes` - Code review helper
- `techdebt` - Tech debt analysis
- `test-and-fix` - Test and fix workflow

**Local Skills** (14) - Project-specific, in `.claude/skills/`:

These skills are **only available in this repository** (not symlinked to `~/.claude/`):
- `brew-manage` - Homebrew package management
- `claude-config` - Claude Code configuration management
- `dotfiles-rollback` - Backup and rollback
- `dotfiles-sync` - Manual dotfiles sync
- `git-config` - Git configuration files
- `health-check` - Dotfiles health check
- `hf-spaces` - HuggingFace Spaces search
- `launchd-manage` - Auto-sync launchd management
- `mise-runtime` - Runtime management (mise)
- `new-machine-setup` - New machine setup guide
- `security-check` - Security scanning
- `symlink-manage` - Symlink management
- `tmux-config` - tmux configuration
- `zsh-config` - zsh configuration

## Best Practices

- Test after code changes to verify behavior
- Review related files before committing multiple changes
- Use concise PR titles that describe the changes
- Consider PostToolUse hooks for code format automation in projects
