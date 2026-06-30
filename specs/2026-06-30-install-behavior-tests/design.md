---
id: 2026-06-30-install-behavior-tests
phase: design
status: approved
---

> 注: 検証ツーリング（テストハーネス）の新設。DDD/レイヤ語彙は該当範囲のみ honest に当てる。

## ドメインモデル（DDD）
ユビキタス言語:
- **被テストスクリプト（SUT）**: `install.sh`・`rollback.sh`。symlink 作成・バックアップ・復元という破壊的振る舞いを持つ。
- **隔離ホーム（sandbox HOME）**: テスト実行時に `HOME` として与える使い捨て一時ディレクトリ。実ホームの代役。**実環境を汚さない安全境界の実体**。
- **振る舞いケース**: 検証する4つの観測対象 = symlink 作成 / バックアップ退避 / ロールバック復元 / 冪等。各ケースは pass/fail を返す。
- **アサーション**: 「期待される観測」と「実際の観測」の一致判定。1つでも不一致ならテスト全体が fail。

## レイヤ構成（クリーンアーキテクチャ）
依存方向「起動点 → テストランナー → SUT（sourced）→ 隔離ホーム」の一方向。
- **infra / 起動点**: ①CI（`verify.sh` 経由）、②開発者の直接実行。どちらも単一のテストスクリプトを呼ぶだけ。
- **interface-adapter / テストランナー**: 新規 `tests/test-install.sh`。隔離ホームを用意し、SUT を **source して個別関数を呼び**、観測してアサートし、結果を集約して終了コードを返す。
- **SUT（被テスト・sourced）**: `install.sh`／`rollback.sh` の個別関数（`create_backup`/`create_symlinks`/`remove_symlinks`/`restore_backup`）。テストは main を起動しない（一括処理・パッケージインストールを走らせない）。
- **安全境界**: `HOME` を隔離ディレクトリに上書きしてから source。SUT 内の `$HOME` 参照・`BACKUP_DIR`（source 時に `$HOME` から算出）はすべて隔離ホームに向く。実ホーム・実パッケージには一切触れない。
依存ルール: 起動点（外）→ test-install.sh（内）→ SUT 関数。SUT はテストの存在を知らない。

## サービス境界 / 統合点
- 単一リポジトリ内のテスト追加。分割なし。
- 統合点: `verify.sh` に振る舞いテストのチェックを1つ追加（`tests/test-install.sh` を呼ぶ）。CI は `verify.sh` を呼ぶため CI ゲートに自動的に入る。pre-commit には**追加しない**（コミットを軽く保つ。CI と手動 verify が回帰検出ゲート）。
- SUT との契約: テストは SUT を **source（main ガードで main 不発火）** して関数単位で叩く。`install.sh` は既に `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi` を持つ。`rollback.sh` は持たないため**同じガードを追加**（これが唯一の本番スクリプト変更／通常の直接実行時の振る舞いは不変）。

## 主要な設計判断
- 判断: **隔離ホーム（一時ディレクトリを `HOME` として与える）に対して SUT 関数を実行** / 理由: requirement の最優先安全要件「実環境を汚さない」を構造的に保証。`$HOME` 上書きだけで SUT の全パスが隔離先に向く（SUT は `$HOME` 基準で書かれている）/ 却下案: 実ホームで dry-run フラグを足す → SUT に広範な改修が必要・誤爆リスク。コンテナ/VM → 重く CI 依存が増える。
- 判断: **SUT を source して個別関数を呼ぶ（main は走らせない）** / 理由: パッケージインストール（brew/mise/xcode、ネットワーク・権限・実環境）を避けつつ symlink/backup/restore の振る舞いだけを検証できる。requirement の out（パッケージ検証は対象外）に整合 / 却下案: `bash install.sh` を丸ごと実行 → brew 等が走り CI が重く・危険。環境変数で main 内を分岐 → main 改造が大きい。
- 判断: **`rollback.sh` に main ガードを追加（install.sh と同形）** / 理由: rollback.sh は末尾で無条件 `main "$@"` を実行しており source すると対話処理が走るため、テストから関数を隔離して呼べない。ガードは直接実行時の振る舞いを変えない（requirement 承認済みの最小調整）/ 却下案: rollback.sh を source せずサブプロセスで実行 → 対話 `read`/确認で詰まる、関数単位の観測ができない。
- 判断: **各ケースをサブシェルで実行（`( export HOME=...; source ...; 関数 )`）** / 理由: SUT の `set -e` とグローバル変数・`HOME` 上書きをケースごとに封じ込め、相互汚染を防ぐ / 却下案: 同一シェルで source → `set -e` がテストランナーを巻き込み、状態が漏れる。
- 判断: **テスト本体は依存ゼロの素の bash アサーション**（フレームワーク不使用）/ 理由: requirement「重いテスト依存を持ち込まない」。小さなヘルパ（`assert_symlink`/`assert_file` 等）で十分 / 却下案: bats 等の導入 → 新規依存・CI セットアップ増。
- 判断: **検証は代表的な symlink 部分集合＋backup＋restore＋冪等に絞る**（全26リンクを網羅しない）/ 理由: 振る舞いの回帰検出が目的で、列挙の完全性ではない。少数の代表で十分に回帰を捉える / 却下案: 全リンク網羅 → install.sh のリスト二重管理になり drift（#1/#2 で学んだ轍）。

## 既存コードへの影響（blast radius）
- **`rollback.sh`（変更・最小）**: 末尾 `main "$@"` を `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi` ガードで包む。直接実行時の挙動は不変。
- **`tests/test-install.sh`（新規）**: 振る舞いテスト本体。`tests/` ディレクトリも新規。`.sh` なので lint-shell.sh/shellcheck/pre-commit の対象に自動的に入る（自己被覆）。
- **`scripts/verify.sh`（変更）**: 振る舞いテストを呼ぶチェックを1つ追加。pass/fail/skip 集約は既存機構を再利用。
- **`install.sh`（無変更）**: 既に main ガードあり。source して関数を呼べる。
- 破壊的変更なし。利用者向けの直接実行（`./install.sh`・`./rollback.sh`）の挙動は不変。

## 受け入れ条件 → 設計 の対応表
| requirement の受け入れ条件 | それを満たす設計要素 |
| --- | --- |
| symlink が正しい対象を指して作成される | 隔離ホームで `create_symlinks` 実行 → 代表 symlink が `$DOTFILES_DIR/...` を指すことをアサート |
| 既存ファイルが上書き前に退避される | 隔離ホームに実ファイルを置き `create_backup` → バックアップ先にコピーが在ることをアサート |
| ロールバックが復元する | backup→create_symlinks 後に `remove_symlinks`＋`restore_backup` → 元の実ファイルに戻ることをアサート |
| 冪等（2回実行で壊れない） | `create_symlinks` を2回実行 → 2回目も成功し健全であることをアサート |
| 失敗で非0＋どの振る舞いか出力 | テストランナーがケース単位で pass/fail を集約、fail で非0＋ケース名出力 |
| 実環境を一切変更しない | `HOME` を一時ディレクトリに上書きしてから source。SUT の全 `$HOME` 参照が隔離先に向く |

## リスク / 未確定
- **source 時の `set -e` 伝播**: SUT は `set -e`。サブシェル隔離で封じるが、ケース実装時に各サブシェルが意図通り分離されているか実行で確認する。
- **`BASH_SOURCE`/`DOTFILES_DIR` の解決**: source 時 `DOTFILES_DIR` は SUT の位置（リポジトリ）に解決される（テストの位置ではない）。実行で確認。
- **隔離の完全性**: `create_symlinks` は `$HOME/.config/...` 等を作る。`HOME` 上書きで隔離先に向くはずだが、SUT が `$HOME` 以外の絶対パスや別の環境変数（XDG 等）を参照していないことを実装時に確認（現状の grep では `$HOME` 基準）。最優先の安全要件のため、テスト前後で実ホームの主要 symlink・`~/.dotfiles_backup` が不変であることもテスト内で確認する。
- **CI 実行**: `verify.sh` 経由で macOS ランナー実行。`create_symlinks` 内の `mkdir`/`ln`/`cp -R` は macOS で問題なし。実行時間は隔離ディレクトリ操作のみで軽量。
- **二重実行コスト**: verify.sh が増えるが小さい。pre-commit には入れないため commit は軽いまま。
- **スコープ外の既存負債（指摘のみ）**: `health-check` スキルの launchd 残存参照（既知）。本件無関係。
