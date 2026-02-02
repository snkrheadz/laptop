# サブエージェント (Sub-agents)

特定のタスクを委譲するカスタムエージェントを定義。

## ファイル配置

```
~/.claude/agents/          # ユーザーレベル（全プロジェクト）
.claude/agents/            # プロジェクトレベル（version control推奨）
```

## テンプレート

```markdown
---
name: agent-name
description: エージェントの説明（いつ使うか）
tools: Read, Grep, Glob
model: sonnet
permissionMode: default
---

指示内容...
```

## 設定オプション

| フィールド | 値 |
|-----------|------|
| `tools` | `Read`, `Edit`, `Write`, `Bash`, `Glob`, `Grep`, `Task` など |
| `model` | `sonnet`, `opus`, `haiku`, `inherit` |
| `permissionMode` | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan` |
| `hooks` | `PreToolUse`, `PostToolUse`, `Stop` イベント |

## permissionMode 詳細

| モード | 説明 |
|--------|------|
| `default` | 通常の権限確認 |
| `acceptEdits` | 編集を自動承認 |
| `dontAsk` | 確認なしで実行（危険） |
| `bypassPermissions` | すべての権限をバイパス（危険） |
| `plan` | 計画モード（実行しない） |

## 組み込みサブエージェント

- `Explore`: 読み取り専用、コードベース探索用
- `Plan`: 計画立案用
- `general-purpose`: 複雑なマルチステップタスク

## 使用例

### Task tool での呼び出し

```json
{
  "subagent_type": "agent-name",
  "prompt": "タスクの説明",
  "description": "短い説明（3-5語）"
}
```

### エージェント内でのフック定義

```markdown
---
name: my-agent
hooks:
  PostToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: echo "Bash executed"
---
```
