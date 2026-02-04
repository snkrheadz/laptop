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
├── iterm2/                 # iTerm2 settings plist
├── tmux/                   # tmux configuration
├── tig/                    # Tig (git TUI) config
├── fzf/                    # Fuzzy finder config
├── mise/                   # mise runtime manager config
├── bin/                    # Executable scripts (tat)
├── raycast/                # Raycast settings export
├── claude/                 # Claude Code configuration → ~/.claude/
│   ├── CLAUDE.md           # User global instructions
│   ├── settings.json       # Hooks, plugins, permissions
│   ├── statusline.sh       # Custom status line script
│   ├── hooks/              # PostToolUse hooks (2)
│   ├── agents/             # Subagents (16)
│   └── skills/             # Custom skills (9)
│
├── .claude/                # Local skills (project-specific, 13)
│   └── skills/             # Not symlinked to ~/.claude/
│
├── scripts/
│   └── auto-sync.sh        # Hourly auto-sync script
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

## Claude Code Configuration

This repository manages Claude Code settings via symlinks to `~/.claude/`:

```text
claude/
├── CLAUDE.md           # User global instructions
├── settings.json       # Hooks, plugins, permissions
├── statusline.sh       # Custom status line script
├── hooks/              # PostToolUse hooks (2)
│   ├── validate-shell.sh   # shellcheck validation
│   └── save-to-obsidian.js # Obsidian integration
├── agents/             # Subagents (16)
│   ├── verify-shell.md, verify-app.md, build-validator.md
│   ├── code-architect.md, code-simplifier.md, oncall-guide.md
│   ├── aws-best-practices-advisor.md, gcp-best-practices-advisor.md
│   ├── arxiv-ai-researcher.md, gemini-api-researcher.md
│   ├── strategic-research-analyst.md, nano-banana-pro-prompt-generator.md
│   ├── state-machine-diagram.md, migration-assistant.md
│   ├── diagnose-dotfiles.md, verify-subagent-result.md
└── skills/             # Custom skills (9)
    ├── claude-code-guide/  # Claude Code extension guide
    ├── db-query/           # Database query helper
    ├── first-principles/   # First principles analysis
    ├── merge-pr/           # PR merge automation
    ├── project-setup/      # Project setup wizard
    ├── quick-commit/       # Fast commit workflow
    ├── review-changes/     # Code review helper
    ├── techdebt/           # Tech debt analysis
    └── test-and-fix/       # Test and fix workflow
```

### Managed Components

| Component | Description |
|-----------|-------------|
| `CLAUDE.md` | User global instructions (workflow, best practices, prohibitions) |
| `settings.json` | Hooks, plugins, permissions, Obsidian integration |
| `statusline.sh` | Custom status line showing model, cost, context |
| `hooks/` | PostToolUse hooks for shellcheck and Obsidian |
| `agents/` | 16 specialized subagents for various tasks |
| `skills/` | 9 custom skills for common workflows |

### Status Line

Displays in Claude Code CLI:
```
[Opus] 📁 laptop | 🌿 main | 💰 $5.20 (Today) | 📊 185k
```

### Hooks

| Hook | Description |
|------|-------------|
| `validate-shell.sh` | Runs shellcheck on `.sh` files after Write/Edit |
| `save-to-obsidian.js` | Saves conversation context to Obsidian |

### Key Subagents

| Agent | Purpose |
|-------|---------|
| `verify-shell` | Shell script verification |
| `verify-app` | Application verification |
| `build-validator` | Build validation |
| `code-architect` | Architecture design |
| `aws-best-practices-advisor` | AWS guidance |
| `gcp-best-practices-advisor` | GCP guidance |
| `diagnose-dotfiles` | Dotfiles troubleshooting |

### Available Skills

- `/claude-code-guide` - Claude Code extension documentation
- `/quick-commit` - Fast commit workflow
- `/merge-pr` - PR merge with worktree cleanup
- `/review-changes` - Code review helper
- `/test-and-fix` - Run tests and fix failures

### Local Skills (Project-specific)

The `.claude/skills/` directory contains 13 project-specific skills that are **only available in this repository** (not symlinked to `~/.claude/`). These skills are tailored for managing this dotfiles repository.

| Skill | Description |
|-------|-------------|
| `brew-manage` | Homebrew package management (add/remove/search, Brewfile update) |
| `claude-config` | Claude Code configuration (settings.json, hooks, agents, skills) |
| `dotfiles-rollback` | Backup confirmation and rollback to previous state |
| `dotfiles-sync` | Manual dotfiles sync (Brewfile update, commit, push) |
| `git-config` | Git config files (.gitconfig, .gitmessage, .gitignore) |
| `health-check` | Dotfiles health check (symlinks, configs, dependencies) |
| `launchd-manage` | Auto-sync launchd agent management (start/stop/logs) |
| `mise-runtime` | Runtime management with mise (Go, Node.js, Python, Ruby) |
| `new-machine-setup` | New machine setup guide (macOS → dotfiles) |
| `security-check` | Security scanning (gitleaks, pre-commit, secrets) |
| `symlink-manage` | Symlink status check and repair (broken link detection) |
| `tmux-config` | tmux configuration (.tmux.conf, keybindings) |
| `zsh-config` | zsh configuration (functions, configs, aliases) |

**Usage:** These skills are invoked using slash commands (e.g., `/brew-manage`, `/health-check`) when working in this repository with Claude Code.

## License

MIT
