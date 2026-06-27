# Claude Code 日次ワークフロー（The Boris Way）

> 出典の起点: Boris Cherny *Practical Tips on How to use Claude Code*（https://www.youtube.com/watch?v=M8HuXu_bOco）
> 関連: [`claude-code-practical-tips-boris-cherny.md`](./claude-code-practical-tips-boris-cherny.md)（講演まとめ）/
>       [`claude-code-context-supply-the-boris-way.md`](./claude-code-context-supply-the-boris-way.md)（コンテキスト供給の流儀）
>
> 本書は「**Boris なら新しいリポジトリで最初に何をし、毎日どんなループを回すか**」を実行手順に落としたもの。
> ※ Part 3 のメンテループは講演に直接は出てこない。**Boris の思想（context supply）を日次運用へ拡張**した部分で、自分の `~/.claude/CLAUDE.md` §5（loop/routine primitives）に整合させてある。区別して読むこと。

---

## Part 1: 初めてのリポジトリでやること（Day 0 オンボーディング）

Boris の鉄則は「**最初から完璧を作らない。質問から入り、使いながら育てる**」。順序が大事。

### Step 0. まず質問する（zero setup で入る）
新しいコードベースに入ったら、設定より先に**質問でコードベースを理解する**。これが Boris の言う「新規ユーザーの最も簡単な入り口」かつ「ローカル完結・セットアップ不要」。
```
> このリポジトリの全体像を3行で。主要なエントリポイントとビルド/テスト方法は？
> How is @<主要ファイル> used?
> What did this repo ship last week?（git 履歴から）
```
→ ここで得た「コマンド・ファイル地図」が、次の CLAUDE.md の素材になる。

### Step 1. 環境を最適化する（一度きり）
- `/terminal-setup` — **Shift+Enter で改行**を有効化
- `/config` — **通知をオン**（長い処理の完了に気づける）
- `/theme` — ライト/ダーク
- `/install-github-app` — Issue/PR で `@claude` を使うなら
- `/allowed-tools` — よく使うツールの権限を許可してプロンプト疲れを減らす

### Step 2. CLAUDE.md を「最小で」作る
- `/init` で叩き台を生成（または手書き）。
- 入れるのは Step 0 で分かった **毎回必要なものだけ**: Commands / File map / 理由つき Conventions。
- ❌ 一般論（「テストを書け」等）は書かない。モデルは既に知っている。
- 詳細テンプレは context-supply docs §3 を参照。

### Step 3. 繰り返す手続きをコマンド化する
- 同じ指示を2回打ったら `.claude/commands/<name>.md` に切り出す → `/project:<name>` で再利用。
- 例: `create-release-pr` / `fix-github-issue` / `lint`。

### Step 4. チームのツールを教える
- 社内 CLI: `Use the <tool> CLI ... Use -h to check how to use it`（ヘルプを読ませる）。
- 恒常利用の外部システム: `claude mcp add <name> -- <cmd>` で MCP ツール化。

### Step 5. キーバインドを体に入れる
`Shift+Tab`（編集の自動承認）/ `#`（メモ追記）/ `!`（bashモード）/ `@`（ファイル投入）/ `Esc`（中断）/ `Double-Esc`（履歴を遡る）/ `Ctrl+R`（詳細出力）。

> **Day 0 のゴール**: 「質問できる状態 ＋ 最小の CLAUDE.md ＋ 通知/改行」。ここから毎日育てる。

---

## Part 2: 毎日の実作業ループ（Boris の Common Workflows）

Boris が挙げた3つの型。すべて「**先に基準を固定 → 実装 → 検証して反復**」という同じ骨格。

### ループA: 探索 → 計画 → 確認 → 実装 → コミット
バグ修正・設計判断が要るとき。**いきなり書かせない**。
```
> Figure out the root cause for issue #983, then propose a few fixes.
  Let me choose an approach before you code. ultrathink
```
- `ultrathink` / `think hard` で思考量を増やす。
- 「confirm（人が承認）」を挟むのが肝。実装前に方向を選ぶ。

### ループB: テスト → コミット → 実装 → 反復 → コミット（TDD）
仕様が明確なとき。**テストを先に固定してコミット**し、それを基準に実装。
```
> Write tests for @utils/markdown.ts to make sure links render properly
  (note the tests won't pass yet, since links aren't yet implemented).
  Then commit. Then update the code to make the tests pass.
```
- 「まだ通らない」とあらかじめ伝えるのがコツ（Claude が無理に通そうとしない）。

### ループC: 実装 → スクリーンショット → 反復（ビジュアル）
UI をモックに寄せるとき。**自己検証ループ**。
```
> Implement [mock.png]. Then screenshot it with Puppeteer and iterate
  till it looks like the mock.
```

### 毎日使うプリミティブ
- **`@`** で必要なファイルだけ遅延投入（全部 CLAUDE.md に書かない）。
- **`#`** で「これは毎回必要」と気づいた知識をその場で CLAUDE.md に還元。
- **並列エージェント**: `Use 3 parallel agents to brainstorm ...`。
- **Multi-claude**: 別タブの複数チェックアウト / git worktrees / SSH+tmux / GitHub Actions で並列に走らせる。

---

## Part 3: 毎日のメンテループ — コンテキストを腐らせない

> ⚠️ ここからは講演の範囲外。**Boris の「context supply」思想を日次運用に拡張**した部分（自分の CLAUDE.md §5 と整合）。

チームが毎日コードを変えると、CLAUDE.md の「事実」は確実にズレる。**育てる（足す）と同じ頻度で、削る・直すループを回す**のが要点。

### 頻度ごとの担当
| 周期 | やること | 道具 |
|---|---|---|
| **日次（セッション終わり）** | その日の学び（コマンド・クセ・落とし穴）を還元 | `#` メモ / `claude-md-management:revise-claude-md`（公式） |
| **イベント駆動** | 構造変更・コマンド変更・新サービス追加の **PR でその場更新** | PR チェックリストに「CLAUDE.md 更新」 |
| **週次（軽い点検）** | CLAUDE.md と実態のズレを軽く確認、明らかな古い記述を削る | 手動 / `claude-md-improver`（公式、`conciseness` 基準） |
| **月次（剪定）** | 肥大・矛盾・重複の棚卸し | `claude-md-improver`（公式）＋ `eng:prune-redundant-skills`（自作・土台側） |

### どのループ primitive を使うか（CLAUDE.md §5 準拠）
- **その場で観察・維持したい** → `/loop`（セッション内、起動中のみ。コストはプラン枠内）
- **検証可能な終了条件がある**（例: 全 CLAUDE.md がスコア閾値超え）→ `/goal`
- **不在でも定期実行したい** → **routine**（クラウド cron。プラン枠内／月次なら 1日15回上限に触れない）
  - ただし routine からプラグイン skill（improver/prune）を呼べるかは **未確定**
    → [`TODO-routine-plugin-skill-verification.md`](./TODO-routine-plugin-skill-verification.md)
  - 確定するまでは **月次剪定は手動/ローカル**で回す（確実・追加コストなし）

### 剪定の原則（Boris §0 と同じ）
- **足したら削る**。CLAUDE.md は書き切るものでなく、運用で太らせ・刈り込むもの。
- **一般論・rules は増やさない**。「ルールが要る」と感じたら、まず context 供給（CLAUDE.md / コマンド / @）で代替できないか疑う。
- **削除でなくアーカイブから**（無人ループでは特に。誤学習・破壊を防ぐ。dotfiles の Dreaming dry-run 思想と同じ）。

---

## まとめ — 1日の流れ

```
Day 0（初回）: 質問で理解 → 環境最適化 → 最小CLAUDE.md → コマンド/ツール接続
  ↓
毎日（実作業）: 探索→計画→確認→実装→検証 のループ（A/B/C を使い分け）
              @で投入 / #で還元 / 並列・multi-claude でスケール
  ↓
毎日（メンテ）: セッション終わりに学びを # / revise で還元
週次: 軽い点検で古い記述を削る
月次: improver + prune で剪定（当面は手動、routine 化は検証後）
```

> Boris の一行: **More context = better performance**。
> ただし「足す」だけでは腐る。**育てると刈り込むを同じリズムで回す**のが、毎日変わるコードベースでコンテキストを事実と一致させ続けるコツ。
