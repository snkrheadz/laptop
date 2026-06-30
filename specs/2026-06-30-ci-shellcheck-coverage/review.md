---
id: 2026-06-30-ci-shellcheck-coverage
phase: review
status: pass
---

> verdict: 初回 changes-requested(Blocker2/Minor2)。指摘4件すべて修正・実入力で再検証済み → pass。受け入れ条件4本も充足。

## 差し戻し後の修正と再検証（2回目）
| 指摘 | 修正 | 再検証(実入力) |
| --- | --- | --- |
| [Blocker] CWD非固定 | 冒頭で `cd "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"` | `scripts/` から実行しても **11本検出**(従来は5本)✅ |
| [Blocker] `env -S` 取りこぼし | env 後の `-` 始まりトークンをスキップしてから interp 取得 | `#!/usr/bin/env -S bash` → interp=`bash` で **検出される** ✅ |
| [Minor] BOM未除去 | CRLF除去後に `first=${first#$'\xef\xbb\xbf'}` | BOM前置 `#!` を除去後に認識 ✅ |
| [Minor] symlinkコメント不正確 | コメントを実挙動(`-f` は symlink を辿る)に訂正 | コメントのみ ✅ |
回帰: 通常実行 exit 0 / AC2 注入→exit1→復元exit0 / AC3 新規自動被覆 / self-shellcheck 緑 / pre-commit 緑 / git status クリーン。

---

> （初回レビュー記録 ↓）verdict: 受け入れ条件4本はすべて実観測で充足(pass)。ただし design のリスク欄が「取りこぼし不可」と明示した堅牢性項目に Major 2件のギャップがあり、差し戻す。

## 受け入れ条件の充足
| 受け入れ条件 | 状態 | 根拠（実際に観測したこと） |
| --- | --- | --- |
| CI起動時に全シェルスクリプト(hooks/statusline含む)を検査 | ✅ | `bash scripts/lint-shell.sh` が11本検査・exit 0。`git ls-files` 由来の自前導出リストと**差分ゼロ一致**。hooks2本・statusline・bin/tat すべて PRESENT |
| 不備があれば CI を失敗させる | ✅ | statusline に SC2086 を注入 → exit 1 で失敗 → 復元で exit 0 |
| 新規スクリプトを手動登録なしで対象化 | ✅ | 一時 `.sh`＋拡張子なし(`#!/usr/bin/env bash`)を追加 → スクリプト無改変で両方が対象に出現 → 削除で消滅 |
| 除外は明示的・レビュー可能に記録(必要時) | ✅ | `EXCLUDES=( )` 配列＋コメント＋`is_excluded()` の1箇所に集約、diff で追跡可能。現時点 除外なし(要件通り) |

## 設計との整合（eng:architecture-reviewer より）
- 依存方向 CI(infra)→検証スクリプト→shellcheck の一方向は正しく、抽象境界も妥当。CI は検証ロジックの詳細を持たず単一スクリプトを呼ぶだけ。
- ただし「ローカルとCIで同一手続き(parity)」の design 保証(design.md L15-16)が CWD 非固定により破れている(下記 Blocker)。
- design のリスク欄(design.md L49)が「引数付き shebang / BOM を取りこぼさないこと」と明示したが、env 引数付き(`env -S`)と BOM が未対応(下記)。

## 指摘（重大度順）
- [Blocker] CWD をリポジトリルートに固定していない — 場所: `scripts/lint-shell.sh:65-69` — `git ls-files` は実行時 CWD 相対でパスを出すため、`scripts/` 等のサブディレクトリから実行すると配下5本しか拾わず exit 0 で**サイレント過小スキャン**。design の local-CI parity 保証に違反。CI は checkout がルートに置くため無害だが、ローカル/将来の自動化が壊れる。直し方: スクリプト冒頭で `cd "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"`。
- [Blocker] `#!/usr/bin/env -S bash` を取りこぼす — 場所: `scripts/lint-shell.sh:50` — env の次トークンを無条件に interp とするため `-S` が interp になり case 不一致で除外。design が「引数付き shebang は取りこぼさない」と明記した契約ギャップ。現状そのような shebang を使うファイルは無いため latent。直し方: env の後の `-` 始まりトークンをスキップしてから interp を取る。
- [Minor] BOM を除去していない — 場所: `scripts/lint-shell.sh:43-44` — CRLF は除くが UTF-8 BOM 前置の `#!` を判定できず skip。design がリスクに挙げた項目。実害は極小。直し方: CRLF 除去後に `first="${first#$'\xef\xbb\xbf'}"`。
- [Minor] symlink に関するコメントが不正確 — 場所: `scripts/lint-shell.sh:66` — `[[ -f ]]` は symlink を辿るため「skip symlinks」は誤り。現リポジトリに追跡 symlink は無く実害なし。直し方: コメントを実挙動に合わせて訂正。

## 検証ログ
- `bash scripts/lint-shell.sh` → 11本検査・`all 11 script(s) passed.`・exit 0
- 不備注入(SC2086) → exit 1 / 復元 → exit 0
- 新規 `.sh`＋拡張子なし追加 → 両方自動被覆 / 削除 → 消滅
- `shellcheck scripts/lint-shell.sh` → exit 0(自己被覆)
- `pre-commit run --all-files` → 全7フック Passed
- `.github/workflows/main.yml` → YAML 妥当、Shellcheck ステップ = `bash scripts/lint-shell.sh`
- 後始末: 全一時変更を復元、最終 `git status` クリーン

## スコープ外で気づいた負債
- PostToolUse hook `validate-shell.sh` は `.sh` のみ検査するため `bin/tat` 編集時に発火しない(別バックログ。design リスク欄に既記)。本件では無変更。
