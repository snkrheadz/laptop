# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

macOS laptop setup repository with dotfiles management, manual sync, and security features.

## Commands

```bash
# Full installation (backup, symlinks, brew packages, security tools)
./install.sh

# Sync ONLY Claude Code symlinks (~/.claude/*), skipping brew/mise/security/backup
./scripts/sync-claude.sh

# Rollback to previous configuration
./rollback.sh

# Manual operations
brew bundle dump --force --file=Brewfile  # Dump current Homebrew packages
brew bundle --file=Brewfile               # Install packages from Brewfile
./scripts/auto-sync.sh                    # Sync dotfiles manually (commit & push)

# Security checks
pre-commit install                        # Setup pre-commit hooks
pre-commit run --all-files                # Run all pre-commit checks
gitleaks detect --source=. --no-git       # Scan for secrets

# Runtime management (mise)
mise list                                 # List installed runtimes
mise install                              # Install runtimes from config
mise use go@1.24.3                        # Install/use specific version

# CodeGraph (code intelligence index)
codegraph index                           # 初回インデックス構築 or 完全再構築
codegraph sync                            # 差分更新（スクリプト等からの手動実行用）
codegraph status                          # インデックスの状態確認
# 自動更新: MCP デーモン稼働中は FS ウォッチャーが 2 秒デバウンスで自動同期するため
#           通常は手動実行不要。.codegraph/ を削除した場合は codegraph index を再実行。
```

## Architecture

```text
├── install.sh          # Main installer (creates backup, symlinks, installs packages)
├── rollback.sh         # Restore from backup
├── scripts/
│   ├── auto-sync.sh           # Manual dotfiles sync (commit & push)
│   ├── sync-claude.sh         # Claude symlink sync (sources install.sh) + plugin sync
│   └── sync-claude-plugins.sh # Materialize marketplaces/plugins declared in settings.json (headless, idempotent)
├── Brewfile            # Homebrew packages, casks, VSCode extensions
│
├── zsh/                # Shell config → ~/.zshrc, ~/.aliases, ~/.zsh/
│   ├── .zshrc          # Main zsh config (loads functions → configs → aliases → oh-my-zsh)
│   ├── .aliases        # Shell aliases
│   ├── functions/      # Custom zsh functions: _git_delete_branch, change-extension,
│   │                   #   envup, mcd, pr-merge
│   └── configs/        # Modular zsh configs
│       ├── *.zsh       # Main configs (color, editor, history, etc.)
│       └── post/       # Loaded last (path.zsh, completion.zsh, mise.zsh)
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
│   ├── CLAUDE.md       # User global instructions (Workflow Orchestration)
│   ├── loop.md         # Default no-arg `/loop` maintenance routine (project-agnostic)
│   ├── hooks/          # Lifecycle hooks (2): validate-shell.sh,
│   │                   #   verify-git-on-stop.sh
│   ├── agents/         # Global agents (1): verify-subagent-result
│   │                   #   (shareable agents in the snkrheadz/claude-skills marketplace)
│   └── commands/       # Custom slash commands (1): implement-with-notes
│
├── .claude/            # Project-local config (NOT symlinked to ~/.claude/)
│   ├── agents/         # Project agents (1): diagnose-dotfiles (real file, dotfiles-specific)
│   └── skills/         # Local skills (14): brew-manage, health-check, zsh-config, etc.
│
├── .github/
│   └── workflows/main.yml  # CI/CD (gitleaks + shellcheck)
│
├── docs/
│   └── fable5-vs-opus48.html # Model comparison report (evidence base for model routing)
│
├── .codegraph/               # CodeGraph index (SQLite 知識グラフ、MCP デーモンが FS ウォッチで自動更新)
│
├── .pre-commit-config.yaml   # Pre-commit hooks config
├── .gitleaks.toml            # Gitleaks secret scanning config
└── .gitignore                # Enhanced security-focused gitignore
```

## Key Features

- **Manual sync**: run `./scripts/auto-sync.sh` to commit and push changes (no background agent; launchd auto-sync removed)
- **Backup/Rollback**: `install.sh` creates timestamped backups; `rollback.sh` restores them
- **Security**: gitleaks + pre-commit hooks scan for secrets before commit
- **Secrets**: Store API keys in `~/.secrets.env` (gitignored, created by install.sh)
- **Runtimes**: mise manages Go 1.24.3, Node.js 25.2.1/22.16.0, Python 3.13, Ruby 3.4.8

## Development Notes

### zsh Loading Order

The `.zshrc` loads configuration in this order:

1. `zsh/functions/*` - Custom functions
2. `zsh/configs/pre/*` - Pre-configs (code in .zshrc but directory unused)
3. `zsh/configs/*.zsh` - Main configs
4. `zsh/configs/post/*` - Post-configs (PATH, completion, mise)
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
- `CLAUDE.md` - User global instructions (Workflow Orchestration §1–§5)
- `loop.md` - Default no-arg `/loop` maintenance routine

**Hooks** (2):
- `hooks/validate-shell.sh` - PostToolUse hook for shellcheck
- `hooks/verify-git-on-stop.sh` - Stop hook: when the last reply claims a commit/push/PR/merge, injects actual `git`/`gh pr` state so false-success reports get caught against reality (near-silent otherwise; `stop_hook_active`-guarded)

> Note: sensitive-file access blocking is enforced by `settings.json` `deny` rules (harness-native, zero per-call overhead); the former `pre-tool-guard.sh` PreToolUse hook was removed. `gh pr create` base-sync is handled by the `/eng:create-pr` skill.

**Global Agents** (1, always loaded — symlinked to `~/.claude/agents/`):
- `verify-subagent-result` - SubAgent verification

**Project Agents** (1, dotfiles repo only — real file in `.claude/agents/`):
- `diagnose-dotfiles` - Dotfiles troubleshooting (specific to this repo)

> `side-job-researcher` is personal and kept **machine-local** (a real file in
> `~/.claude/agents/`, not dotfiles-managed), mirroring its machine-local
> `side-job-search` skill — so it is not synced or published to the marketplace.

**Shareable agents** now live in the **`snkrheadz/claude-skills`** marketplace
(single source of truth) alongside the skills, enabled per role via
`/plugin install <pack>@claude-skills`:
- **eng** (8 agents): `code-architect`, `architecture-reviewer`, `verify-shell`,
  `migration-assistant`, `oncall-guide`, `state-machine-diagram`,
  `aws-best-practices-advisor`, `gcp-best-practices-advisor`
- **research**: `arxiv-ai-researcher`, `gemini-api-researcher`, `huggingface-spaces-researcher`

Packs in `snkrheadz/claude-skills` (declared in `settings.json`, installed via `scripts/sync-claude-plugins.sh`, namespaced as `/<pack>:<skill>`):
`core` | `pm` | `eng` | `research` | `strategy`

**Commands** (1) - Custom slash commands in `claude/commands/`, symlinked to `~/.claude/commands/`:
- `implement-with-notes` - Implement a spec while keeping running implementation notes (decisions, tradeoffs, deltas)

**Local Skills** (14) - Project-specific, in `.claude/skills/`:

These skills are **only available in this repository** (not symlinked to `~/.claude/`):
- `brew-manage` - Homebrew package management
- `claude-config` - Claude Code configuration management
- `dotfiles-rollback` - Backup and rollback
- `dotfiles-sync` - Manual dotfiles sync
- `git-config` - Git configuration files
- `health-check` - Dotfiles health check
- `hf-spaces` - HuggingFace Spaces search
- `launchd-manage` - (非推奨/廃止) launchd auto-sync は廃止。手動同期は `scripts/auto-sync.sh` を直接実行
- `mise-runtime` - Runtime management (mise)
- `new-machine-setup` - New machine setup guide

- `security-check` - Security scanning
- `symlink-manage` - Symlink management
- `tmux-config` - tmux configuration
- `zsh-config` - zsh configuration
