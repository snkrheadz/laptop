# ツール自動承認 (CLI)

非対話モード（CI/CD等）でツール実行を自動承認。

## 基本的な使い方

```bash
# ツール自動承認
claude -p "Fix the bug" --allowedTools "Read,Edit,Bash"

# 特定コマンドのみ許可
claude -p "Create commit" \
  --allowedTools "Bash(git diff:*),Bash(git commit:*)"

# 構造化JSON出力
claude -p "Extract functions" \
  --output-format json \
  --json-schema '{"type":"object","properties":{"functions":{"type":"array"}}}'

# 会話継続
claude -p "Start task" --continue
```

## 利用可能なツール

### 基本ツール

| ツール | 説明 |
|--------|------|
| `Read` | ファイル読み取り |
| `Edit` | ファイル編集 |
| `Write` | ファイル作成 |
| `Bash` | コマンド実行 |
| `Glob` | ファイル検索 |
| `Grep` | テキスト検索 |

### 制限付きツール

```bash
# git コマンドのみ許可
--allowedTools "Bash(git:*)"

# npm コマンドのみ許可
--allowedTools "Bash(npm:*)"

# 特定のコマンドパターン
--allowedTools "Bash(git diff:*),Bash(git commit:*)"
```

### エージェントツール

```bash
# すべてのエージェント
--allowedTools "Task"

# 特定のエージェントのみ
--allowedTools "Task(agent-name)"
```

### その他のツール

| ツール | 説明 |
|--------|------|
| `Skill` | スキル呼び出し |
| `AskUserQuestion` | ユーザーへの質問 |

## 出力フォーマット

### JSON出力

```bash
claude -p "List files" \
  --output-format json \
  --json-schema '{"type":"object","properties":{"files":{"type":"array","items":{"type":"string"}}}}'
```

### テキスト出力（デフォルト）

```bash
claude -p "Explain the code"
```

## CI/CD での使用例

### GitHub Actions

```yaml
- name: Run Claude
  run: |
    claude -p "Fix linting errors" \
      --allowedTools "Read,Edit,Bash(npm:*)" \
      --output-format json
```

### 環境変数

```bash
export ANTHROPIC_API_KEY="your-key"
claude -p "Your prompt"
```

## セキュリティ考慮事項

1. **最小権限の原則**: 必要なツールのみ許可
2. **コマンド制限**: `Bash(command:*)` で特定コマンドに制限
3. **出力検証**: JSON スキーマで出力を検証
4. **シークレット管理**: API キーは環境変数で管理
