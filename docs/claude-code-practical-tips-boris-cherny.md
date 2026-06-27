# Boris Cherny「Claude Code 実践活用ガイド」まとめ

> 登壇者: **Boris Cherny**（Anthropic / Claude Code 開発者）
> 動画: *Practical Tips on How to use Claude Code*（YouTube: https://www.youtube.com/watch?v=M8HuXu_bOco）
> 本ドキュメントは講演スライド（全18枚）の OCR 内容をもとに再構成したものです。

Claude Code の設計思想から、セットアップ、日常ワークフロー、コンテキスト設計、チーム共有、並列実行までを一通り解説した講演です。スライドの流れに沿って整理します。

---

## 1. Claude Code とは — 新しいタイプの AI アシスタント

Claude Code は従来の「IDE 補完型」AI とは別物として設計されています。5つの特徴：

1. **ターミナルベース（IDE ではない）** — エディタに縛られない
2. **あらゆるツールと連携できる** — bash で動くものは何でも使える
3. **既存のワークフローに溶け込む** — 新しい環境への移行を強制しない
4. **汎用的** — コーディングに限らずほぼ何にでも使える
5. **無限にハック可能（Infinitely hackable）** — 自分好みに拡張・カスタマイズできる

> ポイント: 「特定の使い方を押し付けない、土台としてのツール」という思想。

---

## 2. セットアップを最適化する（Optimize your setup）

導入直後にやっておくべき設定コマンド：

| コマンド | 役割 |
|---|---|
| `/allowed-tools` | ツール実行権限のカスタマイズ |
| `/install-github-app` | GitHub の Issue / PR で `@claude` をタグ付けして呼べるように |
| `/config` | 通知（notifications）をオンにする |
| `/terminal-setup` | **Shift+Enter** で改行を入力できるようにする |
| `/theme` | ライト / ダークモードの切り替え |
| （macOS の dictation を有効化） | 音声入力でプロンプトを書く |

> 通知オンと Shift+Enter 改行は、体験が大きく変わるので最初に設定推奨。

---

## 3. コードベースについて質問する（最初の入り口）

新規ユーザーにとって **最も簡単な始め方** は「コードベースに質問すること」：

1. 新しいユーザーが Claude Code を始める最も簡単な方法
2. **セットアップ不要（Zero setup）**
3. **データはローカルに留まる（Your data stays local）**

### 質問プロンプト例
- `How is @RoutingController.py used?`（このファイルはどう使われている？）
- `How do I make a new @app/services/ValidationTemplateFactory?`
- `Why does recoverFromException take so many arguments? Look through git history to answer`（git 履歴を調べて答えて）
- `Why did we fix issue #18363 by adding the if/else in @src/login.ts API?`
- `In which version did we release the new @api/ext/PreHooks.php API?`
- `Look at PR #9383, then carefully verify which app versions were impacted`
- `What did I ship last week?`（先週何をリリースした？）

> `@ファイル名` でファイルを、`#issue番号`・`PR番号` で履歴を参照させられる。git 履歴や PR まで遡って「なぜそうなったか」を答えられるのが強み。

---

## 4. ツールで実作業をこなす（Use tools to get things done）

- Claude Code は **十数個のツールを標準搭載**。このツール群こそが Claude Code を強力にしている。
- **組み込みツール**: bash / ファイル検索 / ファイル一覧 / ファイル読み書き / Web fetch・検索 / TODO 管理 / **サブエージェント**

> スライドの実演では、コードの重複を削減 → `npm run lint` → `npm run typecheck` を自動で走らせ、すべてパスするまで検証してから変更サマリを提示する様子が示されている。「書く → 検証する」までを一貫して実行する。

---

## 5. ツールの使い方を自分流に誘導する（Steer Claude）

プロンプトで作業の進め方を指示できる：

- `Propose a few fixes for issue #8732, then implement the one I pick`（複数案を出して、選んだものを実装）
- `Identify edge cases that are not covered in @app/tests/signupTest.ts, then update the tests to cover these. think hard`（エッジケースを洗い出してテスト追加。**think hard**）
- `commit, push, pr`（コミット→プッシュ→PR を一気に）
- `Use 3 parallel agents to brainstorm ideas for how to clean up @services/aggregator/feed_service.cpp`（**3つの並列エージェント**でアイデア出し）

> `think hard` / `ultrathink` のような語で思考量を増やせる。並列エージェントの指示も自然言語でできる。

---

## 6. チームのツールを組み込む（Plug in your team's tools）

### bash ツールを教える
```
> Use the barley CLI to check for error logs in the last training run. Use -h to check how to use it.
```
→ 社内 CLI でも `-h`（ヘルプ）を読ませれば使い方を理解して使う。

### MCP ツールを教える
```
$ claude mcp add barley_server -- node myserver
> Use the barley MCP server to check for error logs in the last training run
```
→ MCP サーバーを登録すれば、外部システムをツールとして呼べる。

---

## 7. よくあるワークフロー（Common workflows）

| パターン | 内容 |
|---|---|
| **探索 → 計画 → 確認 → 実装 → コミット** | `Figure out the root cause for issue #983, then propose a few fixes. Let me choose an approach before you code. ultrathink` |
| **テスト → コミット → 実装 → 反復 → コミット**（TDD） | `Write tests for @utils/markdown.ts ...（まだ実装がないのでテストは通らない点に注意）→ commit → テストが通るようコードを更新` |
| **実装 → スクショ → 反復** | `Implement [mock.png]. Then screenshot it with Puppeteer and iterate till it looks like the mock.`（モック画像に近づくまで自己反復） |

> 共通するのは「**計画やテストを先に固定 → 実装 → 検証して反復**」という型。特に TDD では「先にコミットして基準を固定する」のがコツ。

---

## 8. コンテキストが多いほど性能が上がる（More context = better performance）

Claude はコンテキストが多いほど賢く動く。与え方は複数：

- **CLAUDE.md**
- **スラッシュコマンド**
- **`@` でのファイル名メンション**
- （近日対応: MCP リソース）

### CLAUDE.md の置き場所（自動で毎セッションに読み込まれる）
| 場所 | スコープ |
|---|---|
| `/<enterprise root>/CLAUDE.md` | 全プロジェクト共有 |
| `~/.claude/CLAUDE.md` | 全プロジェクト共有（自分用） |
| `project-root/CLAUDE.md` | プロジェクト共有（**git にコミットする**） |
| `project-root/CLAUDE.local.md` | コミットしない個人用 |

> ショートカット: **`#`** を打つとその場でメモ（memory）を CLAUDE.md に追記できる。

### オンデマンドでコンテキストを引き込む（スラッシュコマンド / `@`）
| 配置 | 呼び出し方 |
|---|---|
| `~/.claude/commands/foo.md` | `/user:foo` |
| `.claude/commands/foo.md` | `/project:foo` |
| `a/commands/foo.md` | `/project:a:foo` |
| ディレクトリ `a/` | `@a` |
| `a/foo.py` | `@a/foo.py` |

> `.claude/commands/` に `create-release-pr.md` / `fix-github-issue.md` / `lint.md` などを置くと、繰り返し手順をスラッシュコマンド化できる。

---

## 9. コンテキスト設計の心得（Tips）

- **Tip #5**: コンテキストを多く与えるほど Claude は賢くなる
- **Tip #6**: コンテキスト整備に時間をかける価値がある
  - それは **自分用か、チーム用か？**
  - **自動で読ませるか、必要時に遅延（lazy）で読ませるか？**

---

## 10. チームで共有する（Share with your team）

設定の種類ごとに「共有レベル」が異なる：

| | エンタープライズ方針（共有） | グローバル（自分のみ） | プロジェクト（共有） | プロジェクト（自分のみ） |
|---|---|---|---|---|
| **Memory** | `/Library/Application Support/ClaudeCode/CLAUDE.md` | `~/.claude/CLAUDE.md` | `CLAUDE.md` | `CLAUDE.local.md` |
| **スラッシュコマンド** | — | `~/.claude/commands/` | `.claude/commands/` | — |
| **権限（Permissions）** | `…/ClaudeCode/policies.json` | `~/.claude/settings.json` | `.claude/settings.json` | `.claude/settings.local.json` |
| **MCP サーバー** | — | `claude mcp` | `.mcp.json` | `claude mcp` |

> 「共有したいもの（コミット）」と「個人用（コミットしない）」を意識的に分ける。

---

## 11. 幕間: キーバインド（Keybindings）

| | キー | 動作 |
|---|---|---|
| 1 | **Shift+Tab** | 編集を自動承認（auto-accept edits） |
| 2 | **#** | メモ（memory）を作成 |
| 3 | **!** | bash モードに入る |
| 4 | **@** | ファイル / フォルダをコンテキストに追加 |
| 5 | **Esc** | キャンセル |
| 6 | **Double-Esc** | 履歴を遡る（`--resume` で再開） |
| 7 | **Ctrl+R** | 詳細出力（verbose） |
| 8 | **/vibe** | （遊び心のコマンド） |

---

## 12. Claude Code SDK

- **プログラムから低レベルに Claude Code を呼ぶための SDK**
- **CI / 非対話環境・自動化**、そして対話アプリの構築ブロックとして有用
- 現状は **CLI 対応**（TypeScript / Python SDK は近日）
- アーキテクチャ: `あなたのエージェントアプリ` → `Claude Code SDK` → `Anthropic / Bedrock / Vertex API` → `Claude モデル`

```bash
$ claude -p "what did I do this week?" \
  --allowedTools Bash(git log:*) \
  --output-format json
```

---

## 13. 幕間: Multi-claude（並列で複数の Claude を走らせる）

複数の Claude を同時に動かす方法はいくつもある：

1. **複数チェックアウト** を別々のターミナルタブで
2. **1つのチェックアウト + git worktrees**
3. **SSH + tmux**
4. **GitHub Actions** でジョブを並列起動

---

## 全体の要点（まとめ）

- Claude Code は **ターミナル発・汎用・ハック可能** な土台。既存ワークフローに組み込んで使う。
- 始め方は **「コードベースに質問」** が最も簡単（セットアップ不要・ローカル完結）。
- 真価は **ツール実行**（bash / ファイル操作 / Web / サブエージェント / MCP）にあり、「書く→検証する」まで自走する。
- 性能は **コンテキスト量** に比例 → `CLAUDE.md`・スラッシュコマンド・`@メンション` で整備する。整備対象が「自分用かチーム用か」「自動か遅延か」を区別する。
- ワークフローの型は **探索→計画→実装→検証→反復**（TDD やスクショ反復も同型）。
- スケールは **Multi-claude**（worktree / tmux / GitHub Actions）と **SDK**（CI・自動化）で。
