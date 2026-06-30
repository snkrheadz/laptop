---
id: 2026-06-30-precommit-shellcheck
phase: design
status: approved
---

> 注: ドメインアプリではなく検証ツーリングの構成変更。DDD/レイヤ語彙は該当範囲のみ honest に当てる。本件は既存の `scripts/lint-shell.sh`（#1）を pre-commit から呼ぶだけの薄い統合。

## ドメインモデル（DDD）
ユビキタス言語のみ:
- **シェル静的検査（検査単位）**: リポジトリのシェルスクリプト集合に shellcheck を適用し合否を返す手続き。実体は既存 `scripts/lint-shell.sh`（対象を `git ls-files` × `.sh`/shebang で導出）。
- **コミット前検査（pre-commit）**: コミット時に複数フックを実行するゲート。本件はそこに「シェル静的検査」フックを1つ追加する。
- **検査対象集合**: `lint-shell.sh` が導出する集合（CIと同一）。pre-commit も CI もこの単一の実体を通すため判定が一致する。

## レイヤ構成（クリーンアーキテクチャ）
依存方向は「起動点 → 検査手続き → 外部ツール」の一方向（外→内）。
- **infra / 起動点（2つ・対等）**: ①CI（`verify.sh` 経由で `lint-shell.sh` を呼ぶ）、②pre-commit（新規 local フックで `lint-shell.sh` を呼ぶ）。どちらも検査ロジックを持たず同じ実体を呼ぶだけ。
- **interface-adapter / 検査手続き**: 既存 `scripts/lint-shell.sh`（**唯一の対象判定＋shellcheck 実行の所在**）。本件で無変更。
- **外部ツール**: `shellcheck`（既存依存）。
依存ルール: 起動点（外）→ lint-shell.sh（内）→ shellcheck。逆依存なし。pre-commit と CI が同一の内側実体を共有することで「判定の一貫性」を構造で担保。

## サービス境界 / 統合点
- 単一リポジトリ内のツーリング統合。分割なし。
- 統合点: pre-commit 設定 → `lint-shell.sh`。CI も（verify.sh 経由で）同じ `lint-shell.sh` を呼ぶため、**同一スクリプトを共有することがコミット前検査と CI の判定一致の根拠**（受け入れ条件「一貫性」）。
- 既存の pre-commit フック（空白・YAML・秘密情報等）とは独立した追加フック。相互に干渉しない。

## 主要な設計判断
- 判断: **pre-commit の `local` フックとして `bash scripts/lint-shell.sh` を呼ぶ**（検査の実体を再実装しない）/ 理由: CI と同一スクリプトを共有 → 対象集合・判定が必然的に一致（一貫性を構造で担保）。#1 で作った資産の再利用 / 却下案: pre-commit 公式の shellcheck フック（`shellcheck-py` 等の別 repo フック）を追加 → 対象決定が pre-commit 側の `files` パターン依存になり CI（`lint-shell.sh` の shebang 導出）と乖離し得る。`bin/tat`（拡張子なし）の扱いも別管理になる。新規依存も増える。
- 判断: **`pass_filenames: false` ＋ `always_run: true`（リポジトリ全体検査）** / 理由: requirement 確定事項「検査対象はリポジトリ全体」。`lint-shell.sh` は自分で対象を導出するため、pre-commit が渡す変更ファイル名は不要。always_run で doc のみのコミットでも全体整合を保証 / 却下案: `files: \.sh$` ＋ 変更ファイルのみ → `bin/tat`（拡張子なし）を取りこぼし、CI と検査範囲が乖離（一貫性違反）。`lint-shell.sh` は引数を無視するため渡す意味もない。
- 判断: **ツール不在時の扱いは `lint-shell.sh` 既存挙動に委ねる**（shellcheck が無ければ非0＋メッセージ）/ 理由: requirement「黙って成功扱いにしない」を既存ロジックがすでに満たす。pre-commit フックはその非0をそのままコミット失敗に伝える / 却下案: フック側で握り潰す → 要件違反。

## 既存コードへの影響（blast radius）
- **`.pre-commit-config.yaml`（変更）**: `repo: local` ブロックを1つ追加し、`bash scripts/lint-shell.sh` を呼ぶフックを定義。既存フック（pre-commit-hooks 群・gitleaks）は無変更。
- **影響を受けないが関連**: `scripts/lint-shell.sh`（再利用・無変更）、`scripts/verify.sh`（CI 経路、無変更。verify は pre-commit 全体を別途呼ぶが二重実行は許容＝後述リスク）、`.github/workflows/main.yml`（無変更）。
- 破壊的変更なし。現状シェル全12本が shellcheck 緑（既確認）のため、フック追加で既存コミットフローに新たな失敗は出ない。
- 注意（自己整合）: 本 PR では `.pre-commit-config.yaml` の変更自体が pre-commit（check-yaml 等）で検査される。

## 受け入れ条件 → 設計 の対応表
| requirement の受け入れ条件 | それを満たす設計要素 |
| --- | --- |
| コミット時にシェル静的検査を実行 | pre-commit に `lint-shell.sh` を呼ぶ local フックを追加（always_run） |
| 不備でコミット失敗＋箇所提示 | `lint-shell.sh` が非0＋shellcheck の指摘（ファイル・行）を出力 → pre-commit がコミットを阻止 |
| 不備が無ければ成功 | `lint-shell.sh` が exit 0 → フック成功 |
| ツール不在を黙って成功扱いにしない | `lint-shell.sh` の既存挙動（shellcheck 不在で非0＋メッセージ）をフックがそのまま伝播 |
| pre-commit と CI で同じ不備を同じく検知（一貫性） | 両者が同一 `lint-shell.sh`（同一対象導出・同一 shellcheck）を呼ぶ |

## リスク / 未確定
- **二重実行**: `verify.sh` は pre-commit 全体（このフック含む）と `lint-shell.sh` を別々に呼ぶため、`verify.sh` 実行時に shellcheck が2回走る。リポジトリが小さく実害は無視できるが、重複は認識しておく（最適化は本件スコープ外）。
- **always_run の副作用**: シェルに無関係なコミットでもフックが走る。小規模ゆえ許容。重くなれば対象を絞る余地あり（将来）。
- **フック未インストール環境**: `pre-commit install` をしていないクローンではコミット時にフックが走らない。これは pre-commit 全般の前提であり本件固有ではない（CI が最終ゲートとして残る）。リスクとして明記。
- **検査内容は不変**: 既存 shellcheck の判定をコミット前段階に持ち込むのみ。ルール追加・変更はしない（requirement スコープ out）。
