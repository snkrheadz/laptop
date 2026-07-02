---
description: "Git設定ファイル管理。.gitconfig、.gitmessage、.gitignoreの確認・編集。トリガー: git config, gitconfig, gitmessage, gitignore, git設定"
model: sonnet
allowed-tools:
  - Bash
  - Read
  - Edit
  - Grep
---

# git-config スキル

dotfiles リポジトリで管理している Git 設定ファイルの確認・編集を行う。

## 管理対象ファイル（このリポジトリ固有の対応表）

| ファイル | 説明 | symlink先 |
|---------|------|-----------|
| `git/.gitconfig` | Gitグローバル設定 | `~/.gitconfig` |
| `git/.gitmessage` | コミットメッセージテンプレート | `~/.gitmessage` |
| `git/.gitignore_global` | グローバルgitignore | `~/.gitignore` |

確認は `git config --list --show-origin`、symlink 状態は
`ls -la ~/.gitconfig ~/.gitmessage ~/.gitignore`。

## 注意事項

- 変更は **リポジトリ側の `git/.gitconfig`** に対して行う（symlink で `~/.gitconfig` に反映）
- 機密情報（トークン等）は直接書かない（`~/.secrets.env` へ）
- エイリアス追加時は oh-my-zsh の git プラグインと競合しないか確認（例: `g` は使用済み）
