---
description: "事業観点でPlan/設計/PRをレビュー。目的とゴールに対する妥当性を評価。トリガー: pdm-review, 事業レビュー, PdMレビュー, ROI確認"
allowed-tools:
  - Task
  - Read
  - Grep
  - Glob
---

# pdm-review スキル

Plan、設計、PRを事業観点でレビューし、目的とゴールに対する妥当性を評価する。

## 概要

PdM (Product Manager) の視点で以下を評価:
- 目的との整合性
- 投資対効果 (ROI)
- リスク

## 使用方法

### 手動呼び出し

```
/pdm-review
```

現在のコンテキスト（Plan内容、diff、設計書）を自動収集してレビューを実行。

### 自動呼び出し

Planモード終了前（ExitPlanMode呼び出し前）に自動で実行される。

**Skip条件**:
- 5行以下のバグ修正
- ドキュメント変更のみ

## 実行フロー

```
1. Context確認
   ↓
   goal/metricsが不明？
   → Yes: 質問フェーズ
   → No: 評価フェーズ

2. 質問フェーズ（必要時）
   Q1: この変更で何を達成したい？
   Q2: 成功をどう測定する？
   Q3: 制約はある？

3. 評価フェーズ
   - 目的整合性 (⭐1-5)
   - ROI (⭐1-5)
   - リスク評価

4. 判定
   Go / NoGo / 要確認
```

## 出力フォーマット

```markdown
## PdM Review

### Verdict: [Go / NoGo / 要確認]

### Context
- **Goal**: <目的>
- **Success Metrics**: <KPI/KGI>
- **Constraints**: <制約>

### Evaluation

| Criteria | Score | Comment |
|----------|-------|---------|
| Goal Alignment | ⭐X | ... |
| ROI | ⭐X | ... |

### Risks
- **[リスク種別]**: <説明> → 対策: <提案>

### Improvement Suggestions
1. ...

### Recommendation
<推奨事項と理由>
```

## NoGo時の動作

**NoGo判定時はPlanをブロック**し、以下を提供:
1. NoGoの明確な理由
2. 改善提案
3. Goに変えるために必要なこと

## 使用例

- `/pdm-review` - 現在のPlanをレビュー
- Planモード終了前に自動でレビュー実行
- PR作成前の事業価値確認

## 実装

pdm-reviewer agentを呼び出して実行:

```
Task tool call:
  subagent_type: pdm-reviewer
  prompt: |
    以下のPlan/設計/PRをレビューしてください。

    [Plan内容/diff/設計書をここに含める]
```
