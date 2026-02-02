# プラグイン (Plugins)

複数プロジェクト間で共有する拡張機能パッケージ。

## ディレクトリ構造

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json         # 必須
├── commands/               # スラッシュコマンド
│   └── hello.md
├── agents/                 # サブエージェント
├── skills/                 # スキル
└── hooks/
    └── hooks.json
```

## plugin.json

```json
{
  "name": "plugin-name",
  "description": "説明",
  "version": "1.0.0"
}
```

## スラッシュコマンド

### 基本テンプレート

```markdown
# commands/review.md
---
description: コードレビュー
---
$ARGUMENTS のコードをレビュー...
```

### 変数

- `$ARGUMENTS` - コマンド呼び出し時の引数
- `$FILE_PATH` - 現在のファイルパス（該当する場合）

## テスト方法

```bash
# ローカルプラグインをテスト
claude --plugin-dir ./my-plugin

# コマンド呼び出し
/plugin-name:command
```

## プロジェクトレベルでのプラグイン有効化

グローバル設定で無効化されているプラグインをプロジェクト単位で有効化できる。

### 設定ファイル

`.claude/settings.local.json`:

```json
{
  "permissions": {
    "allow": [
      "mcp__plugin_playwright_playwright__*",
      "mcp__awslabs_aws-documentation-mcp-server__*"
    ]
  },
  "enabledPlugins": {
    "playwright@claude-plugins-official": true
  }
}
```

## 利用可能なプラグイン（デフォルト無効）

| プラグイン | 説明 | 用途 |
|-----------|------|------|
| `playwright@claude-plugins-official` | ブラウザ自動化 | Web開発プロジェクト |
| `github@claude-plugins-official` | GitHub連携 | gh CLI推奨のため通常無効 |

## プラグイン配布

1. GitHub リポジトリにプラグインを公開
2. ユーザーは `~/.claude/plugins/` にクローン
3. または `claude --plugin-dir` で一時的に読み込み
