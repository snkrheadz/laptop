# Evals for AI Agents — 新モデルごとに最大の成果を引き出すために

作成: 2026-07-15。Anthropic 公式3ドキュメントを「How Product Builders Get the
Most Out of Every New Model」の観点で調査・統合したリファレンス。
claude/CLAUDE.md §4 の evals ルールの根拠・詳細版。

出典:

1. [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)
2. [Building effective agents](https://www.anthropic.com/research/building-effective-agents)
3. [Writing tools for agents](https://www.anthropic.com/engineering/writing-tools-for-agents)

---

## TL;DR — 「新モデル」というレンズで読むと3記事は1つのループになる

- **evals を持たないチーム**は新モデルが出るたびに何週間も手動テストに費やす。
  **evals を持つチーム**はsuiteを流してモデルの強みを即座に判定し、プロンプトを
  調整して数日でアップグレードを完了する。この差が競争優位の源泉(記事1)。
- 「今日はまあまあ動く」機能の多くは、実は**数ヶ月後のモデル能力への賭け**。
  低いpass rateから始まるcapability evalはこの賭けを可視化し、新モデルが出た
  瞬間に「どの賭けが当たったか」を教えてくれる(記事1)。
- agent の複雑化(workflow→agent、単発→ループ)は**測定で実証的に改善する場合
  のみ**正当化される。evals はその測定器(記事2)。
- tools は非決定論的な agent と決定論的なシステムの間の**新しい契約**。契約の
  質は eval → transcript 分析 → 改善のループで磨く。このループは Claude 自身に
  回させることができ、人間の手作業を上回る(記事3)。

統合すると: **シンプルに作る → real-world task で eval → transcript を読む →
プロンプト/ツールを直す → 新モデルが出たら suite を流す → 測定に基づき採用**。

---

## 1. 基礎概念(記事1: Demystifying evals)

### 構成要素

| 用語 | 定義 |
|---|---|
| Eval | 入力を与え、出力に採点ロジックを適用して成功を測るテスト |
| Task | 明確な入力と成功基準を持つ単一のテストケース |
| Trial | task への1回の試行。出力はばらつくため複数 trial 実行する |
| Grader | 性能のある側面を採点するロジック。1 task に複数持てる |
| Transcript | 出力・tool call・推論・中間結果を含む trial の完全な記録 |
| Outcome | trial 終了時点での環境の最終状態 |
| Eval harness | task を並行実行し、全ステップを記録し、採点するインフラ |
| Eval suite | 特定の能力・振る舞いを測る task の集合 |

複雑さの階段: single-turn → multi-turn → **agent evals**(ツールを多ターン使い
環境の状態を変更する。最も複雑)。

### Grader の3種類

| 種類 | 例 | 長所 | 短所 |
|---|---|---|---|
| Code-based | string match, binary test, 静的解析, outcome検証 | 高速・安価・客観的・再現可能 | 妥当なバリエーションに脆弱、ニュアンスを欠く |
| Model-based (LLM judge) | rubric採点, 自然言語assertion, pairwise比較 | 柔軟・スケーラブル | 非決定的・高コスト・要calibration |
| Human | SMEレビュー, 抜き取り確認, A/Bテスト | ゴールドスタンダード | 高コスト・低速 |

原則: **可能な限り決定論的(code-based)grader を使い、必要な時だけ LLM judge**。
LLM judge は人間の専門家判定と calibration し、「Unknown」と答える逃げ道を必ず
用意する。

### Eval の2つのスコープ

- **Capability (quality) evals** — 「この agent は何が得意か」。低い pass rate
  から始まってよい(むしろ始まるべき)。将来モデルへの賭けの可視化装置。
- **Regression evals** — 「以前できていたことは今もできるか」。ほぼ 100% を
  維持すべき。

### メトリクス

- **pass@k** — k 回の試行のうち少なくとも1回成功する確率。k↑でスコア↑。
  探索的・capability 向き。
- **pass^k** — k 回の試行**すべて**が成功する確率。k↑でスコア↓
  (per-trial 75% × 3 trials ≈ 42%)。顧客向けで一貫性が要る場面向き。

evals が一度存在すれば、レイテンシ・トークン使用量・タスクあたりコスト・
エラー率のベースラインと回帰検知は「無料で」ついてくる。

---

## 2. Zero-to-One ロードマップ(記事1)

1. **今すぐ小さく始める** — 20〜50 task で十分。待つほど構築は難しくなる
   (本番からの逆算は、要件を自然に eval へ翻訳する機会を失う)。
2. **ソースは実在の失敗** — リリース前に手動確認している振る舞い、バグ
   トラッカー、サポートキュー。ユーザー影響度で優先順位付け。
3. **良い task の基準** — 「2人のドメインエキスパートが独立に同じ pass/fail
   判定に至る」こと。自分でその task をパスできないなら task を練り直す。
   frontier model が pass@100 で 0% なら task 自体が壊れているサイン。
4. **双方向でバランスさせる** — 「起こるべき」と「起こらないべき」の両方を
   テストする(例: 検索すべき場合と既存知識で答えるべき場合)。片方向のみの
   eval は片方向への過剰最適化(over-trigger)を招く。
5. **環境をクリーンに** — 各 trial はクリーン環境から。古いファイル・
   キャッシュ・リソース枯渇などの状態共有は結果を汚す。
6. **経路でなく結果を採点する** — tool call の厳密な順序を要求するような
   grading は脆弱(agent は設計者が想定しない正当な経路を見つける)。
   outcome を採点し、複数コンポーネントには partial credit を。
7. **transcript を読む** — grader が機能しているかは transcript を読まないと
   分からない。Anthropic 社内でも閲覧ツールに投資し、定期的に読む時間を
   確保している。「失敗は公正に見えるべき」。
8. **飽和(saturation)を監視** — 全 task に合格し始めたら、より難しい task を
   追加する(SWE-bench Verified は 30% スタート→frontier は 80% 超)。
9. **eval suite は生きた成果物** — 未実装の計画中の能力を先に eval として
   定義する「eval-driven development」も有効。

---

## 3. Agent 設計原則と evals の関係(記事2: Building effective agents)

### 設計の大原則

- 成功していたチームは複雑なフレームワークではなく**シンプルで構成可能な
  パターン**を使っていた。まず単一 LLM 呼び出しの最適化、足りない時のみ
  マルチステップへ。
- **複雑さを追加するのは、測定でアウトカムの改善が実証される場合のみ。**
  これが agent 設計と evals の接続点。
- Workflow(事前定義された経路 = 予測可能・一貫)vs Agent(モデルが動的に
  プロセスを監督 = 柔軟・スケール)。予測可能性が要るなら workflow。
- agent 化はレイテンシ・コストをタスク性能と引き換えるトレードオフ。
  妥当かを常に検討する。

### パターン語彙(検証設計に効く順)

- **Evaluator-optimizer** — 生成 LLM と評価 LLM のループ。適合の4条件:
  ①明確な評価基準がある ②反復改善が測定可能な価値を生む ③人間の明示的
  フィードバックで実証的に改善する ④LLM がそのフィードバックを出せる。
- **Orchestrator-workers** — 中央 LLM が動的にタスク分解しワーカーへ委譲。
- **Prompt chaining** — ステップ分解 + 中間に検証ゲート。
- **Routing / Parallelization (sectioning, voting)** — voting は偽陽性/偽陰性の
  バランスで閾値を変える。

### Agent の安全装置

- 自律性 = 高コスト + **複合エラー(compounding errors)**のリスク。sandbox での
  広範なテストとガードレールが前提。
- **停止条件**(最大反復回数など)を必ず入れる。
- 各ステップで環境から ground truth(tool call 結果、コード実行結果)を取得し、
  ブロッカー時に人間へ一時停止できる設計にする。
- **ACI(Agent-Computer Interface)を文書化しテストする** — SWE-bench 用ツールで
  相対パス誤用が頻発 → 絶対パス必須に変更したら誤用が消えた(Poka-yoke)。

---

## 4. Tools × evals の改善ループ(記事3: Writing tools for agents)

### ツール設計プラクティス

1. **ワークフロー単位で統合** — API 1機能=1ツールのラッピングを避け、
   `schedule_event`(list_users+list_events+create_event)、
   `get_customer_context` のような少数の高インパクトなツールへ。
2. **Namespacing** — `asana_projects_search` のような prefix/suffix で機能境界を
   明確化。この選択の影響は非自明なので**モデルごとに実測**する。
3. **意味のある識別子を返す** — `uuid`/`mime_type` でなく `name`/`file_type`。
   UUID をセマンティックな ID に解決するだけで精度が上がり幻覚が減る。
4. **可変粒度レスポンス** — ResponseFormat enum(DETAILED 206 tokens / CONCISE
   72 tokens の実例)。Slack thread_ts の例で約 1/3 のトークン削減。
5. **トークン効率** — pagination・range・filter・truncation。Claude Code は
   ツール応答をデフォルト 25,000 tokens に制限。「広い1回の検索より小さな
   標的検索を複数」と agent に明示的に指導する。
6. **エラーは実行可能な改善提案で返す** — エラーコードや traceback でなく、
   正しいパラメータ形式の例を返す。
7. **description は新入社員向けに書く** — 暗黙知(特殊クエリ形式・用語・
   リソース間関係)を明文化。`user` でなく `user_id`。description の精密化
   だけで SWE-bench のエラー率低減・完了率向上を達成した実例あり。

### Eval ループ

- **task は real-world で複雑に** — 数十回の tool call を要する現実的シナリオ
  (弱い例: 「jane@acme.corp と会議を設定」/ 強い例: 「Jane と来週会議を設定し、
  前回のプロジェクト計画会議のノートを添付し、会議室を予約」)。sandbox より
  本物のデータソースでのストレステストを重視。
- **数十(dozens)のプロンプト-応答ペア**を Claude Code で高速生成し、
  検証可能な結果と対にする。verifier は書式・句読点の違いで落とさない
  「厳密すぎない」ものに。**held-out test set で過学習を防ぐ**。
- **収集メトリクス**: 正答率、実行時間、tool call 総数、トークン消費、
  ツールエラー。呼び出しパターン分析はツール統合の機会を教えてくれる。
- **transcript 分析** — agent が「書いたこと」と同じくらい「省略したこと」が
  重要。reasoning ブロックの精読と生の tool call/response の検査で、CoT に
  現れない振る舞いを捉える(実例: web search ツールが query に不要な「2025」を
  付けてバイアスしていた問題を transcript で発見し、description 修正で解決)。
- **Claude 自身にツールを改善させる** — eval の transcripts を連結して
  Claude Code に渡すと、複数ツールを一括リファクタリングし、実装と
  description の整合性チェックまで行う。社内 Slack/Asana MCP の実測で
  **Claude 最適化版が人間作成版を held-out set で上回った**。記事のアドバイス
  の大部分自体が Claude Code との反復最適化から得られたと明言。

---

## 5. アンチパターン集(3記事統合)

| # | アンチパターン | 出典 |
|---|---|---|
| 1 | evals の構築を先延ばしにする(後からの逆算は情報を失う) | 1 |
| 2 | 曖昧な task 仕様・grading バグ(CORE-Bench で修正前 42% → 修正後 95%) | 1 |
| 3 | tool call の厳密な順序など rigid すぎる grading | 1 |
| 4 | 片方向のみの eval(over-trigger への最適化を招く) | 1 |
| 5 | grader のハック・bypass 耐性の欠如(git history を覗いて有利になった実例) | 1 |
| 6 | 飽和した easy eval での過信 / 逆に単純すぎる eval での新モデル過小評価(Qodo の例: one-shot では不満 → agentic eval で明確な向上) | 1 |
| 7 | 測定なしの複雑化・過剰なフレームワーク依存(抽象化がデバッグを阻害) | 2 |
| 8 | 停止条件・ガードレールなしの自律 agent(複合エラー) | 2 |
| 9 | More tools ≠ better outcomes(API の単純ラッピング、list_contacts 型の全件取得) | 3 |
| 10 | 低レベル ID(UUID 等)のみ返す・全部返す冗長レスポンス(幻覚とコンテキスト圧迫) | 3 |
| 11 | 不透明なエラー(コードのみ・traceback のみ) | 3 |
| 12 | transcript を読まずにスコアだけ見る | 1,3 |

---

## 6. この環境への適用(snkrheadz: laptop + the-boris-way)

現状の資産と記事のフレームの対応:

- `scratchpad/test-guard.sh`(pre-tool-guard の12ケース)は**すでに regression
  eval**。「稼働中の hook がテスト文字列の curl|bash を実際にブロックした」は
  outcome-grading の生きた実例。
- `docs/fable5-vs-opus48.html` は**アドホックな capability eval**。suite 化
  されていないので、次の新モデルでは同じ作業をやり直すことになる。
- `/craft:produce`(rubric → verifier → taste-judge)は evaluator-optimizer
  パターンそのもの。4条件チェックリストが「full mode を使うべきか」の判定に
  そのまま使える。
- CLAUDE.md §2 の model routing(fact-finding→sonnet 等)は**検証されるべき
  賭け**。suite があれば新モデルごとに routing 表を数字で更新できる。
- `dream.sh` の transcript 読み取り基盤は、記事3の「transcripts を Claude に
  渡してツール/skill の description を改善させる」ループに転用できる。

推奨アクション(優先順):

1. **`evals/` を作る(20〜50 task)** — ソースは tasks/lessons.md の失敗事例、
   過去の hook 事故(auto-sync)、skills の手動確認項目。capability と
   regression をディレクトリで分ける。
2. **grader は code-based 優先** — shellcheck / jq / verify.sh の drift check の
   延長線。skill 出力の主観品質だけ craft:verifier(LLM judge)へ。
3. **新モデルリリース時の手順を固定化** — suite 実行 → capability の pass rate
   変化で「当たった賭け」を特定 → model routing 表(§2)とプロンプトを更新。
   fable5-vs-opus48 の次回版はレポートでなく suite の実行結果にする。
4. **一貫性が要るもの(hooks, guards)は pass^k で見る** — 1回通ればよい
   ものではない。
5. **transcript を読む時間を仕組み化** — dream.sh の generate 対象に
   「失敗 trial の transcript サンプリング」を追加する。

---

## 7. 出典メモ

調査: sonnet teammates 3体による serial WebFetch(2026-07-15)、統合: Fable 5。
各記事の一次情報は冒頭のリンクを参照。本ドキュメントは要約であり、数値・
実例は記事の記載に基づく。
