---
id: 2026-06-30-precommit-shellcheck
phase: tasks
status: ready
---

## 実装タスク

- [x] T1: `.pre-commit-config.yaml` に `repo: local` のシェル静的検査フックを追加（`bash scripts/lint-shell.sh` を呼ぶ）
  - 触る場所: `.pre-commit-config.yaml`（design「infra/起動点②pre-commit」）
  - 内容: `repo: local` ブロックを追加し、`entry: bash scripts/lint-shell.sh`、`language: system`、`pass_filenames: false`、`always_run: true` のフックを1つ定義。既存フック群（pre-commit-hooks・gitleaks）は無変更。
  - 検証:
    - `pre-commit run <新フックid> --all-files` が成功（現状シェル12本クリーン）。
    - `pre-commit run --all-files` 全体が緑（既存フックと共存、新フックも実行される）。
    - `python3 -c "import yaml; yaml.safe_load(open('.pre-commit-config.yaml'))"` で YAML 妥当。
    - フックが呼ぶ実体が `scripts/lint-shell.sh`（＝CIが verify.sh 経由で呼ぶものと同一）であることを設定で確認。
  - 由来: design「local フックで lint-shell.sh を呼ぶ」「pass_filenames:false＋always_run」/ AC「コミット時にシェル静的検査を実行」「不備が無ければ成功」「pre-commit と CI で一貫」

- [x] T2: 受け入れ条件のエンドツーエンド検証（不備でコミット阻止・ツール不在で非黙殺・CIとの一貫性）。ネットでツリーは無変更に戻す
  - 触る場所: 検証専用の一時操作のみ（恒久変更なし）
  - 内容:
    - (a) シェルスクリプト1本に shellcheck が検知する不備を仕込み `git add` → `git commit` を試み、**コミットが成立せず**、どのスクリプトの何が問題か出力されることを確認 → 仕込みを戻す。
    - (b) `bin/tat`（拡張子なし）に不備を仕込んで同様にコミット阻止されることを確認（CIと同じ shebang 導出で被覆されている証拠）→ 戻す。
    - (c) shellcheck を一時的に PATH から外してフックを実行 → 黙って成功にならず非0＋メッセージになることを確認。
    - (d) 一貫性: 同じ不備に対し `pre-commit run <フックid> --all-files` と `bash scripts/lint-shell.sh`（CI実体）が同じく失敗することを確認。
  - 検証: (a)(b) でコミット不成立＋箇所提示、(c) ツール不在が明示、(d) 両者一致。最終 `git status`/`git log` がクリーン（余分なコミット・差分なし）。
  - 由来: requirement「検証方法」全項 / AC「不備でコミット失敗＋箇所提示」「ツール不在を黙殺しない」「一貫性」

## 実装順序の根拠
- T1 が唯一の実装（設定追加）。T2 はその受け入れ条件を実地観測する非破壊検証で、T1 完了後でなければ意味を成さない。
- 検査の実体（`lint-shell.sh`）は #1 で実装・検証済みのため本件で新規ロジックは無く、リスクは設定の配線に限定される。

## 完了の定義（DoD）
- requirement.md「検証方法」全項が観測できる（コミット時検査実行／不備でコミット阻止＋箇所提示／pre-commit と CI が同一不備を同じく検知／対象集合が CI と一致／ツール不在を黙殺しない）。
- `pre-commit run --all-files` が緑、`.pre-commit-config.yaml` の YAML 妥当、`bash scripts/verify.sh` が引き続き緑。
- 差分が `.pre-commit-config.yaml` に限定（`lint-shell.sh` ほか既存は無変更）。
- 関係する `tasks/lessons.md` の教訓に反していない。
