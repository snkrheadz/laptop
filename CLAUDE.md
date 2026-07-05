# CLAUDE.md

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
│   └── hooks/          # Lifecycle hooks (3): validate-shell.sh,
│                       #   verify-git-on-stop.sh, cost-alert.sh
│
├── .claude/            # Project-local config (NOT symlinked to ~/.claude/)
│   ├── agents/         # Project agents (1): diagnose-dotfiles (real file, dotfiles-specific)
│   └── skills/         # Local skills — source of truth is the directory (ls .claude/skills/)
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

### Claude Code Configuration

The `claude/` directory contains Claude Code settings managed by this repository:

**Managed files** (symlinked to `~/.claude/`):
- `settings.json` - Hooks, plugins, permissions, statusLine config
- `statusline.sh` - Status line display script
- `CLAUDE.md` - User global instructions (Workflow Orchestration §1–§5)
- `loop.md` - Default no-arg `/loop` maintenance routine

**Hooks** (3):
- `hooks/validate-shell.sh` - PostToolUse hook for shellcheck
- `hooks/verify-git-on-stop.sh` - Stop hook: when the last reply claims a commit/push/PR/merge, injects actual `git`/`gh pr` state so false-success reports get caught against reality (near-silent otherwise; `stop_hook_active`-guarded)
- `hooks/cost-alert.sh` - Stop hook: fires a native notification, once per session, when session/daily cost crosses a threshold (default $5/$20, env-overridable) — replaces statusline.sh's old always-on cost segment

> Note: sensitive-file access is guarded by two accident-prevention layers: `settings.json` `deny` rules (harness-native) and the `pre-tool-guard.sh` PreToolUse hook shipped by `core@the-boris-way` (the local copy in `claude/hooks/` was removed; the plugin one still runs on every Bash call). Neither is a security boundary — they catch mistakes, not adversaries. `gh pr create` base-sync is handled by the `/eng:create-pr` skill.

**Global Agents** (0 in this repo): `claude/agents/` is empty — all shareable agents
(including `verify-subagent-result`, moved to the `research` pack) live in the
`snkrheadz/the-boris-way` marketplace.

**Project Agents** (1, dotfiles repo only — real file in `.claude/agents/`):
- `diagnose-dotfiles` - Dotfiles troubleshooting (specific to this repo)

> `side-job-researcher` is personal and kept **machine-local** (a real file in
> `~/.claude/agents/`, not dotfiles-managed), mirroring its machine-local
> `side-job-search` skill — so it is not synced or published to the marketplace.

**Shareable agents** now live in the **`snkrheadz/the-boris-way`** marketplace
(single source of truth) alongside the skills, enabled per role via
`/plugin install <pack>@the-boris-way`:
- **eng** (8 agents): `code-architect`, `architecture-reviewer`, `verify-shell`,
  `migration-assistant`, `oncall-guide`, `state-machine-diagram`,
  `aws-best-practices-advisor`, `gcp-best-practices-advisor`
- **research**: `arxiv-ai-researcher`, `gemini-api-researcher`, `huggingface-spaces-researcher`, `verify-subagent-result`

Packs in `snkrheadz/the-boris-way` (declared in `settings.json`, installed via `scripts/sync-claude-plugins.sh`, namespaced as `/<pack>:<skill>`):
`core` | `pm` | `eng` | `research` | `strategy` | `spec` (the marketplace also ships `writing`, not enabled here)

The spec pipeline is provided by `spec@the-boris-way` (`/spec:scan` → … → `/spec:review`);
the former `claude/commands/spec-*.md` + `implement-with-notes` copies were removed.

**Local Skills** - Project-specific, in `.claude/skills/` (only available in this
repository, not symlinked to `~/.claude/`). The directory is the source of truth:
list them with `ls .claude/skills/`; each `SKILL.md`'s `description:` frontmatter
carries its purpose and triggers. The human-readable table lives in README.md and
`scripts/verify.sh` fails when a skill is missing from it — no hand-maintained
count to rot here.
