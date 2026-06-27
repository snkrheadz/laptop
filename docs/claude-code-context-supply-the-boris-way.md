# Claude Code: コンテキスト供給の流儀（The Boris Way）

> 出典の起点: Boris Cherny *Practical Tips on How to use Claude Code*（https://www.youtube.com/watch?v=M8HuXu_bOco）
> 関連: [`claude-code-practical-tips-boris-cherny.md`](./claude-code-practical-tips-boris-cherny.md)
>
> 本書の目的: Boris は「**rules（禁止/許可ルール）で縛る**」のではなく「**コンテキストを供給して賢くする**」流儀でClaude Code を運用している。その流儀を**自分（運用者）が同じように初期化・運用できる土台**として落とし込む。

---

## 0. 大前提 — rules ではなく context

Boris の世界観は一行で言える：

> **More context = better performance.**（コンテキストが多いほど性能が上がる）

だから彼は「ルールを書く」ことに時間を使わない。代わりに「**どのコンテキストを・誰に・いつ（自動 or オンデマンド）届けるか**」を設計する。これが本書の全て。

- ❌ rules を増やして Claude を制約する（静的・禁止ベース・マイクロマネジメント）
- ✅ context を供給して Claude を賢くする（動的・知識/手続きベース・設計）

> 自分のグローバル `CLAUDE.md` 冒頭の *「モデルが既にうまくやれることは意図的に繰り返さない。足すのはマイクロマネジメント」* は、この原則の実装そのもの。**この姿勢を全部品に広げる**のが本書のゴール。

---

## 1. Boris の4チャネルと2軸

コンテキストを供給する手段は4つ。それぞれを **2軸**（自動 or オンデマンド / 自分用 or チーム用）で位置づけるのが Boris の Tip #6。

| チャネル | 供給タイミング | 何を入れるか |
|---|---|---|
| **CLAUDE.md** | 自動（毎セッション） | プロジェクトの知識・bashコマンド・ファイル地図・スタイル規約 |
| **スラッシュコマンド** (`.claude/commands/*.md`) | オンデマンド（`/...` で呼ぶ） | 繰り返す手続き（リリースPR作成・issue修正・lint等） |
| **`@` メンション** | オンデマンド（その場で） | 必要なファイル/フォルダだけを遅延（lazy）で引き込む |
| **`#` メモ** | 自動に育てる | 会話中に気づいた知識をその場で CLAUDE.md に追記 |

### 2軸での判断
- **自動 か オンデマンド か** → 「毎回必要」なら CLAUDE.md（自動）、「時々必要」なら コマンド/@（オンデマンド）。CLAUDE.md を肥大させない。
- **自分用 か チーム用 か** → 配置場所で共有範囲が決まる（→ §4の配置表）。

---

## 2. 「ゼロから初期化する」How（Boris のやり方）

新しいプロジェクト／環境でコンテキストを立ち上げる手順。**最小から始めて、使いながら育てる**のが要点。

### Step 1. CLAUDE.md を生成する（土台の核）
- `/init` で叩き台を作る、または手書きで開始。
- 入れるのは「**Claude が毎回知っておくべきこと**」だけ：
  - よく使う bash コマンド（ビルド・テスト・lint・デプロイ）
  - 主要ファイル/ディレクトリの地図（どこに何があるか）
  - プロジェクト固有のスタイル規約・命名・禁則の「**理由**」
- ❌ 一般論（「テストを書け」「綺麗に書け」）は書かない。モデルは既に知っている。

### Step 2. `#` で育てる（運用しながら追記）
- 会話中に「これは毎回必要だ」と気づいたら **`#`** を打ってその場で CLAUDE.md に追記。
- CLAUDE.md は**書き切るものではなく、運用で太らせる**もの。

### Step 3. 繰り返す手続きをスラッシュコマンド化する
- 同じ指示を2回書いたら `.claude/commands/foo.md` に切り出す → `/project:foo` で再利用。
- 例: `create-release-pr.md` / `fix-github-issue.md` / `lint.md` / `get-feedback.md`。
- これで CLAUDE.md を汚さずに「手続き」をオンデマンド供給できる。

### Step 4. `@` で遅延供給する
- 作業のたびに必要なファイルだけ `@app/services/Foo.ts` で引き込む。
- 「全部を CLAUDE.md に書く」のではなく「**その場で指す**」。コンテキスト窓を節約しつつ精度を上げる。

### Step 5. ツールを教える（bash / MCP）
- 社内CLIは `Use the barley CLI ... Use -h to check how to use it` のように**ヘルプを読ませて**使わせる。
- 恒常的に使う外部システムは `claude mcp add ...` で MCP ツール化。

> **初期化の鉄則**: 「最初に完璧な CLAUDE.md を書く」のではなく、**最小で始めて `#` とコマンド切り出しで育てる**。これが Boris のやり方。

---

## 3. あなたが同じことをできる土台（テンプレ）

### 3-1. プロジェクト `CLAUDE.md` の骨格テンプレ
```markdown
# <プロジェクト名>

## Overview
（このリポジトリは何か、1〜3行）

## Commands
（毎回使う bash。build / test / lint / deploy など実際に動くものだけ）

## Architecture / File map
（どこに何があるか。Claude が迷わないための地図）

## Conventions（理由つき）
（プロジェクト固有の規約。「なぜそうするか」を書く。一般論は書かない）
```

### 3-2. スラッシュコマンドの骨格テンプレ（`.claude/commands/<name>.md`）
```markdown
# <コマンドがやること1行>

手順:
1. ...
2. ...

注意: $ARGUMENTS を使えば引数を受け取れる
```

### 3-3. 「初期化チェックリスト」
新しいプロジェクトに入ったら上から実行：

- [ ] `CLAUDE.md` を最小で作成（Overview / Commands / File map のみで可）
- [ ] よく使う bash を 3〜5個だけ Commands に書く
- [ ] スタイル規約は「理由つき」で、本当に必要なものだけ
- [ ] 2回書いた指示は `.claude/commands/` に切り出す
- [ ] 恒常利用する外部システムを `claude mcp add` で登録
- [ ] 共有したいものは commit、個人用は `CLAUDE.local.md` / `*.local.json` に分離
- [ ] 運用開始後は `#` で随時追記して育てる

---

## 4. 配置表 — 「誰に届けるか」を場所で決める

| | エンタープライズ（共有） | グローバル（自分のみ） | プロジェクト（共有） | プロジェクト（自分のみ） |
|---|---|---|---|---|
| **Memory** | `/Library/Application Support/ClaudeCode/CLAUDE.md` | `~/.claude/CLAUDE.md` | `CLAUDE.md` | `CLAUDE.local.md` |
| **スラッシュコマンド** | — | `~/.claude/commands/` | `.claude/commands/` | — |
| **権限** | `…/ClaudeCode/policies.json` | `~/.claude/settings.json` | `.claude/settings.json` | `.claude/settings.local.json` |
| **MCP サーバー** | — | `claude mcp` | `.mcp.json` | `claude mcp` |

> 判断: 「チームに効かせたい」→ 左寄り＆commit、「自分だけ」→ 右寄り＆commitしない。

---

## 5. 境界の再設計 — 「自分の設定」と「配布する土台」を分ける

Boris は**土台を渡す側（プロダクト設計者）**。同じ視点に立つには、`claude/` を役割で二分する。

| 層 | 置き場所 | 性格 | 判断基準 |
|---|---|---|---|
| **自分の運用設定** | `claude/`（この dotfiles） | 個人依存・絶対パスOK | 他人のマシンでは無意味／自分専用 |
| **配布する土台** | `snkrheadz/claude-skills`（marketplace） | 汎用・オプトイン・hackable | **他人のマシンでそのまま動き、価値があるか？** |

### 振り分けルール（一行判定）
> **「他人が `/plugin install` してそのまま価値が出るか？」が Yes → marketplace、No → dotfiles に留める。**

### governance 機構は廃止する（コンテキスト供給へ一本化）
`governance-proposer` / `rule-auditor` / `governance-review` / `rule-history` / `governance/` は「**ルールを統治・監査する仕組み**」＝ §0 の原則と逆行する。Boris 視点では異物なので**廃止**し、その役割をコンテキスト供給に置き換える：

| 旧（rules 統治） | 新（context 供給） |
|---|---|
| failure を検知して rule を提案・監査 | 学びは `#` で CLAUDE.md / `lessons.md` に追記 |
| rule の鮮度を audit する skill | CLAUDE.md を運用で育て、不要記述は手で削る |
| governance ログを蓄積 | 繰り返す手続きは slash command に切り出す |

> ※ 実際の削除は本書のスコープ外（境界の再設計まで）。廃止対象と移行先を確定したので、次アクションとして安全に撤去できる。

---

## 6. まとめ — Boris の視点を自分のものにする

1. **rules を足す前に context を疑う** — 「ルールが要る」と感じたら、それは CLAUDE.md / コマンド / @ で供給できないか考える。
2. **最小で始めて運用で育てる** — 完璧な初期設定を目指さない。`#` とコマンド切り出しが育成エンジン。
3. **2軸で配置する** — 自動 or オンデマンド / 自分 or チーム。場所が共有範囲を決める。
4. **設定と土台を分ける** — 他人マシンで価値が出るものだけ marketplace へ。残りは dotfiles。
5. **統治より供給** — governance を廃し、学びはコンテキストとして還元する。

> Boris は「使い方を押し付けない土台」を作った。あなたが同じ視点に立つとは、**自分の `claude/` を「自分専用の最適化」から「誰でも土台にできる供給設計」へ開く**こと。
