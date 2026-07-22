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

Top-level map only — for any directory below, the source of truth is the directory
itself (`ls <dir>`) plus each file's header comment.

```text
├── install.sh          # Main installer (backup → symlinks → brew packages → security)
├── rollback.sh         # Restore from backup
├── scripts/            # Maintenance scripts (ls scripts/ + each header)
│   └── verify.sh       #   the Closing Gate entrypoint (also runs claude/hooks/*_test.sh)
├── Brewfile            # Homebrew packages, casks, VSCode extensions
├── zsh/ git/ tmux/ tig/ fzf/ ghostty/ iterm2/ mise/ bin/ raycast/
│                       # One dir per tool; install.sh symlinks them into $HOME, except:
│                       #   iterm2/ & raycast/ are manual-import settings exports, and
│                       #   bin/ joins PATH via zsh/configs/post/path.zsh (no symlink)
├── claude/             # Claude Code global config → ~/.claude/ (settings.json, CLAUDE.md,
│                       #   loop.md, statusline.sh, hooks/, skills/)
├── .claude/            # Project-local config (NOT symlinked to ~/.claude/): agents/, skills/
├── evals/              # Behavioral eval suite (tasks sourced from tasks/lessons.md; evals/run.sh)
├── docs/               # Reference docs (e.g. evals-for-ai-agents.md — basis for claude/CLAUDE.md §4)
├── .github/workflows/main.yml  # CI/CD (gitleaks + shellcheck)
├── .codegraph/         # CodeGraph index (SQLite; auto-synced by the MCP daemon's FS watcher)
├── .pre-commit-config.yaml     # Pre-commit hooks config
├── .gitleaks.toml              # Gitleaks secret scanning config
└── .gitignore                  # Enhanced security-focused gitignore
```

## Key Features

- **Manual sync**: run `./scripts/auto-sync.sh` to commit and push changes (no background agent; launchd auto-sync removed)
- **Secrets**: Store API keys in `~/.secrets.env` (gitignored, created by install.sh)
- **Runtimes**: mise manages Go 1.24.3, Node.js 25.2.1/22.16.0, Python 3.13, Ruby 3.4.8

## Development Notes

### Closing Gate (run before declaring work done)

- `source ~/.zshrc` loads clean
- `shellcheck` passes on changed scripts
- `pre-commit run --all-files` is green
- the `/health-check` skill reports no broken symlinks

Tools for running the gate: the `verify-shell` agent (from `eng@the-boris-way`),
the official `/verify` skill, and `/eng:test-and-fix` for repair loops.

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
- `CLAUDE.md` - User global instructions (Workflow Orchestration §1–6)
- `loop.md` - Default no-arg `/loop` maintenance routine
- `skills/*` - Global personal skills (each dir → `~/.claude/skills/<name>`; available in every repo, unlike `.claude/skills/`)

**Hooks** — source of truth is `claude/hooks/`: each hook's header comment carries its
full spec, and each has a `*_test.sh` behavior suite that `scripts/verify.sh` discovers
via the `claude/hooks/*_test.sh` glob. One-line map:

- `validate-shell.sh` — PostToolUse: shellcheck on edited shell scripts
- `cost-alert.sh` — Stop: native notification, once per session, when session/daily cost crosses a threshold (default $5/$20, env-overridable)
- `check-pr-base.sh` — PreToolUse (Bash): blocks `gh … pr create` when `origin/<default-branch>` is not an ancestor of HEAD; a command that syncs the base in the same block (the `/eng:create-pr` flow) passes
- `check-pr-reviewed.sh` — PreToolUse (Bash): blocks `gh … pr create` until a `/code-review` or `/security-review` ran this session ("code review on by default"; human-only escape hatch documented in README.md)
- `check-pr-verify-warn.sh` — PreToolUse (Bash): WARNS (never blocks) when `scripts/verify.sh` hasn't run this session — warning-only by design (#120) because verify.sh's verdict is environment-dependent (it SKIPs tool-dependent checks), so a hard gate would false-block
- `weekly-maintenance.sh` — SessionStart: weekly-throttled symlink/repo-drift sweep; detection only, never mutates

All three PR-gate hooks guard Bash-tool `gh … pr create` calls only and fail open on
every anomaly. PR sequence: review first, then create. Sensitive-file access is guarded
by `settings.json` deny rules + the `pre-tool-guard.sh` hook shipped by
`core@the-boris-way` — accident guardrails, not a security boundary.

**Agents & packs** — single source of truth is the `snkrheadz/the-boris-way`
marketplace (per-pack agent/skill contents live in its repo); the packs enabled here
are declared in `settings.json` and materialized by `scripts/sync-claude-plugins.sh`
(namespaced `/<pack>:<skill>`). Project-local agents: `ls .claude/agents/`
(dotfiles-specific only). `side-job-researcher` stays machine-local in
`~/.claude/agents/` by design (mirrors its machine-local `side-job-search` skill) —
never synced or published. The spec pipeline is provided by `spec@the-boris-way`; the
former `claude/commands/spec-*.md` copies were removed — don't recreate them.

**Local Skills** - Project-specific, in `.claude/skills/` (only available in this
repository, not symlinked to `~/.claude/`). The directory is the source of truth:
list them with `ls .claude/skills/`; each `SKILL.md`'s `description:` frontmatter
carries its purpose and triggers. The human-readable table lives in README.md and
`scripts/verify.sh` fails when a skill is missing from it — no hand-maintained
count to rot here.
