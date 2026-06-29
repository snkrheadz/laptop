---
description: "Claude Code設定管理。settings.json、hooks、agents、skillsの確認・編集。トリガー: claude設定, hooks, settings, claude config, エージェント設定"
model: sonnet
allowed-tools:
  - Bash
  - Read
  - Edit
  - Grep
  - Glob
---

# claude-config スキル

Claude Code設定ファイルの確認・編集を行う。

## 管理対象ファイル

| ファイル/ディレクトリ | 説明 | symlink先 |
|---------------------|------|-----------|
| `claude/settings.json` | Claude Code設定 | `~/.claude/settings.json` |
| `claude/statusline.sh` | ステータスライン表示 | `~/.claude/statusline.sh` |
| `claude/CLAUDE.md` | ユーザーグローバル指示 | `~/.claude/CLAUDE.md` |
| `claude/hooks/` | PostToolUseフック | `~/.claude/hooks/` |
| `claude/agents/` | カスタムエージェント | `~/.claude/agents/` |
| `.claude/skills/` | カスタムスキル | プロジェクトレベル |

## コマンド

### settings.json確認

```bash
cat /Users/snkrheadz/ghq/github.com/snkrheadz/laptop/claude/settings.json
```

### symlinkの状態確認

```bash
ls -la ~/.claude/
ls -la ~/.claude/settings.json
ls -la ~/.claude/hooks/
ls -la ~/.claude/agents/
```

### agents一覧

```bash
ls -la /Users/snkrheadz/ghq/github.com/snkrheadz/laptop/claude/agents/
```

### skills一覧

```bash
ls -la /Users/snkrheadz/ghq/github.com/snkrheadz/laptop/.claude/skills/
```

### hooks一覧

```bash
ls -la /Users/snkrheadz/ghq/github.com/snkrheadz/laptop/claude/hooks/
```

### CLAUDE.md確認

```bash
cat /Users/snkrheadz/ghq/github.com/snkrheadz/laptop/claude/CLAUDE.md | head -100
```

### statusline.sh確認

```bash
cat /Users/snkrheadz/ghq/github.com/snkrheadz/laptop/claude/statusline.sh
```

## settings.jsonの構造

```json
{
  "hooks": {
    "PostToolUse": [...],
    "Stop": [...]
  },
  "plugins": {
    "allowed": [...]
  },
  "permissions": {
    "allow": [...],
    "deny": [...]
  },
  "statusLine": "shell:/path/to/statusline.sh"
}
```

## Hooksの設定

### PostToolUse

ツール実行後に自動実行されるフック。

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "shellcheck -x \"$CLAUDE_FILE_PATH\"",
            "condition": "glob:.sh"
          }
        ]
      }
    ]
  }
}
```

## 実行フロー

### 設定確認

1. settings.jsonの内容確認
2. symlinkの状態確認
3. 利用可能なagents/skillsの一覧表示

### 設定変更

1. 変更対象ファイルの確認
2. 変更内容のレビュー
3. ファイル編集
4. Claude Code再起動の案内

## 使用例

- "Claude設定を確認"
- "settings.jsonを見せて"
- "利用可能なagentsを一覧"
- "hooksの設定を確認"
- "skillsを一覧"

## Skills（プロジェクトレベル）

| スキル | トリガー |
|--------|---------|
| `brew-manage` | brew, homebrew, package |
| `dotfiles-rollback` | rollback, backup, restore |
| `dotfiles-sync` | sync, 同期, push |
| `mise-runtime` | mise, runtime, node, go |
| `security-check` | security, gitleaks, scan |
| `zsh-config` | zsh, shell, alias |
| `health-check` | 健全性, 診断, check |
| `symlink-manage` | symlink, link, リンク |
| `git-config` | git config, gitconfig |
| `launchd-manage` | launchd, auto-sync |
| `claude-config` | claude設定, hooks |
| `tmux-config` | tmux |
| `new-machine-setup` | 新マシン, setup |

## Agents

### Global（dotfiles 管理・`~/.claude/agents/` に symlink）

| エージェント | 説明 |
|-------------|------|
| `verify-subagent-result` | SubAgent 結果の検証 |

### Project-local（このリポジトリのみ・`.claude/agents/` の実体ファイル）

| エージェント | 説明 |
|-------------|------|
| `diagnose-dotfiles` | dotfiles の問題診断 |

### Role agents（claude-skills マーケットプレイス経由）

`verify-shell` / `verify-app` / `code-architect` / `migration-assistant` などの
役割別 agent は `snkrheadz/claude-skills` のパック（eng/marketer/designer/research）に
移行済み。`/plugin install <pack>@claude-skills` で有効化すると全プロジェクトで使える。

> machine-local（dotfiles 非管理）の実体 agent が `~/.claude/agents/` に置かれることもある
> （例: `side-job-researcher`）。これらは symlink ではないため install/sync で消えない。

## 注意事項

- 設定変更後はClaude Code再起動が必要
- settings.jsonの構文エラーに注意
- hooksのコマンドは絶対パスを使用
- global agents は dotfiles の `claude/agents/` → `~/.claude/agents/` に symlink
- role agents はマーケットプレイスのパック install で全プロジェクト有効化
- skills はプロジェクトレベル（`.claude/skills/`）またはマーケットプレイス（`/<pack>:<skill>`）
