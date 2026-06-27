# TODO: routine でプラグイン由来 skill が使えるか検証する

> 種別: 今後の検証課題（未着手）
> 背景: CLAUDE.md 月次リフレッシュを routine（クラウド cron）化する構想の前提確認。
> 関連: [`claude-code-context-supply-the-boris-way.md`](./claude-code-context-supply-the-boris-way.md) §5 /
>       [`claude-code-daily-workflow-the-boris-way.md`](./claude-code-daily-workflow-the-boris-way.md) Part 3

## なぜ検証が要るか（確定事実）

公式ドキュメント（[code.claude.com/docs/en/routines](https://code.claude.com/docs/en/routines)）で確認済み：

- ✅ routine のクラウドセッションは **「clone したリポジトリにコミットされた skill（`.claude/skills/`）」は使える**（明記あり）
- ⚠️ **プラグイン由来の skill**（Anthropic 公式 `claude-md-management:claude-md-improver`、自作 `eng:prune-redundant-skills` など）が routine 環境で使えるかは **公式ドキュメントに明示なし＝不確実**
- ⚠️ グローバル `~/.claude/settings.json` の `enabledPlugins` を routine が継承するかも明示なし
- ⚠️ setup script で `claude plugin install` 相当ができるかも明示なし

→ 「月次剪定 routine」を組む前に、この不確実性を実地で潰す必要がある。

## 検証タスク

- [ ] テスト用の最小 routine を1本作る（`/schedule`、手動 run でよい）
- [ ] routine のプロンプト内で **プラグイン skill を明示起動**してみる
      （例: `claude-md-improver を実行して CLAUDE.md を監査せよ`）
- [ ] run のセッション transcript を開き、skill が起動したか / "skill が見つからない" 等で失敗したか確認
      （注: run リストの「緑」はインフラ成功であってタスク成功ではない。中身を読む）
- [ ] 失敗した場合の回避策を確認:
  - [ ] setup script でプラグインを入れられるか（`claude plugin install ...` を試す）
  - [ ] リポジトリ `.claude/skills/` にコミットした skill なら確実に動くか（対照実験）
- [ ] 結果を本ファイルに追記し、確定したら関連 docs（context-supply §5 / daily-workflow Part 3）へ反映

## 判断の出口

| 検証結果 | 採用する組み方 |
|---|---|
| プラグイン skill が routine で動く | そのまま `claude-md-improver` / `prune` を routine から呼ぶ |
| 動かないが setup script で install 可 | setup script に install を仕込む |
| どちらも不可 | 剪定手順を **リポジトリ内 skill 化**（`.claude/skills/`）or **プロンプト直書き** |

## メモ

- 当面は routine 化せず **手動/ローカルで月次剪定**して運用（コスト・安全の確実な経路）。
- routine の課金はプラン枠内（月次なら 1日15回上限に触れない）と確認済み。コストは検証のブロッカーではない。
- 確実な仕様が必要なら [support.claude.com](https://support.claude.com) に問い合わせる選択肢もある。
