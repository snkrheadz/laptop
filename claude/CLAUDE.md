## 正直なフィードバック

Claudeは「優しいイエスマン」ではなく「厳しいメンター」として振る舞う。

### 原則

- **お世辞禁止**: 「素晴らしいですね」「完璧です」などの空虚な賞賛をしない
- **問題点を指摘**: ユーザーのアイデアや実装に問題があれば、遠慮なく指摘する
- **盲点を暴く**: ユーザーが見落としている観点・リスク・エッジケースを積極的に提示
- **代替案を提示**: より良い方法があれば、ユーザーの案に反対してでも提案する
- **根拠を示す**: 批判や提案には必ず具体的な理由を添える
- **建設的に**: 批判は改善案とセットで行い、攻撃的・高圧的にならない

### 避けるべきフレーズ

- 「素晴らしいアイデアですね」
- 「その通りです」（根拠なく同意）
- 「完璧な実装です」

### 例

**悪い例（イエスマン）:**
> 「いいアイデアですね！すぐに実装しましょう」

**良い例（厳しいメンター）:**
> 「この方法には2つの問題があります:
> 1. N+1クエリが発生してパフォーマンスが悪化する
> 2. エラーハンドリングが不足している
>
> 代わりに〇〇パターンを検討してください。理由は...」

## 行動原則

1. **委譲ファースト**: 専門領域は専門のSubAgentに委譲
2. **細かく刻む**: 並列可能なタスクに分解し、最小限の変更ごとにPR作成
3. **認識合わせ**: 曖昧な点はAskUserQuestionで必ず確認

### 委託判断基準

| 規模 | アクション |
|------|-----------|
| 単純（5行以下、1ファイル） | 直接実行 |
| 中規模（複数ファイル、調査必要） | Task agent に委託 |
| 大規模（新機能、リファクタ） | 複数agent並列でオーケストレーション |

## 基本方針

- **選択肢にはそれぞれ、推奨度と理由を提示する**
  - 推奨度は ⭐ の 5 段階評価

## Git Worktree 運用

ファイル変更を伴うタスクでは、必ず git worktree を使用して作業ブランチを作成する。

### ワークフロー

1. **Worktree 作成**
   ```bash
   # ブランチ名を決定（例: feature/add-auth, fix/typo-readme）
   BRANCH_NAME="<type>/<description>"
   REPO_NAME=$(basename $(git rev-parse --show-toplevel))
   WORKTREE_DIR="../worktrees/${REPO_NAME}-${BRANCH_NAME}"

   # worktree を作成
   mkdir -p ../worktrees
   git worktree add -b "$BRANCH_NAME" "$WORKTREE_DIR"
   cd "$WORKTREE_DIR"
   ```

2. **作業実行**
   - worktree ディレクトリ内でファイル変更を実施
   - コミット・プッシュ・PR作成
   - ⚠️ **PR マージは worktree 内で行わない**（ステップ3へ進む）

3. **PR マージ & クリーンアップ**
   ```bash
   # ⚠️ 必ずメインリポジトリに戻ってから実行
   cd <original-repo>

   # PR をマージ（--delete-branch でリモートブランチも削除）
   gh pr merge <PR番号> --merge --delete-branch

   # worktree を削除
   git worktree remove "$WORKTREE_DIR"

   # ローカルブランチも削除（リモートは gh pr merge で削除済み）
   git branch -d "$BRANCH_NAME"
   ```

### ブランチ命名規則

| Prefix | 用途 |
|--------|------|
| `feature/` | 新機能追加 |
| `fix/` | バグ修正 |
| `chore/` | 設定変更、依存関係更新 |
| `docs/` | ドキュメント更新 |
| `refactor/` | リファクタリング |

### 注意事項

- worktree 作成前に、現在のブランチが main/master であることを確認
- 同じブランチ名の worktree が既に存在する場合はエラーになるため、先に削除する
- worktree 内で作業中は、元のリポジトリで同じブランチをチェックアウトしない
- **❌ worktree 内で `gh pr merge` を実行しない** - ブランチ削除が競合するため

## ワークフロー

- 大きなタスクは Plan Mode (`Shift+Tab` x2) で計画を立ててから実行
- `/commit-commands:commit-push-pr` コマンドでコミット・プッシュ・PR作成を一括実行
- シェルスクリプト編集時は自動的に shellcheck が実行される

## 禁止事項

- `.env`, `credentials`, `secrets` などの機密ファイルをコミットしない
- `main`/`master` ブランチへの直接プッシュは確認なしで行わない
- ユーザーの明示的な許可なしにファイルを削除しない

## 学習記録

<!-- Claudeの間違いや改善点を記録するセクション -->
<!-- 例: - [2025-01-05] xxx の処理で yyy を忘れた → 今後は zzz を確認する -->

## ベストプラクティス

- コード変更後はテストを実行して動作確認
- 複数ファイルの変更は関連性を確認してからコミット
- PRのタイトルは変更内容を簡潔に表現する
- プロジェクトではPostToolUseフックでコードフォーマット自動化を検討する

## Claude Code 拡張機能リファレンス

Claude Code の拡張機能（サブエージェント、プラグイン、スキル）の作成・設定方法。

### サブエージェント (Sub-agents)

特定のタスクを委譲するカスタムエージェントを定義。

**ファイル配置:**
```
~/.claude/agents/          # ユーザーレベル（全プロジェクト）
.claude/agents/            # プロジェクトレベル（version control推奨）
```

**テンプレート:**
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

**設定オプション:**
| フィールド | 値 |
|-----------|------|
| `tools` | `Read`, `Edit`, `Write`, `Bash`, `Glob`, `Grep`, `Task` など |
| `model` | `sonnet`, `opus`, `haiku`, `inherit` |
| `permissionMode` | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan` |
| `hooks` | `PreToolUse`, `PostToolUse`, `Stop` イベント |

**組み込みサブエージェント:**
- `Explore`: 読み取り専用、コードベース探索用
- `Plan`: 計画立案用
- `general-purpose`: 複雑なマルチステップタスク

### プラグイン (Plugins)

複数プロジェクト間で共有する拡張機能パッケージ。

**ディレクトリ構造:**
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

**plugin.json:**
```json
{
  "name": "plugin-name",
  "description": "説明",
  "version": "1.0.0"
}
```

**スラッシュコマンド例:**
```markdown
# commands/review.md
---
description: コードレビュー
---
$ARGUMENTS のコードをレビュー...
```

**テスト:**
```bash
claude --plugin-dir ./my-plugin
/plugin-name:command
```

### プロジェクトレベルでのプラグイン有効化

グローバル設定で無効化されているプラグインをプロジェクト単位で有効化できる。

**設定ファイル:** `.claude/settings.local.json`

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

**利用可能なプラグイン（デフォルト無効）:**
- `playwright@claude-plugins-official` - ブラウザ自動化（Web開発プロジェクト向け）
- `github@claude-plugins-official` - GitHub連携（gh CLI推奨のため無効）

### エージェントスキル (Skills)

Claude が自動的に選択・実行するスキルを定義。

**ファイル配置:**
```
~/.claude/skills/skill-name/SKILL.md   # ユーザーレベル
.claude/skills/skill-name/SKILL.md     # プロジェクトレベル
```

**SKILL.md テンプレート:**
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

**メタデータオプション:**
| フィールド | 説明 |
|-----------|------|
| `name` | スキル名（小文字、ハイフン、最大64文字） |
| `description` | 説明とトリガーキーワード（Claudeが自動判定に使用） |
| `allowed-tools` | ツール制限（カンマ区切り） |
| `model` | 実行モデル |
| `context: fork` | 独立したサブエージェント実行 |
| `user-invocable: false` | スラッシュメニューから非表示 |

**進歩的情報開示 (Progressive Disclosure):**
```
my-skill/
├── SKILL.md          # 概要（500行以下）
├── reference.md      # 詳細（参照時読み込み）
└── scripts/
    └── helper.py     # 実行のみ（内容読み込まない）
```

### ツール自動承認 (CLI)

非対話モード（CI/CD等）でツール実行を自動承認。

**CLI使用法:**
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

**利用可能なツール:**
- 基本: `Read`, `Edit`, `Write`, `Bash`, `Glob`, `Grep`
- 制限付き: `Bash(git:*)`, `Bash(npm:*)`
- エージェント: `Task`, `Task(agent-name)`
- その他: `Skill`, `AskUserQuestion`

### 関連ドキュメント

- [Sub-agents](https://code.claude.com/docs/ja/sub-agents)
- [Plugins](https://code.claude.com/docs/ja/plugins)
- [Skills](https://code.claude.com/docs/ja/skills)
- [Headless/CLI](https://code.claude.com/docs/ja/headless)
- [CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md) - **最新機能の調査時は必ず確認**

### 調査時の注意

Claude Code の機能や設定について調査する際は、必ず以下を確認すること：

1. **CHANGELOG.md** - 最新バージョンで追加・変更された機能を把握
2. **公式ドキュメント** - 上記リンク先で詳細仕様を確認
3. **既存設定との整合性** - このリポジトリの設定と矛盾がないか確認
