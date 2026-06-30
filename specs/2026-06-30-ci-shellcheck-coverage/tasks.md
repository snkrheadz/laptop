---
id: 2026-06-30-ci-shellcheck-coverage
phase: tasks
status: ready
---

## 実装タスク

- [x] T1: 対象列挙 + shellcheck 実行スクリプト `scripts/lint-shell.sh` を新規作成
  - 触る場所: `scripts/lint-shell.sh`（新規 / design「interface-adapter / 検証手続き」）
  - 内容: `git ls-files` を母集合に「拡張子 `.sh` OR シェル shebang（`sh`/`bash`/`dash`/`ksh`、`#!/usr/bin/env` 経由含む。`zsh` は除外）」で対象を動的導出し、`shellcheck` に渡し、1件でも指摘があれば終了コード非0。除外指定の口（現時点は空）を明示コメント付きで1箇所用意。
  - 検証:
    - `bash scripts/lint-shell.sh` が終了コード 0（現状10本すべてクリーンの実測前提）。
    - スクリプトが列挙した対象一覧が、`git ls-files` 由来の全シェルスクリプト10本（9本 `.sh` + `bin/tat`）と**差分ゼロ**で一致（`claude/hooks/*`・`claude/statusline.sh`・`bin/tat` が含まれること）。
    - `shellcheck scripts/lint-shell.sh` が緑（自己被覆）。
  - 由来: design「対象列挙を専用スクリプトに集約」「`.sh` OR shebang ハイブリッド」「母集合 `git ls-files`」「zsh 除外」/ AC「全シェルスクリプトを検査」「新規を手動登録なしで対象化」「除外は明示的・レビュー可能」

- [x] T2: CI（`.github/workflows/main.yml`）の Shellcheck ステップをハードコードリストから `scripts/lint-shell.sh` 呼び出しへ置換
  - 触る場所: `.github/workflows/main.yml`（Shellcheck ステップのみ / design「infra / 起動点」）
  - 内容: `shellcheck install.sh rollback.sh scripts/*.sh` を `bash scripts/lint-shell.sh`（相当）に置換。gitleaks ステップ・トリガー・`permissions`・ツールインストールは不変。
  - 検証:
    - `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/main.yml'))"`（または pre-commit の check-yaml）で YAML が妥当。
    - 差分が Shellcheck ステップに限定され、gitleaks ステップ・トリガーが無変更であることを `git diff` で目視確認。
    - ローカルで `bash scripts/lint-shell.sh` を実行し、CI が走らせる内容とローカルが同一手続き（同一スクリプト）であることを確認。
  - 由来: design「CI 定義は検証ロジックの詳細を持たず単一スクリプトを呼ぶだけ」「依存方向 外→内」/ AC「CI 起動時に全シェルスクリプトを検査」「CIとローカルの一致」

- [x] T3: 受け入れ条件のエンドツーエンド検証（不備注入→失敗、新規追加→自動被覆）。ネットでツリーは無変更に戻す
  - 触る場所: 検証専用の一時操作のみ（恒久的なファイル変更なし）
  - 内容:
    - (a) `claude/hooks/` か `claude/statusline.sh` のいずれかに shellcheck が検知する不備を1つ仕込み、`bash scripts/lint-shell.sh` が**非0で失敗**することを確認 → 仕込みを戻す。
    - (b) 一時的なシェルスクリプト（`.sh` 1本＋拡張子なし shebang 1本）を追加し、`scripts/lint-shell.sh` の対象リストへ**手動登録なしで自動的に**現れることを確認 → 一時ファイルを削除。
  - 検証: (a) で exit≠0、戻すと exit 0。(b) で一時2本が対象一覧に出現、削除後に消える。最終的に `git status` がクリーン（T1/T2 の成果物以外の差分なし）。
  - 由来: requirement「検証方法」全項 / AC「不備があれば CI を失敗させる」「新規を手動登録なしで対象化」

## 実装順序の根拠
- T1 が検証の中核（対象判定）。T2 はそれを CI に配線するだけなので T1 に依存する。先に T1 を独立で緑にしてから T2 で配線すると、各段階でツリーが緑に保たれる（T1 完了時点でローカル検証可能、T2 完了時点で CI 経路が完成）。
- T3 は T1・T2 完了後に受け入れ条件を実地で観測する非破壊の検証。コードを増やさずに requirement の「検証方法」を消化し、戻すのでツリーは緑のまま。

## 完了の定義（DoD）
- requirement.md の「検証方法」4項すべてが観測できる（差分ゼロ照合 / 不備注入で CI 失敗 / 新規自動被覆 / 除外の明示性）。
- `bash scripts/lint-shell.sh` が exit 0、`shellcheck scripts/lint-shell.sh` 緑、`pre-commit run --all-files` 緑、check-yaml 通過。
- 差分が `scripts/lint-shell.sh`（新規）と `.github/workflows/main.yml`（Shellcheck ステップのみ）に限定され、破壊的変更なし。
- 関係する `tasks/lessons.md` の教訓に反していない。
