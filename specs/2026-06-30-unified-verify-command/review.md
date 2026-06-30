---
id: 2026-06-30-unified-verify-command
phase: review
status: pass
---

> verdict: 初回 changes-requested(Blocker1/Major2/Minor3)。全6件を修正し実入力で再検証 → pass。受け入れ条件 AC1–AC5＋後方互換＋自己被覆も実観測で充足。

## 受け入れ条件の充足
| 受け入れ条件 | 状態 | 根拠（実際に観測したこと） |
| --- | --- | --- |
| 単一コマンドで全種を実行 | ✅ | `bash scripts/verify.sh` が shellcheck/pre-commit/gitleaks/symlink/shell-init の5セクションを実行、サマリ表示 |
| いずれか失敗で非0＋どれが失敗か出力 | ✅ | 各チェックを個別に失敗させ毎回 exit 1、サマリで該当チェックが FAIL と判別可能（shellcheck/pre-commit/gitleaks/symlink/shell-init すべて確認） |
| すべて成功で0終了 | ✅ | 健全状態で `→ 5 pass / 0 fail / 0 skip`、exit 0 |
| CIはローカルと同一の単一コマンドで実行 | ✅ | `main.yml` が `bash scripts/verify.sh` を呼ぶだけ。`CI=true`/`GITHUB_ACTIONS` で env=ci 分岐、shell-init が `zsh -n` に縮退 |
| ツール不在を黙って成功扱いにしない | ✅ | shellcheck を PATH から外すと `SKIP — 未インストール`。skip は fail に計上せず明示 |

## 設計との整合（eng:architecture-reviewer より）
- 依存方向 起動点→オーケストレータ→各チェック→外部ツール は一方向で妥当。PASS/FAIL/SKIP の3状態集約・終了コードも design 通り。
- ただし design の「gitleaks は pre-commit 経由で退行なし」という前提が **誤り**だったことが判明（下記 Blocker）。pre-commit の gitleaks フックは `protect --staged` モードで、CIの fresh checkout（staged 差分ゼロ）では0ファイル検査になる。実装で明示的な `gitleaks detect` を追加して是正。
- symlink の固定 roots が design の「固定リスト非宣言」原則に反していた（下記 Major）。find 導出に変更して是正。

## 指摘（重大度順）と対応
| 指摘 | 重大度 | 対応 | 再検証(実入力) |
| --- | --- | --- | --- |
| pre-commit の gitleaks は `protect --staged` で CI では秘密情報を実質スキャンしない（requirement「秘密情報スキャンを変えない」違反） | **Blocker** | `gitleaks detect --source=. --no-git` を verify の明示チェックとして追加、CI に gitleaks を再インストール | 未stageの秘密鍵を置く→pre-commitは Passed だが gitleaks detect は `leaks found: 1`→verify が FAIL gitleaks・exit 1。復元で exit 0 ✅ |
| symlink の hardcoded roots は design 禁止の「固定リスト」の別形態（install.sh 追加時に drift） | Major | roots 配列を廃し `find`（HOME 直下＋`~/.config`・`~/.claude` 再帰）で導出 | find 導出が固定rootsでは見えなかった孤立リンク2本(`~/.config/alacritty/*`)を新規検出。除去後 26本健全 PASS ✅ |
| `$HOME/.zsh` root は dead code（配下に dotfiles を指す symlink 無し） | Major | find 導出化で roots ごと廃止、`~/.zsh` symlink 自体は HOME 直下走査で被覆 | symlink チェック全体が PASS、被覆漏れなし ✅ |
| CI の `zsh -n` エラー内容を `/dev/null` 破棄 | Minor | `2>&1` 捕捉しエラー本文を出力 | 構文エラー注入時に該当ファイル＋内容を表示 ✅ |
| `zsh -c "source $HOME/.zshrc"` の word-split リスク＋二重実行 | Minor | `zsh -c 'source "$1"' -- "$HOME/.zshrc"` に変更、出力を単一実行で捕捉 | shell-init PASS、二重実行解消 ✅ |
| `${CI:-}` 単独の環境検出は偽陽性抑制なし | Minor | `GITHUB_ACTIONS` も判定に追加 | `CI=true` 単独でも ci 判定維持（後方互換）✅ |

## 検証ログ
- 健全状態: 5 pass / 0 fail / 0 skip、exit 0。`scripts/` からでも exit 0（CWD固定）。
- 個別失敗: shellcheck(SC不備)/pre-commit(private key)/gitleaks(秘密鍵)/symlink(壊れリンク)/shell-init(CI構文エラー) すべて exit 1＋判別可能。
- ツール不在: shellcheck を PATH 除外で `SKIP — 未インストール`（黙殺なし）。
- env: `CI=true` で env=ci、shell-init→`zsh -n`。
- 自己被覆: `shellcheck scripts/verify.sh` 緑。後始末: 全一時変更復元、最終 git status はコミット対象差分のみ。
- 副産物: 実環境の孤立 symlink を計3本検出・除去（`~/.myclirc`、`~/.config/alacritty/{alacritty,alacritty.toml}`）。

## スコープ外で気づいた負債
- `health-check` スキルが廃止済み launchd auto-sync を参照（CLAUDE.md は廃止記載）。本件では無変更。
- `~/.config/alacritty/themes` は実ディレクトリとして残存（壊れリンクではない、対象外）。
