---
id: 2026-06-30-precommit-shellcheck
phase: review
status: pass
---

> verdict: eng:architecture-reviewer が APPROVE(Blockerなし)。受け入れ条件は実装フェーズ T2 で実地検証済み。auto-stash×git ls-files の相互作用も詳細検証され正しいことを確認 → pass。

## 受け入れ条件の充足
| 受け入れ条件 | 状態 | 根拠（実際に観測したこと / レビュー確認） |
| --- | --- | --- |
| コミット時にシェル静的検査を実行 | ✅ | `repo: local` フック(always_run)が `lint-shell.sh` を実行。新フック単体・全体とも pre-commit 緑 |
| 不備でコミット失敗＋箇所提示 | ✅ | .sh に不備注入→`git commit` 阻止、shellcheck 指摘出力。HEAD 不変 |
| 不備が無ければ成功 | ✅ | 現状12本クリーンでフック Passed |
| ツール不在を黙って成功扱いにしない | ✅ | shellcheck を PATH 除外→`lint-shell.sh` が exit 1 + "shellcheck is not installed" → コミット阻止 |
| pre-commit と CI で同じ不備を同じく検知（一貫性） | ✅ | 両者が同一 `lint-shell.sh` を呼ぶ(構造的担保)。同一不備で `pre-commit run` と `lint-shell.sh` が共に exit 1 |
| 検査対象が CI と一致(bin/tat 含む) | ✅ | `bin/tat`(拡張子なし)に不備注入でもコミット阻止 = shebang 導出で被覆 |

## 設計との整合（eng:architecture-reviewer より）
- 依存方向(起動点→lint-shell.sh→shellcheck)一方向で妥当。design の全判断を実装が忠実に反映。
- `language: system`/`pass_filenames: false`/`always_run: true` は意図通り(doc のみコミットでも全体検査)。CWD は pre-commit のルート実行＋`lint-shell.sh` の自己アンカーで二重保護。
- **auto-stash 検証**: pre-commit は `git stash --keep-index` 後にフックを実行するため、`lint-shell.sh` の `git ls-files`＋`-f` は「実際にコミットされる状態」を忠実にスキャン。部分ステージ/削除/拡張子なし(ケースA–E)いずれも誤検知・見逃しなし。`pre-commit run --all-files`(CI/verify) では stash 非発動で作業ツリー全体を検査=用途として適切。
- 一貫性は `lint-shell.sh` 共有という構造で担保され、検査対象の乖離は発生しない。

## 指摘（重大度順）
- 指摘なし（Blocker/Major なし）。
- [Minor / 既存・本PR起因でない] `scripts/verify.sh:46-50` は shellcheck 未インストール時に SKIP で早期リターンし、SKIP は失敗に計上されない。shellcheck と pre-commit が**両方**不在の環境で `verify.sh` を手動実行すると exit 0 になる(「黙殺しない」のカバレッジ穴)。これは #2 由来の既存挙動で、本PRはむしろ pre-commit 経路でこのカバレッジを強化する副作用を持つ。スコープ外のため本PRでは修正しない(下記負債に記録)。

## 検証ログ
- `pre-commit run shellcheck-all --all-files` Passed / `pre-commit run --all-files` 全フック緑
- `.pre-commit-config.yaml` YAML 妥当
- 不備注入(.sh / bin/tat)→`git commit` 阻止、HEAD 不変
- shellcheck 不在→exit 1 + メッセージ
- 一貫性: `pre-commit run` と `lint-shell.sh` が同一不備で共に exit 1
- 閉じゲート `bash scripts/verify.sh` exit 0

## スコープ外で気づいた負債
- `verify.sh` の shellcheck+pre-commit 両不在時の silent exit 0(上記 Minor)。将来 `check_shellcheck` の SKIP 条件を見直す小修正の候補。
- `health-check` スキルの launchd 残存参照(既知・別件)。
