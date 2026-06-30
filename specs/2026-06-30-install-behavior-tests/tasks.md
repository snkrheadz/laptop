---
id: 2026-06-30-install-behavior-tests
phase: tasks
status: ready
---

## 実装タスク

- [x] T1: `rollback.sh` に main ガードを追加（source 時に main を走らせない）
  - 触る場所: `rollback.sh`（design「rollback.sh に main ガードを追加」）
  - 内容: 末尾の無条件 `main "$@"` を `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi` で包む（install.sh と同形）。他は無変更。
  - 検証:
    - `source rollback.sh` しても main が走らない（対話/処理が起きない）ことを、隔離シェルで関数定義のみ読み込めることで確認。
    - 直接実行時の挙動が不変であること（ガードの真偽が直接実行で真）を確認。
    - `shellcheck rollback.sh` 緑、`bash scripts/verify.sh` 緑。
  - 由来: design「SUT を source して個別関数を呼ぶ」「rollback.sh ガード追加（直接実行は不変）」/ AC「ロールバックが復元する」の前提

- [x] T2: `tests/test-install.sh` の骨格＋安全境界＋symlink 作成ケースを作る
  - 触る場所: `tests/test-install.sh`（新規 / design「テストランナー」）。`tests/` 新規ディレクトリ。
  - 内容: 冒頭でリポジトリルートに `cd`。アサートヘルパ（`assert_symlink`/`assert_file`/`fail`）と結果集約（pass/fail＋ケース名、fail で非0）。各ケースをサブシェルで実行し `HOME` を `mktemp -d` の隔離ディレクトリに上書きしてから `install.sh` を source。最初のケースとして「`create_symlinks` 実行 → 代表 symlink（例: `.zshrc`/`.gitconfig`/`.tmux.conf`）が `$DOTFILES_DIR/...` の正しい対象を指す」をアサート。テスト終了時に隔離ディレクトリを必ず削除。
  - 検証:
    - `bash tests/test-install.sh` が exit 0、symlink ケースが pass 表示。
    - `(cd tests && bash test-install.sh)` でもルート基準で同結果（CWD固定）。
    - 実行前後で**実ホームの主要 symlink・`~/.dotfiles_backup` が不変**（テスト外から `ls -la ~/.zshrc` 等を前後比較）。
    - `shellcheck tests/test-install.sh` 緑。
  - 由来: design「隔離ホーム」「source して関数を呼ぶ」「サブシェル隔離」「依存ゼロのアサーション」/ AC「symlink が正しい対象を指す」「実環境を変更しない」「失敗で非0＋ケース名」

- [x] T3: backup・rollback 復元・冪等の3ケースを追加
  - 触る場所: `tests/test-install.sh`（design「振る舞いケース」）
  - 内容:
    - backup: 隔離ホームに実ファイル（非 symlink）を置き `create_backup` → バックアップ先にコピーが存在することをアサート。
    - rollback 復元: backup→`create_symlinks`（実ファイルが symlink に置換）→ `remove_symlinks`＋`restore_backup "$backup_dir"` → 元の実ファイル内容に戻ることをアサート（rollback.sh を source して関数使用）。
    - 冪等: `create_symlinks` を2回実行 → 2回目も成功し symlink が健全であることをアサート。
  - 検証:
    - `bash tests/test-install.sh` が全4ケース pass、exit 0。
    - 実行前後で実ホームが不変（T2 と同じ前後比較）。
  - 由来: design 対応表（backup/rollback/冪等）/ AC「既存ファイルが退避」「ロールバックが復元」「冪等」

- [x] T4: `scripts/verify.sh` に振る舞いテストのチェックを追加（CI ゲート入り）
  - 触る場所: `scripts/verify.sh`（design「verify.sh にチェック追加」）
  - 内容: `tests/test-install.sh` を呼ぶチェック関数を1つ追加し、pass/fail/skip 集約に組み込む（テスト不在/未実行を黙殺しない）。pre-commit には追加しない。
  - 検証:
    - `bash scripts/verify.sh` のサマリに install-tests（仮称）が pass 表示、全体 exit 0。
    - `CI=true bash scripts/verify.sh` でも当該チェックが実行され緑。
    - `git diff` で変更が verify.sh のチェック追加に限定。
  - 由来: design「統合点: verify.sh に1チェック追加 → CI ゲート」/ AC「ローカルと CI の双方で実行可能」

- [x] T5: 受け入れ条件のエンドツーエンド検証（回帰検出・安全性・CI）。ネットでツリーは無変更に戻す
  - 触る場所: 検証専用の一時操作のみ（恒久変更なし）
  - 内容:
    - (a) `create_symlinks` の symlink を1つ張らない回帰を一時的に仕込み（または被テスト側を一時改変）、`bash tests/test-install.sh` が**失敗（非0）し、どのケースが落ちたか**出力されることを確認 → 戻す。
    - (b) 安全性: テスト1回実行の前後で、実ホームの主要 symlink と `~/.dotfiles_backup` の状態が完全に同一であることを確認。
    - (c) CI 経路: `CI=true bash scripts/verify.sh` が install-tests を含め緑であることを確認。
  - 検証: (a) 回帰で非0＋ケース判別、(b) 実ホーム不変、(c) verify 緑。最終 `git status` クリーン。
  - 由来: requirement「検証方法」全項 / AC「失敗で非0＋判別可能」「実環境を変更しない」

## 実装順序の根拠
- T1（rollback ガード）が T3 の rollback ケースの前提（source 可能化）。先に入れる。
- T2 でハーネスの土台＋安全境界＋1ケースを緑にしてから、T3 で残りケースを足す（各追加後もツリー緑）。
- T4 はテストが出揃ってから verify/CI に配線。T5 は全実装後の非破壊な受け入れ観測。

## 完了の定義（DoD）
- requirement.md「検証方法」全項が観測できる（4ケース実行／回帰で非0＋ケース判別／実行前後で実ホーム不変／単一コマンドでローカル・CI 実行可能）。
- `bash tests/test-install.sh` が exit 0、`bash scripts/verify.sh` が緑、`shellcheck`（lint-shell.sh 経由）が新規 .sh を含め緑、`pre-commit run --all-files` 緑。
- 差分が `rollback.sh`（main ガードのみ）・`tests/test-install.sh`（新規）・`scripts/verify.sh`（チェック追加）に限定。`install.sh` は無変更。利用者向け直接実行の挙動は不変。
- 実環境（実ホーム・実パッケージ）への副作用が無い（最優先安全要件）。
- 関係する `tasks/lessons.md` の教訓（CWD固定等）に反していない。
