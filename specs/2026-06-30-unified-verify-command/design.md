---
id: 2026-06-30-unified-verify-command
phase: design
status: approved
---

> 注: ドメインアプリではなく検証ツーリングの統合。DDD/レイヤ語彙は該当範囲のみ honest に当てる。

## ドメインモデル（DDD）
ユビキタス言語のみ:
- **チェック（Check）**: 単独で合否を返す検証単位。本件で束ねる4種 = `shellcheck` / `pre-commit` / `symlink健全性` / `shell初期化健全性`。
- **チェック結果（CheckResult）**: `pass` / `fail` / `skip(理由付き)` の値オブジェクト。`skip` は「環境により実行不可」を**明示的に**表す（黙殺禁止 = 受け入れ条件「黙って成功扱いにしない」）。
- **検証ラン（VerifyRun）**: 全チェックを実行し、結果を集約する。1つでも `fail` があれば全体 `fail`（非0）、なければ `pass`（0）。`skip` は全体合否に影響しない（成功でも失敗でもない第3状態）。
- **実行環境（Environment）**: `local` / `ci`。各チェックの実行可否を決める。

## レイヤ構成（クリーンアーキテクチャ）
依存方向は「起動点 → オーケストレータ → 各チェック → 外部ツール」の一方向（外→内）。
- **infra / 起動点**: CI（`.github/workflows/main.yml`）と人間/エージェントのシェル。どちらも**単一コマンドを呼ぶだけ**で、チェックの中身を知らない。
- **interface-adapter / オーケストレータ**: 新規 `scripts/verify.sh`。環境を検出し、4チェックを順に実行、結果を集約し、サマリを出力、終了コードを決める。**検証手順の唯一の所在**。
- **各チェック（手続き）**:
  - shellcheck → 既存 `scripts/lint-shell.sh` を呼ぶ（再実装しない）。
  - pre-commit → `pre-commit run --all-files`（gitleaks 等の既存フックを内包）。
  - symlink健全性 → dotfiles リポジトリを指す symlink に壊れたものが無いか。
  - shell初期化健全性 → `local` では `zsh` で `~/.zshrc` を読み込み exit 0 を確認、`ci` では zsh 構文チェックに限定。
- **外部ツール**: `shellcheck` / `pre-commit` / `zsh`（いずれも既存依存。新規導入なし）。
依存ルール: 起動点（外）→ verify.sh（内）→ 各ツール。逆依存なし。

## サービス境界 / 統合点
- 単一リポジトリ内のツーリング統合。分割なし（モノリポのまま正しい）。
- 統合点: ①CI → `scripts/verify.sh`、②ローカルシェル → 同 `scripts/verify.sh`。**同一スクリプトを通すことで CI とローカルの検査内容一致を構造的に担保**（受け入れ条件「CIとローカルで一致」）。環境差は verify.sh 内の環境検出で吸収し、CIで実行不可な項目は `skip(理由)` として明示。
- **既存スキル・既存単体コマンドとの境界**: `health-check` 等のスキルは対話的入口として不変で残す（後方互換）。`lint-shell.sh`・`pre-commit`・`shellcheck` の単体実行も従来通り可能。verify.sh はそれらを**呼ぶだけ**で置き換えない。

## 主要な設計判断
- 判断: **`scripts/verify.sh` を新規オーケストレータ**とし、CI もローカルもこれを呼ぶ / 理由: 検証手順の所在が1箇所に集まり、CI・ローカル一致を構造で担保。requirement の確定事項（`scripts/` 慣習・タスクランナー不採用）に一致 / 却下案: `make verify`（Makefile 新規＝慣習外の追加）、zsh エイリアス（CIから呼べず一致が崩れる）。
- 判断: **環境検出で各チェックの実行可否を切り替え、CIで不可な項目は `skip(理由)` を明示**。環境判定は `${CI:-}`（GitHub Actions が `CI=true` を設定）を一次情報とする / 理由: requirement「ローカルのみフル検証」「黙って成功扱いにしない」を同時に満たす / 却下案: CIでも全項目強制実行 → symlink 未インストールの CI で恒常 fail。CIで該当項目を単に無視 → 黙殺になり要件違反。
- 判断: **symlink健全性は「dotfiles を指す壊れた symlink が無いこと」を検査**（期待リンクの固定リストを再宣言しない） / 理由: 正典の symlink 対象は `install.sh` が保持しており、verify 側に固定リストを持つと二重管理で drift する。壊れリンク検出なら drift せず、CLAUDE.md の閉じゲート「no broken symlinks」とも一致 / 却下案: 期待リンク一覧を verify に再掲 → install.sh と乖離する負債を生む（リスク欄に限界を明記）。
- 判断: **shell初期化は local=フル `source`、ci=構文チェック** / 理由: `~/.zshrc` は個人環境（oh-my-zsh 等）依存で CI に無いため。両環境で「実行可能な最大限」を行い、差は `skip`/縮退として明示 / 却下案: CI用の最小 zsh 環境を構築 → CI が複雑・不安定化（requirement 確定で却下済み）。
- 判断: **verify.sh 冒頭でリポジトリルートに `cd`**（直前 PR の lint-shell.sh で得た教訓）/ 理由: サブディレクトリ起動でのサイレント縮退を防ぐ / 却下案: CWD 非固定 → 同じ過小実行バグの再発。

## 既存コードへの影響（blast radius）
- **`scripts/verify.sh`（新規）**: オーケストレータ。`scripts/*.sh` に属し、自身も shellcheck チェック対象（lint-shell.sh 経由）に入る。
- **`.github/workflows/main.yml`（変更）**: 現在の「gitleaks 単体ステップ + Shellcheck ステップ」を、`scripts/verify.sh` 呼び出しに集約。gitleaks は pre-commit の gitleaks フック経由で引き続き実行されるため**カバレッジは退行しない**（むしろ pre-commit の他フックも CI で走るようになり増える）。<!-- ⚠️ 訂正(review で判明): pre-commit の gitleaks は `protect --staged` モードで CI(staged 差分ゼロ)では実質スキャンしない。退行する。実装では `gitleaks detect --no-git` を verify の明示チェックとして追加して是正。詳細は review.md 参照。 -->CI に `pre-commit` の用意（インストール）が必要 ← pre-commit は既存の dev 依存（`.pre-commit-config.yaml`・CLAUDE.md 記載）であり新規依存ではない。トリガー・`permissions` は不変。
- **影響を受けないが関連**: `scripts/lint-shell.sh`（verify から呼ばれる、無変更）、`health-check` スキル（対話的入口として不変）、`install.sh`（symlink の正典、無変更）、各単体検査コマンド（後方互換、無変更）。
- 破壊的変更: 利用者向けには無し（従来コマンドは全て生存）。CI の内部構成のみ変化。

## 受け入れ条件 → 設計 の対応表
| requirement の受け入れ条件 | それを満たす設計要素 |
| --- | --- |
| 単一コマンドで4種すべてを実行 | `scripts/verify.sh` が4チェックを順次実行（shellcheck=lint-shell.sh / pre-commit / symlink / shell-init） |
| いずれか失敗で非0＋どれが失敗か出力 | VerifyRun が結果集約、`fail` があれば非0、サマリで各チェックの pass/fail/skip を表示 |
| すべて成功で0終了 | `fail` ゼロなら exit 0 |
| CIはローカルと同一の単一コマンドで実行 | `main.yml` が `scripts/verify.sh` を呼ぶだけ。環境差は verify.sh 内で吸収 |
| ツール不在を黙って成功扱いにしない | CheckResult に `skip(理由)` 第3状態。環境/ツール不在は `skip` として明示出力（成功にしない） |

## リスク / 未確定
- **symlink 検査の限界**: 「壊れリンクが無い」検査は drift しない代わり、「本来あるべきリンクが未作成」は検出しない。これは install.sh が作成の正典であることで許容（検出強化は別途）。リスクとして明記。
- **CI の pre-commit 実行時間/安定性**: pre-commit が全フック（gitleaks 含む）を走らせるため、CI 時間が現状より増える可能性。フックは既存のものに限り、新規追加はしない。実装時に CI が緑かつ実用時間内であることを実 CI で確認する（requirement の検証方法に対応）。
- **環境検出の頑健性**: `${CI:-}` 依存。ローカルで誤って `CI` がセットされていると縮退実行になる。実装時、`local`/`ci` 双方の分岐を実際に動かして確認する。
- **shell初期化チェックの個人環境依存**: ローカルでも利用者の `~/.zshrc` が未インストール（symlink 前）の場合は `skip(未インストール)` とし fail にしない。インストール済み環境でのみフル検証。
- **スコープ外の既存負債（指摘のみ・無変更）**: `health-check` スキルが廃止済みの launchd auto-sync を参照している（CLAUDE.md は launchd 廃止を記載）。本件では触らない。
