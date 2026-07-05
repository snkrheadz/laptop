---
name: gcp-cost
description: GCPの指定期間のコストを計算・分析する。コスト確認、請求分析、サービス別内訳の表示に使用。
allowed-tools: Bash(bq *)
---

# GCP Cost Analysis Skill

GCPのビリングエクスポートデータをBigQueryで分析し、コストを計算する。

## 設定

- **Billing Export Table**: `billing_export.gcp_billing_export_v1_018836_A5D205_75ED20`
- **Default Project**: `ai-ops-poc`
- **通貨**: JPY（日本円）

## 引数

- `$0`: 期間（例: `7d`, `30d`, `3m`）またはサービス名（例: `Vertex AI`, `Cloud Run`）
- `$1`: 追加フィルタ（オプション）

## 実行するクエリ

### 1. 日別コストサマリー

```bash
bq query --use_legacy_sql=false --project_id=ai-ops-poc '
SELECT
  DATE(_PARTITIONTIME) AS date,
  currency,
  ROUND(SUM(cost), 2) AS cost
FROM `billing_export.gcp_billing_export_v1_018836_A5D205_75ED20`
WHERE project.id = "ai-ops-poc"
  AND DATE(_PARTITIONTIME) >= DATE_SUB(CURRENT_DATE(), INTERVAL <DAYS> DAY)
GROUP BY 1, 2
ORDER BY 1 DESC'
```

### 2. サービス別コスト内訳

```bash
bq query --use_legacy_sql=false --project_id=ai-ops-poc '
SELECT
  service.description AS service,
  currency,
  ROUND(SUM(cost), 2) AS cost
FROM `billing_export.gcp_billing_export_v1_018836_A5D205_75ED20`
WHERE project.id = "ai-ops-poc"
  AND DATE(_PARTITIONTIME) >= DATE_SUB(CURRENT_DATE(), INTERVAL <DAYS> DAY)
GROUP BY 1, 2
HAVING SUM(cost) > 0
ORDER BY 3 DESC'
```

### 3. 特定サービスのSKU別内訳

```bash
bq query --use_legacy_sql=false --project_id=ai-ops-poc '
SELECT
  DATE(_PARTITIONTIME) AS date,
  sku.description AS sku,
  currency,
  ROUND(SUM(cost), 2) AS cost
FROM `billing_export.gcp_billing_export_v1_018836_A5D205_75ED20`
WHERE project.id = "ai-ops-poc"
  AND service.description = "<SERVICE_NAME>"
  AND DATE(_PARTITIONTIME) >= DATE_SUB(CURRENT_DATE(), INTERVAL <DAYS> DAY)
GROUP BY 1, 2, 3
ORDER BY 1 DESC, 4 DESC'
```

## 出力形式

以下の情報を含めて結果を報告する:

1. **期間**: 分析対象の日付範囲
2. **合計コスト**: 期間内の総コスト（通貨単位を明記）
3. **日平均**: 1日あたりの平均コスト
4. **サービス別内訳**: 上位サービスのコスト
5. **トレンド**: コストの増減傾向（あれば）

## 使用例

```
# 過去7日間のコストを確認
/gcp-cost 7d

# 過去30日間のVertex AIコストを確認
/gcp-cost 30d "Vertex AI"

# サービス別内訳を確認
/gcp-cost services
```

## 注意事項

- ビリングデータは数時間〜1日遅れで反映される
- 当日のデータは不完全な可能性がある
- `currency` カラムで通貨単位を必ず確認する
