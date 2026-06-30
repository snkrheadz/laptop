---
id: 2026-06-30-install-behavior-tests
phase: review
status: pass
---

> verdict: 初回 changes-requested(Blocker3/Medium1/Low2)。Blocker・Medium 計4件を修正し再検証 → pass。実装中に rollback の実害バグ(dotfiles 復元不可)も検出・修正済み。AC1–AC6 充足、実ホーム無傷。

## 受け入れ条件の充足
| 受け入れ条件 | 状態 | 根拠（実観測 / レビュー） |
| --- | --- | --- |
| symlink が正しい対象を指して作成 | ✅ | 隔離HOMEで create_symlinks → .zshrc/.gitconfig/.tmux.conf が repo を指す |
| 既存ファイルが上書き前に退避 | ✅ | 実ファイルを置き create_backup → バックアップに原本内容 |
| ロールバックが復元 | ✅ | backup→symlink化→remove+restore → 原本の実ファイルに復帰。**偽陽性ガード追加後も真に検証** |
| 冪等(2回実行) | ✅ | create_symlinks 2連で rc 0・symlink 健全 |
| 失敗で非0＋どの振る舞いか出力 | ✅ | 回帰注入で exit 1＋該当ケース FAIL を実観測 |
| 【最優先】実環境を一切変更しない | ✅ | 検証 subagent が実ホームのハッシュ前後一致・backup件数不変を独立確認。temp も修正後リークなし |

## 設計との整合（eng:architecture-reviewer より）
- 隔離境界は構造的に正しい(コールグラフ追跡済み): 全パスは `$HOME/...` 経由、絶対パス/外部コマンド(brew/mise/launchctl)・XDG は main 内のみで main ガードにより不発火。`BACKUP_DIR`/`LAUNCHD_PLIST` も source 時に隔離HOMEへ解決。
- 依存方向(起動点→test→SUT関数)一方向、verify.sh 統合も妥当。

## 指摘（重大度順）と対応
| 指摘 | 重大度 | 対応 | 再検証 |
| --- | --- | --- | --- |
| `case_rollback` 偽陽性: setup の exit code 未捕捉＋中間状態未確認で、symlink化されなくても pass しうる | Blocker | rc 確認＋「.zshrc が symlink になった」「backup dir が存在」の中間アサーション追加 | symlink化しない回帰で `[FAIL] rollback setup did not symlink .zshrc` を確認 ✅ |
| ケース1–3の setup subshell の exit code を破棄 | Blocker | 各 setup に `rc=$?` 確認を追加(失敗で fail＋return) | 全ケースで rc チェック動作 ✅ |
| temp 残骸リーク: `mkhome` をコマンド置換で呼び `TMPDIRS+=()` がサブシェル内更新→trap が空配列で何も消さない | Blocker | 親シェルで単一 `TEST_ROOT` を作成→trap で一括削除、mkhome はその配下に subdir | 実行前後で TMPDIR の残骸 52→52(差0)、修正前残骸52件も掃除 ✅ |
| `restore_backup` の `shopt -u dotglob` 無条件解除が呼び出し元設定を壊しうる | Medium | ループを subshell で囲み shopt をスコープ内に限定(shopt -u 不要に) | shellcheck 緑・rollback ケース緑 ✅ |
| subshell 出力を /dev/null 破棄で失敗診断が弱い | Low(opinion) | rc 確認の fail メッセージで「どのフェーズが落ちたか」は判別可能化。全文ログ化は見送り(複雑化回避) | — |
| real_home_fingerprint の確認対象が少数 | Low(opinion) | 中核(.zshrc/.gitconfig の symlink＋backup)で十分。検証 subagent が別途ハッシュで広く確認。見送り | — |

## 実装中に検出・修正した実害バグ（スコープ承認の上で対応）
- **rollback.sh の復元バグ**: `restore_backup` が `for f in "$backup_dir"/*` でループするが通常グロブは dotfiles を無視 → バックアップ対象(全て .zshrc 等)を一切復元できず **rollback が no-op** だった。dotglob 有効化で修正。振る舞いテストが初回実行で検出。

## 検証ログ
- `bash tests/test-install.sh` → 7 passed / 0 failed、exit 0。`scripts/` 相当でも CWD 固定で同結果。
- 回帰注入(symlink行無効化) → exit 1＋該当ケース FAIL。復元で 0。
- temp リーク: 実行前後 52→52(差0)。
- 実ホーム: 検証 subagent がハッシュ前後一致・backup 21→21 で無傷確認。
- `shellcheck tests/test-install.sh` / `rollback.sh` 緑。`bash scripts/verify.sh` local/ci とも 6 pass/0 fail。

## スコープ外で気づいた負債
- `health-check` スキルの launchd 残存参照(既知)。本件無関係。
- Low指摘2件(診断ログ・fingerprint 拡充)は将来の改善候補として記録。
