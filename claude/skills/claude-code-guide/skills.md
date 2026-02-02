# エージェントスキル (Skills)

Claude が自動的に選択・実行するスキルを定義。

## ファイル配置

```
~/.claude/skills/skill-name/SKILL.md   # ユーザーレベル
.claude/skills/skill-name/SKILL.md     # プロジェクトレベル
```

## SKILL.md テンプレート

```markdown
---
name: skill-name
description: "説明とトリガーキーワード"
allowed-tools: Read, Grep
model: sonnet
context: fork               # オプション: 独立コンテキスト
user-invocable: true        # オプション: /メニュー表示
---

スキルの指示...
```

## メタデータオプション

| フィールド | 説明 | デフォルト |
|-----------|------|-----------|
| `name` | スキル名（小文字、ハイフン、最大64文字） | 必須 |
| `description` | 説明とトリガーキーワード（Claudeが自動判定に使用） | 必須 |
| `allowed-tools` | ツール制限（カンマ区切り） | すべて許可 |
| `model` | 実行モデル（sonnet, opus, haiku） | inherit |
| `context` | `fork` で独立コンテキスト | 親コンテキスト共有 |
| `user-invocable` | `/` メニューに表示するか | true |

## 進歩的情報開示 (Progressive Disclosure)

スキルが大きくなる場合、関連ファイルに分割する:

```
my-skill/
├── SKILL.md          # 概要（500行以下推奨）
├── reference.md      # 詳細（参照時読み込み）
├── examples.md       # 使用例
└── scripts/
    └── helper.py     # 実行のみ（内容読み込まない）
```

SKILL.md から参照:

```markdown
詳細は reference.md を参照してください。
```

## スキルの自動選択

Claude は `description` フィールドのキーワードに基づいてスキルを自動選択する。

### 効果的な description の書き方

```yaml
# 良い例
description: "Git操作のヘルプ。トリガー: git, commit, push, branch, merge"

# 悪い例
description: "バージョン管理ツール"
```

## user-invocable の使い分け

| 設定 | 用途 |
|------|------|
| `true` | ユーザーが `/skill-name` で明示的に呼び出せる |
| `false` | 自動選択のみ、メニューに表示しない |

## context: fork の使い方

独立したサブエージェントとして実行:

```yaml
context: fork
```

- 親コンテキストを汚染しない
- 独立したツール実行環境
- 結果のみ親に返す
