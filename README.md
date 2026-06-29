# laptop

![](https://github.com/snkrheadz/laptop/actions/workflows/main.yml/badge.svg)

Personal macOS configuration management system with automated dotfiles synchronization, security scanning, and one-command setup/rollback capabilities.

## Core Components

This repository manages configurations for the following applications:

| Category        | Application     | Config Location              |
| --------------- | --------------- | ---------------------------- |
| Shell           | Zsh + Oh-My-Zsh | `~/.zshrc`, `~/.zsh/`        |
| Terminal        | Ghostty, iTerm2 | `~/.config/ghostty/config`, `iterm2/` |
| Editor          | Neovim, Vim     | via Homebrew                 |
| Version Control | Git, Tig        | `~/.gitconfig`, `~/.tigrc`   |
| Multiplexer     | tmux            | `~/.tmux.conf`               |
| Fuzzy Finder    | fzf             | `~/.fzf.zsh`                 |
| Packages        | Homebrew        | `Brewfile`                   |
| Runtimes        | mise            | `~/.config/mise/config.toml` |
| Launcher        | Raycast         | `raycast/*.rayconfig`        |
| AI Assistant    | Claude Code     | `~/.claude/` (settings, hooks, agents, skills) |

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
│   ├── functions/          # Custom zsh functions (5)
│   └── configs/            # Modular configs
│       ├── *.zsh           # Main configs (color, editor, history, etc.)
│       └── post/           # Loaded last (PATH, completion, mise)
│
├── git/                    # Git configuration
│   ├── .gitconfig          # Main git config
│   ├── .gitignore          # Global gitignore
│   ├── .gitmessage         # Commit message template
│   └── .git_template       # Git hooks template
│
├── ghostty/                # Ghostty terminal config
├── iterm2/                 # iTerm2 settings plist
├── tmux/                   # tmux configuration
├── tig/                    # Tig (git TUI) config
├── fzf/                    # Fuzzy finder config
├── mise/                   # mise runtime manager config
├── bin/                    # Executable scripts (tat)
├── raycast/                # Raycast settings export
├── claude/                 # Claude Code configuration → ~/.claude/
│   ├── CLAUDE.md           # User global instructions (Workflow Orchestration, §1–5)
│   ├── settings.json       # Hooks, plugins, permissions
│   ├── statusline.sh       # Custom status line script
│   ├── loop.md             # Default no-arg /loop maintenance routine
│   ├── hooks/              # Lifecycle hooks (3)
│   ├── agents/             # Global agents (1): verify-subagent-result
│   └── commands/           # Custom slash commands (1): implement-with-notes
│
├── .claude/                # Project-local config (NOT symlinked to ~/.claude/)
│   ├── agents/             # Project agents (1): diagnose-dotfiles (dotfiles-specific)
│   └── skills/             # Local skills (14)
│
├── scripts/
│   ├── auto-sync.sh               # Manual dotfiles sync script (commit & push)
│   ├── sync-claude.sh             # Claude symlink sync + plugin sync
│   └── sync-claude-plugins.sh     # Materialize marketplaces/plugins declared in settings.json
│
├── docs/
│   └── fable5-vs-opus48.html  # Model comparison report (evidence for model routing)
│
├── .codegraph/             # CodeGraph index (code intelligence, auto-maintained)
│
├── .github/
│   └── workflows/main.yml  # CI/CD (gitleaks + shellcheck)
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

## Synchronization

### Manual Sync

Syncing is **manual** — run `scripts/auto-sync.sh` yourself whenever you want to
push local config changes. No background agent commits anything automatically.

```bash
./scripts/auto-sync.sh
```

The script:

1. Regenerates `Brewfile` from current installations
2. Runs `gitleaks` scan (aborts if secrets detected)
3. Executes pre-commit hooks
4. Commits and pushes changes

> **Note:** This previously ran hourly via a `launchd` agent (`com.dotfiles.autosync`).
> The agent has been removed; `install.sh` no longer installs it. The script name is
> kept as `auto-sync.sh` for continuity but it is invoked manually now.

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
8. Creates `~/.secrets.env` template

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

| Runtime | Version          |
|---------|------------------|
| Go      | 1.24.3           |
| Node.js | 25.2.1, 22.16.0  |
| Python  | 3.13.x           |
| Ruby    | 3.4.8            |

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
2. zsh/configs/pre/*      # Pre-configs (code exists in .zshrc but directory unused)
3. zsh/configs/*.zsh      # Main configs
4. zsh/configs/post/*     # Post-configs (PATH, completion, mise)
5. ~/.aliases             # Shell aliases
6. oh-my-zsh              # Plugins: git, zsh-autosuggestions
```

### Avoiding Conflicts

- Don't create functions with names that conflict with oh-my-zsh aliases
  - Example: `g` is already defined by the git plugin
- Run `alias` after installation to check for conflicts

### Symlink Safety

`install.sh` uses `safe_ln()` which removes existing symlinks before creating new ones. This prevents circular references when running install.sh multiple times.

## Claude Code Configuration

This repository manages Claude Code settings via symlinks to `~/.claude/`:

```text
claude/
├── CLAUDE.md           # User global instructions (Workflow Orchestration, §1–5)
├── settings.json       # Hooks, plugins, permissions
├── statusline.sh       # Custom status line script
├── loop.md             # Default no-arg /loop maintenance routine
├── hooks/              # Lifecycle hooks (3)
│   ├── validate-shell.sh           # PostToolUse: shellcheck validation
│   ├── pre-tool-guard.sh           # PreToolUse: sensitive file block + PR base-freshness guard
│   └── verify-git-on-stop.sh       # Stop: surfaces ground-truth git/PR state vs self-report
└── agents/             # Global agents (1, always loaded)
    └── verify-subagent-result.md
    # side-job-researcher is personal → kept machine-local in ~/.claude/agents/ (not here)
    # Shareable skills AND agents live in the snkrheadz/claude-skills marketplace
    # (core/pm/eng/research packs); invoked as /<pack>:<skill> or
    # enabled per role via `/plugin install <pack>@claude-skills`.
```

### Managed Components

| Component | Description |
|-----------|-------------|
| `CLAUDE.md` | User global instructions (Workflow Orchestration, §1–5 + model routing) |
| `settings.json` | Hooks, plugins, permissions |
| `statusline.sh` | Status line: model, dir+branch, duration, cost (session/daily), lines, braille bars (ctx/5h*/7d*) |
| `hooks/` | 3 lifecycle hooks (PostToolUse, PreToolUse, Stop) |
| `agents/` | 1 global agent (verify-subagent-result) |
| role agents | eng/research packs in the snkrheadz/claude-skills marketplace |

### Status Line

Displays in Claude Code CLI (segments joined by ` | `, conditional ones shown only when data exists):

```
Opus 4.8 | laptop 🌿main | ⏱ 5m | 💰$0.50/$5.20 | +120-45 | ctx ⣿⣿⣄ 45% | 5h* ⣄⠀⠀ 12% | 7d* ⣶⠀⠀ 18%
```

| Segment | Meaning |
|---------|---------|
| `Opus 4.8` | Model display name |
| `laptop 🌿main` | Current directory + git branch |
| `⏱ 5m` | Session duration |
| `💰$0.50/$5.20` | Cost: this session / today's cumulative total |
| `+120-45` | Lines added/removed (hidden when zero) |
| `ctx ⣿⣿⣄ 45%` | Context window usage (braille bar, green→yellow→red gradient) |
| `5h* ⣄⠀⠀ 12%` | 5-hour rate limit usage — all models combined (`*` = not Sonnet-only; shown if available) |
| `7d* ⣶⠀⠀ 18%` | 7-day rate limit usage — all models combined (`*` = not Sonnet-only; shown if available) |

Vim mode and `🤖<agent>` (subagent name) segments are appended when active.

### Hooks

| Hook | Lifecycle Event | Description |
|------|----------------|-------------|
| `validate-shell.sh` | PostToolUse | Runs shellcheck on `.sh` files after Write/Edit |
| `pre-tool-guard.sh` | PreToolUse | Blocks sensitive file access; blocks `gh pr create` when behind the base branch |
| `verify-git-on-stop.sh` | Stop | Surfaces ground-truth git/PR state when the last reply claims a commit/push/PR/merge |

### Agents

Global agents (live in this repo, symlinked to `~/.claude/agents/`, always loaded):

| Agent | Purpose |
|-------|---------|
| `verify-subagent-result` | SubAgent result verification |

Project agent (real file in `.claude/agents/`, this repo only): `diagnose-dotfiles`.
Personal agents (machine-local real files in `~/.claude/agents/`, not dotfiles-managed):
`side-job-researcher` — mirrors the machine-local `side-job-search` skill, so it is
neither synced nor published.

Role agents (eng/research) ship via the **snkrheadz/claude-skills** marketplace;
enable a pack with `/plugin install <pack>@claude-skills` to make its agents available
in every project — e.g. `eng` provides `code-architect`, `architecture-reviewer`,
`verify-shell`, `migration-assistant`, `oncall-guide`, `state-machine-diagram`,
`aws-best-practices-advisor`, `gcp-best-practices-advisor`.

### Available Skills

All shareable skills migrated to the **snkrheadz/claude-skills** marketplace
(core / pm / eng packs) and are invoked as `/<pack>:<skill>` after
`/plugin install <pack>@claude-skills` — e.g. `/eng:test-and-fix`,
`/eng:refactor-swarm`, `/core:first-principles`.

### Local Skills (Project-specific)

The `.claude/skills/` directory contains 14 project-specific skills that are **only available in this repository** (not symlinked to `~/.claude/`). These skills are tailored for managing this dotfiles repository.

| Skill | Description |
|-------|-------------|
| `brew-manage` | Homebrew package management (add/remove/search, Brewfile update) |
| `claude-config` | Claude Code configuration (settings.json, hooks, agents, skills) |
| `dotfiles-rollback` | Backup confirmation and rollback to previous state |
| `dotfiles-sync` | Manual dotfiles sync (Brewfile update, commit, push) |
| `git-config` | Git config files (.gitconfig, .gitmessage, .gitignore) |
| `health-check` | Dotfiles health check (symlinks, configs, dependencies) |
| `hf-spaces` | HuggingFace Spaces search (research demos, model prototypes) |
| `launchd-manage` | Auto-sync launchd agent management (start/stop/logs) |
| `mise-runtime` | Runtime management with mise (Go, Node.js, Python, Ruby) |
| `new-machine-setup` | New machine setup guide (macOS → dotfiles) |
| `security-check` | Security scanning (gitleaks, pre-commit, secrets) |
| `symlink-manage` | Symlink status check and repair (broken link detection) |
| `tmux-config` | tmux configuration (.tmux.conf, keybindings) |
| `zsh-config` | zsh configuration (functions, configs, aliases) |

**Usage:** These skills are invoked using slash commands (e.g., `/brew-manage`, `/health-check`) when working in this repository with Claude Code.

## CodeGraph (Code Intelligence)

[CodeGraph](https://github.com/colbymchenry/codegraph) は tree-sitter で全シンボルを事前解析し SQLite に格納するコード知識グラフです。MCP 経由で Claude Code に提供することで、grep + ファイル読み込みループを 1 回のクエリに圧縮します。

### 自動更新

MCP デーモンが稼働中は **FS ウォッチャー（FSEvents）が 2 秒デバウンスで自動同期**するため、通常は手動操作不要です。

### 手動操作が必要なタイミング

| コマンド | タイミング |
|---------|-----------|
| `codegraph index` | 初回セットアップ後 / `.codegraph/` を削除した後 / 完全再構築したいとき |
| `codegraph sync` | デーモン外（スクリプト等）から差分更新したいとき |
| `codegraph status` | インデックスの状態確認・未同期ファイルの確認 |

### `.codegraph/` の管理

`.codegraph/` ディレクトリは `.gitignore` で除外済みです（マシンローカルなインデックスであり、コミット対象外）。

## License

MIT
