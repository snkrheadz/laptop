# spec 駆動開発パイプライン

このディレクトリは **spec 駆動パイプライン**の成果物（各案件の仕様書）が置かれる場所です。
このドキュメントは、その入口となる `/spec-*` コマンド群の使い方を人間向けにまとめたものです。

コマンド本体は `claude/commands/spec-*.md`（`~/.claude/commands/` にシンボリックリンク）にあり、
Claude Code のスラッシュコマンドとして実行します。

---

## 何のための仕組みか

「思いつき」から「マージ可能な変更」までを、**各段階で人間が承認するゲート**を挟みながら
小さく確実に進めるための一連のコマンドです。背景にあるのは Spotify の Niklas Gustavsson が
語った原則 —— **「検証(verification)こそ最も投資不足のレバーであり、一貫性がエージェントの
性能を決める」**。このパイプラインは、その規律（観測可能な受け入れ条件・各段の検証・隔離
コンテキストでの批判的レビュー）をどのリポジトリにも持ち込める形にしたものです。

各コマンドは **1つのフェーズだけ**を実行し、必ず**人間のゲートで止まります**。
勝手に次へ進みません。あなたが内容をレビューし、承認して初めて次のコマンドを実行します。

---

## 全体の流れ

```text
        ┌─ あなたの一言 / リポジトリの課題
        │
/spec-scan          ← (任意) リポジトリを監査し、ROI順に「やるべき intent」を提案
        │  → specs/<日付>-scan/scan.md
        ▼
/spec-requirement   ← intent を「観測可能な受け入れ条件(EARS)」を持つ要件に
        │  → specs/<id>/requirement.md     ……… Gate ①（人間が承認）
        ▼
/spec-design        ← 要件を設計(DDD/クリーンアーキ/サービス境界)に
        │  → specs/<id>/design.md          ……… Gate ②（人間が承認）
        ▼
/spec-tasks         ← 設計を「各々検証可能な順序付きタスク」に分解
        │  → specs/<id>/tasks.md
        ▼
/implement-with-notes ← 実装（タスクを順に。各タスクは検証行を持つ）
        │
/spec-review        ← 隔離コンテキストの subagent が diff を批判的にレビュー
        │  → specs/<id>/review.md          ……… Gate ③（pass なら次へ）
        ▼
/eng:create-pr      ← base を同期して PR 作成（マージは人間）
```

各コマンドは実行の最後に「次に打つべきコマンド」を必ず表示します。迷ったら出力の最終行を見てください。

---

## コマンド一覧

| コマンド | 役割 | 入力 | 生成物 | 止まる場所 |
| --- | --- | --- | --- | --- |
| `/spec-scan [path]` | リポジトリの agent-readiness を監査し、ROI順の intent バックログを提案 | リポジトリ（省略時カレント） | `scan.md` | スキャン完了で停止 |
| `/spec-requirement "<intent>"` | 一言の意図を、観測可能な受け入れ条件を持つ要件に | intent 文字列 or intent.md パス | `requirement.md` | **Gate ①** |
| `/spec-design <id>` | 承認済み要件を設計に | spec id | `design.md` | **Gate ②** |
| `/spec-tasks <id>` | 承認済み設計を順序付きタスクに分解 | spec id | `tasks.md` | 実装準備完了で停止 |
| `/spec-review <id>` | 実装 diff を隔離 subagent で批判的レビュー | spec id | `review.md` | **Gate ③** |

> `<id>` は `specs/` 配下のディレクトリ名（例: `2026-06-30-unified-verify-command`）です。
> `/spec-requirement` が intent から日付付きの id を自動採番してディレクトリを作ります。

---

## 人間のゲート（重要）

このパイプラインの肝は、**各仕様書の YAML フロントマターにある `status` を人間が書き換えること**で
承認を表す点です。コマンドは承認済みかどうかを `status` で判定し、未承認なら次フェーズの実行を拒否します。

| ゲート | ファイル | 承認のしかた |
| --- | --- | --- |
| Gate ① | `requirement.md` | 内容をレビューし `status: awaiting-human-gate-1` → `status: approved` に編集 |
| Gate ② | `design.md` | 内容をレビューし `status: awaiting-human-gate-2` → `status: approved` に編集 |
| Gate ③ | `review.md` | `status: pass` なら PR へ。`changes-requested` なら Blocker を実装に差し戻す |

承認は「読んで納得したらフロントマターを 1 行書き換える」だけです。納得できなければ、その場で
要件・設計を直すよう指示してください（前のフェーズに戻ってよい）。

---

## 使い方の例

### 例 A: 思いついた変更を流す

```text
/spec-requirement "コミット前に shellcheck を走らせて、CI まで行かずにシェル不備を弾きたい"
  → specs/2026-06-30-precommit-shellcheck/requirement.md を生成、Gate ① で停止

# requirement.md を読み、OK なら status: approved に書き換える
/spec-design 2026-06-30-precommit-shellcheck
  → design.md を生成、Gate ② で停止

# design.md を読み、OK なら status: approved に書き換える
/spec-tasks 2026-06-30-precommit-shellcheck
  → tasks.md を生成

/implement-with-notes specs/2026-06-30-precommit-shellcheck/tasks.md
  → 実装（各タスクの「検証」行を実際に走らせて緑を確認）

/spec-review 2026-06-30-precommit-shellcheck
  → review.md を生成。status: pass を確認

/eng:create-pr
  → PR 作成（マージは人間が GitHub で）
```

### 例 B: 何をやるべきか分からない → まずスキャン

```text
/spec-scan
  → scan.md に「テスト自動化 / 検証ループ / 標準化・一貫性」の3軸スコアカードと、
     ROI順の intent バックログが出る

# バックログから着手する一行を選び、そのまま requirement へ
/spec-requirement "<scan.md のバックログ#1 の intent をそのまま>"
  → 以降は例 A と同じ
```

---

## 生成物の構造

1 案件 = `specs/<id>/` ディレクトリ。フェーズが進むごとにファイルが増えます。

```text
specs/2026-06-30-unified-verify-command/
├── intent.md        # （あれば）元の一言を verbatim 保存
├── requirement.md   # 背景 / スコープ / 受け入れ条件(EARS) / 検証方法   ← Gate ①
├── design.md        # ドメインモデル / レイヤ / 設計判断 / 受け入れ条件↔設計 対応表  ← Gate ②
├── tasks.md         # 順序付きタスク。各タスクに「触る場所 / 検証 / 由来」
└── review.md        # 受け入れ条件の充足 / 指摘(重大度順) / 検証ログ   ← Gate ③
```

`scan.md` は案件横断の監査結果として `specs/<日付>-scan/scan.md` に置かれます。
これらの仕様書は実装と一緒にコミットされ、「なぜこの変更をこう作ったか」の記録として残ります。

---

## 設計上の約束（なぜこの形か）

- **1コマンド = 1フェーズ。** 各コマンドは自分の領分だけを書き、必ずゲートで止まる。altitude（抽象度）を混ぜない
  （要件にクラス名を書かない、設計にコードを書かない、等）。
- **受け入れ条件は必ず観測可能。** 「どう検証するか」を言えないものは要件として認めない（requirement の「検証方法」）。
- **タスクは1つずつ検証可能。** 各タスクは「検証」行を持ち、ツリーを常に緑に保つ順序で並べる。
- **レビューは隔離コンテキストで批判的に。** `/spec-review` は実装者の文脈に引きずられないよう、別 subagent に
  diff を読ませて受け入れ条件を**実際に走らせて**確認する（形式承認にしない）。
- **マージは人間。** パイプラインは PR 作成まで。マージの最終判断は人が行う。

---

## よくある操作

- **途中でやり直したい:** 該当フェーズのコマンドを再実行すれば仕様書を上書き再生成できます（前段の承認は保持）。
- **要件が間違っていた:** design 以降で気づいたら、requirement に戻って直し、再承認してから進めます。
- **並列で複数案件:** 案件ごとに git worktree を分けると干渉しません。
- **レビューで Blocker:** `review.md` が `changes-requested` のときは、Blocker を実装フェーズに差し戻して直し、
  再度 `/spec-review` を回します。

---

関連: リポジトリ全体の検証は `scripts/verify.sh`（shellcheck / pre-commit / gitleaks / symlink / shell-init /
install 振る舞いテストを1コマンドで実行。CI と同一）。spec の各タスクの「検証」もこれらを使います。
