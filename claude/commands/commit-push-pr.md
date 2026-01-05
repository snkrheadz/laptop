---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git commit:*), Bash(git push:*), Bash(git branch:*), Bash(git log:*), Bash(gh pr create:*), Bash(gh pr view:*)
description: コミット、プッシュ、PR作成を一括実行
argument-hint: [PR title (optional)]
---

## コンテキスト

### 現在のブランチ
!`git branch --show-current`

### Git Status
!`git status --short`

### 変更内容（diff）
!`git diff HEAD --stat`

### 最近のコミット（スタイル参考）
!`git log --oneline -5`

## タスク

上記の変更に基づいて、以下を実行してください：

1. **変更をステージング**: 必要なファイルを `git add`
2. **コミット作成**: 変更内容を分析し、適切なコミットメッセージを作成
   - 規約: `<type>: <description>` 形式
   - type: feat, fix, chore, docs, refactor, test など
3. **リモートにプッシュ**: `git push -u origin <branch>`
4. **PR作成**: `gh pr create` でPRを作成
   - タイトル: $ARGUMENTS があればそれを使用、なければコミットメッセージから生成
   - 本文: 変更内容のサマリーを含める

## 注意事項

- .env, credentials, secrets などの機密ファイルはコミットしない
- main/master ブランチへの直接プッシュは確認を求める
- 既にPRが存在する場合は、既存PRのURLを表示
