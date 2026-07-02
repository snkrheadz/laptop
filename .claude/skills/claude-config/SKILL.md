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

このリポジトリが管理する Claude Code 設定の確認・編集を行う。

## 管理対象（このリポジトリ固有の対応表）

| ファイル/ディレクトリ | 説明 | 反映先 |
|---------------------|------|-----------|
| `claude/settings.json` | Claude Code設定（hooks/permissions/plugins） | `~/.claude/settings.json` (symlink) |
| `claude/statusline.sh` | ステータスライン表示 | `~/.claude/statusline.sh` (symlink) |
| `claude/CLAUDE.md` | ユーザーグローバル指示 | `~/.claude/CLAUDE.md` (symlink) |
| `claude/loop.md` | no-arg `/loop` の既定ルーチン | `~/.claude/loop.md` (symlink) |
| `claude/hooks/` | ライフサイクル hooks | `~/.claude/hooks/` (symlink) |
| `.claude/skills/` | プロジェクトローカル skills | このリポジトリ内のみ |
| `.claude/agents/` | プロジェクトローカル agents | このリポジトリ内のみ |

共有可能な skills / agents は `snkrheadz/the-boris-way` マーケットプレイスが単一情報源
（`/plugin install <pack>@the-boris-way`、`/<pack>:<skill>` で起動）。
現在の一覧は列挙表を持たず、実体を見る: `ls .claude/skills/ claude/hooks/`、
`jq '.enabledPlugins' claude/settings.json`。

> machine-local（dotfiles 非管理）の実体 agent が `~/.claude/agents/` に置かれることもある
> （例: `side-job-researcher`）。これらは symlink ではないため install/sync で消えない。

## 実行フロー

1. 変更対象ファイルを確認し、**リポジトリ側のファイル**を編集（symlink で反映される）
2. `jq empty claude/settings.json` で構文確認
3. 編集後は `./scripts/sync-claude.sh`（symlink + plugin の再同期）
4. 新しい Claude Code セッションで反映を確認

## 注意事項

- settings.json の構文エラーはセッション起動に影響する — 編集後は必ず `jq empty`
- hooks のコマンドは絶対パス（`~/.claude/hooks/...`）を使用
- plugins は settings.json の `extraKnownMarketplaces` / `enabledPlugins` が宣言状態、
  `scripts/sync-claude-plugins.sh` がそれをマシンに実体化する
