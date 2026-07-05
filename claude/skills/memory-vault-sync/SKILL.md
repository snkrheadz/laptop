---
name: memory-vault-sync
description: Claude Code の自動メモリ (~/.claude/projects/*/memory/) を棚卸しし、普遍的な知見だけを Obsidian vault (Memories) に昇格させる。削除は提案のみ。トリガー: メモリ棚卸し, memory sync, メモリ同期, obsidian昇格, vault sync
---

# Memory → Obsidian Vault 棚卸し（昇格モデル）

Vault: `/Users/snkrheadz/Documents/obsidian/Memories`

## 原則

- **移動ではなく昇格**: Claude Code のメモリは稼働中セッションが読む運用データ。
  vault へは「複数プロジェクトをまたいで通用する知見」だけをコピーし、
  ソースは削除候補として提案するに留める。
- **削除は提案のみ**: ユーザー承認なしにソースメモリを消さない。
- **冪等**: 昇格ノートの frontmatter に `source_memory:`（元の絶対パス）を持たせる。
  再実行時は vault を grep して既昇格分をスキップ（元が更新されていれば上書き）。

## 手順

1. **走査**: `ls ~/.claude/projects/*/memory/*.md`（`MEMORY.md` は index なので対象外）。
   プロジェクトが多い場合はプロジェクト単位でサブエージェント（`model: "sonnet"`）に
   分類だけ委譲してよい。vault への書き込みは必ずメインが行う。
2. **各メモリを4分類**:
   - **陳腐化**（言及するファイル・機能・URLが消えている、事実が変わった）→ 削除候補
   - **repo が既に記録**（CLAUDE.md / README / git history で再導出可能）→ 削除候補
   - **プロジェクト固有で現役** → 何もしない（vault に置かない）
   - **普遍的な知見・原則・リファレンス** → 昇格
3. **昇格先**（メモリの `type` 別）:
   - `user` / `feedback` → `Principles/`（重複しやすいので既存ノートへの統合を優先）
   - `project`（完了済みプロジェクトの知見）→ `Projects/<project-name>.md`
   - `reference` → `References/`
4. **昇格ノートの形式**: 元 frontmatter を保持し、以下を追加:
   ```yaml
   source_memory: /Users/snkrheadz/.claude/projects/<...>/memory/<file>.md
   promoted: <YYYY-MM-DD>
   ```
   `[[wikilink]]` はリンク先も昇格済みならそのまま、未昇格なら平文に落とす。
5. **記録**: vault 直下の `Sync Log.md` に「実行日 / 昇格 n 件 / 削除候補 n 件」を追記。
6. **報告**: 削除候補を理由付きでチャットに提示。承認されたものだけ削除し、
   各プロジェクトの `MEMORY.md` の index 行も併せて更新する。

## 実行タイミング

- 手動起動が基本（月次目安）。in-session なら `/loop` で回してもよい。
- **cloud routine は不可**: ローカルの `~/.claude/` と vault にアクセスできないため。
