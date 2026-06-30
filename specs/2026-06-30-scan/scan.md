---
id: 2026-06-30-scan
phase: scan
agent_ready: yes
---

> verdict: 検証サブストレートは存在しエージェントは自分で検証できる(agent-ready)。ただし最大のレバーは「検証ハーネス自身が CI で検証されていない穴」— hooks/statusline が CI の shellcheck 対象外。

## 検証サブストレート（エージェントが自分で叩けるコマンド）
| 種別 | コマンド | 有無 | CIと一致 |
| --- | --- | --- | --- |
| test | （振る舞いテストなし。静的検査が代替） | ⚠️ なし | — |
| lint/format | `shellcheck <files>` / `pre-commit run --all-files` | ✅ | ⚠️ 一部のみ |
| type-check | （シェル中心のため対象外） | — | — |
| build | （ビルド成果物なし。`./install.sh` が適用） | — | — |
| CI | `.github/workflows/main.yml`（gitleaks + shellcheck） | ✅ | ⚠️ shellcheck 対象が `install.sh rollback.sh scripts/*.sh` に限定 |

## スコアカード（Honk 3本柱 / 各 0–5）
| 柱 | スコア | 根拠（codegraph / 実コマンドで観測したこと） |
| --- | --- | --- |
| A テストの自動化 | 2 | 全 .sh が shellcheck 緑（実測 exit 0）。だが install/rollback/symlink の**振る舞い**を検証する自動テストは皆無。health-check は自動テストでなく手動 skill。 |
| B 検証の仕組み(closed-loop) | 3 | shellcheck・pre-commit・health-check はエージェントが自分で叩ける（=gate通過）。しかし (1) verify を束ねる単一エントリポイントが無く手順を毎回推測、(2) CI の shellcheck が10本中6本のみ。CI対象外の4本のうち2本は `claude/hooks/`（検証ハーネス自身）。 |
| C 標準化・一貫性 | 4 | shebang は10本すべて `#!/bin/bash` で統一。ディレクトリ構成は CLAUDE.md に明文化、symlink は `safe_ln()` に集約。一貫性は高い。 |

## ROI順 仕様バックログ
各行はそのまま `/spec-requirement "<intent>"` に流せる一言。
| # | intent（一言） | impact | effort | ROI | 由来した柱 |
| --- | --- | --- | --- | --- |
| 1 | CI が hooks と statusline を shellcheck しておらず、検証ハーネス自身の不備を検知できない | high | low | ★★★ | B |
| 2 | 検証一式(zshrc読込・shellcheck・pre-commit・health-check)を束ねる単一の verify コマンドが無く、エージェントが検証手順を毎回推測している | high | low | ★★★ | B |
| 3 | pre-commit が shellcheck を含まず、commit 時点でシェルスクリプトの不備を検知できない | med | low | ★★ | B/A |
| 4 | install.sh / rollback.sh / symlink の振る舞いを検証する自動テストが無く、回帰を観測できない | high | med | ★★ | A |

## エージェント自律化を阻む最大要因
**検証ハーネス自身が検証されていない。** CI の shellcheck 対象は `install.sh rollback.sh scripts/*.sh` に限定され、`claude/hooks/verify-git-on-stop.sh`・`claude/hooks/validate-shell.sh`・`claude/statusline.sh`・`.claude/hooks/validate-zenn-md.sh` の4本が抜けている。このうち hooks 2本は、エージェントの作業全体が依存している安全網そのもの。ここが壊れても CI は緑のまま通り、検証の検証に穴が開く — Niklas の「検証こそ最も投資不足のレバー」がこの repo にそのまま当てはまる箇所。まず #1 で CI 対象を全 .sh に広げ、#2 で verify を単一コマンドに束ねれば、エージェントが「壊れていないこと」を毎回確実に観測できるようになる。

## スコープ外で気づいた負債
- `launchd-manage` skill は非推奨/廃止だが残存（CLAUDE.md に記載済み）。掃除候補だが今回の検証レディネスとは無関係。
- 振る舞いテスト不在(柱A)は dotfiles の性質上ある程度は許容範囲。ただし install/rollback は破壊的操作を含むため、#4 の優先度は環境次第で上がる。
