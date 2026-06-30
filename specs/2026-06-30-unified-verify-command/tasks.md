---
id: 2026-06-30-unified-verify-command
phase: tasks
status: ready
---

## 実装タスク

- [x] T1: `scripts/verify.sh` の骨格（オーケストレータ＋結果集約）を作り、常時実行の2チェック（shellcheck・pre-commit）を組み込む
  - 触る場所: `scripts/verify.sh`（新規 / design「interface-adapter / オーケストレータ」）
  - 内容: 冒頭でリポジトリルートに `cd`、環境検出（`${CI:-}` で local/ci）、`pass`/`fail`/`skip(理由)` を集約する仕組み、各チェックの結果を一覧表示するサマリ、`fail` が1つでもあれば非0・無ければ0 を返す終了ロジック。チェックとして (1) `scripts/lint-shell.sh` 呼び出し、(2) `pre-commit run --all-files` を組み込む。
  - 検証:
    - `bash scripts/verify.sh` が exit 0、サマリに shellcheck=pass・pre-commit=pass が表示される。
    - `(cd scripts && bash verify.sh)` でもルート基準で同じ結果（CWD固定の回帰防止）。
    - `shellcheck scripts/verify.sh` が緑（自己被覆。lint-shell.sh の対象にも入る）。
  - 由来: design「オーケストレータを単一スクリプトに集約」「結果集約・終了コード」「CWDルート固定」/ AC「単一コマンドで実行」「すべて成功で0終了」

- [x] T2: symlink健全性チェックを追加（dotfiles を指す壊れた symlink が無いこと）
  - 触る場所: `scripts/verify.sh`（design「symlink健全性」チェック）
  - 内容: HOME 配下の既知の場所にある symlink のうち、リンク先が dotfiles リポジトリ配下を指すものを列挙し、リンク先が存在しない（壊れている）ものがあれば `fail`。未インストール（対象 symlink が皆無）の場合は `skip(未インストール)`。固定の期待リスト再宣言はしない。
  - 検証:
    - 健全な環境で `bash scripts/verify.sh` の symlink チェックが `pass`（または未インストール環境で `skip(理由)` が明示）。
    - dotfiles を指す symlink を1つ一時的に壊す（リンク先を退避）→ symlink チェックが `fail`、全体が非0、サマリで symlink が落ちたと判別可能 → 復元すると `pass`。
  - 由来: design「symlink健全性=壊れリンク検出、固定リスト非宣言」/ AC「いずれか失敗で非0＋どれが失敗か出力」「ツール不在/不可を黙って成功扱いにしない」

- [x] T3: shell初期化健全性チェックを追加（local=フル `source`、ci/未インストール=構文チェックまたは `skip`）
  - 触る場所: `scripts/verify.sh`（design「shell初期化健全性」チェック）
  - 内容: `local` かつ `~/.zshrc` インストール済みなら非対話 `zsh` で `~/.zshrc` を読み込み exit 0 を確認。`ci` では zsh 構文チェックに縮退、または該当不可なら `skip(理由)`。いずれも結果を明示。
  - 検証:
    - ローカルで `bash scripts/verify.sh` の shell-init チェックが `pass`（インストール済み環境）、または `skip(未インストール)` が明示。
    - `CI=true bash scripts/verify.sh` で shell-init が ci 分岐（構文チェック or skip）になり、結果が明示される。
    - 全チェック健全時に全体 exit 0。
  - 由来: design「shell初期化 local=source/ci=構文チェック」「環境検出 `${CI:-}`」/ AC「CIとローカルで一致(環境差は明示)」「黙って成功扱いにしない」

- [x] T4: CI（`.github/workflows/main.yml`）を `scripts/verify.sh` 呼び出しに集約
  - 触る場所: `.github/workflows/main.yml`（design「infra/起動点」）
  - 内容: 現在の「Run gitleaks」「Shellcheck」の2ステップを、`pre-commit` の用意（インストール）＋ `bash scripts/verify.sh` 呼び出しに置換。gitleaks は pre-commit の gitleaks フック経由で存続。トリガー・`permissions` は不変。
  - 検証:
    - `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/main.yml'))"` で YAML 妥当。
    - `git diff` で変更が lint ジョブのステップに限定され、トリガー・権限が無変更。
    - ローカルで `CI=true bash scripts/verify.sh` を実行し、CI で走る内容（shellcheck＋pre-commit＋環境適応した symlink/shell-init）が緑であることを確認。
    - 実 CI（PR）で当該ジョブが pass し、pre-commit 経由で gitleaks が実行されている（カバレッジ退行なし）ことをログで確認。
  - 由来: design「CIは単一コマンドを呼ぶだけ」「gitleaks は pre-commit 経由で退行なし」/ AC「CIはローカルと同一の単一コマンドで実行」

- [x] T5: 受け入れ条件のエンドツーエンド検証（4チェック個別失敗・ツール不在の skip・後方互換）。ネットでツリーは無変更に戻す
  - 触る場所: 検証専用の一時操作のみ（恒久変更なし）
  - 内容:
    - (a) 4チェックそれぞれを1つずつ失敗させ（shell不備注入／pre-commit違反ファイル／symlink破壊／zshrc不備）、`bash scripts/verify.sh` が毎回非0で、サマリから「どのチェックが落ちたか」が判別できることを確認 → 各々復元。
    - (b) 検査ツールの1つを一時的に PATH から外して実行し、黙って成功にならず `skip(理由)` または明示エラーになることを確認。
    - (c) 後方互換: `bash scripts/lint-shell.sh` 単体、`pre-commit run --all-files` 単体が従来通り実行できることを確認。
  - 検証: (a) 各失敗で exit≠0＋判別可能。(b) ツール不在が明示。(c) 単体コマンド健在。最終 `git status` クリーン。
  - 由来: requirement「検証方法」全項 / AC 全条

## 実装順序の根拠
- T1 がオーケストレータの土台（結果集約・終了コード・環境検出）＋既存で確実に緑の2チェック。ここを独立で緑にしてから、T2・T3 でチェックを1つずつ足す（各追加後もツリー緑を保てる）。
- T4 はチェック群が出揃ってから CI に配線。T1–T3 完了前に配線すると CI が不完全なコマンドを呼ぶ。
- T5 は全実装後に受け入れ条件を実地観測する非破壊検証。コードを増やさず requirement「検証方法」を消化し、戻すのでツリー緑のまま。

## 完了の定義（DoD）
- requirement.md「検証方法」全項が観測できる（4チェック実行／個別失敗で非0＋判別可能／CI=ローカル同一コマンド／ツール不在を黙殺しない／後方互換）。
- `bash scripts/verify.sh` が健全環境で exit 0、`shellcheck scripts/verify.sh` 緑、`pre-commit run --all-files` 緑、`main.yml` の YAML 妥当。
- 実 CI（PR）で lint ジョブが pass し gitleaks が pre-commit 経由で実行されている。
- 差分が `scripts/verify.sh`（新規）と `.github/workflows/main.yml`（lint ジョブのステップ）に限定。既存の単体コマンド・スキルは無変更（後方互換）。
- 関係する `tasks/lessons.md` の教訓（CWD固定・shebang堅牢性等）に反していない。
