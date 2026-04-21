# 可観測性設計 ガイドライン

SLI/SLO設計、distributed tracing、metric/log/trace相関を構築する時に参照。OpenTelemetry semconv 2025準拠。

## Tier 区分

| Tier | 内容 |
|------|------|
| Tier 1（必須） | SLI/SLO、構造化ログ、基本メトリクス |
| Tier 2（規模別） | distributed tracing、Error Budget運用 |
| Tier 3（深掘り） | OpenTelemetry semconv完全準拠、auto-instrumentation |

---

## 1. SLI / SLO / Error Budget

| 概念 | 定義 | 例 |
|------|------|-----|
| **SLI** | 観測可能なメトリクス | 可用性、レイテンシ P99 |
| **SLO** | 内部目標値 | 月次可用性 99.9% |
| **SLA** | 顧客契約値（SLOより緩い） | 月次可用性 99.5% |
| **Error Budget** | 許容失敗率 | `100% - SLO%` = 0.1% |
| **Burn Rate** | 消費速度 | observed_errors / acceptable_errors |

**SLO 99.9% の許容ダウンタイム**:
- 30日 → 約 43.2分
- 7日 → 約 10分
- 1時間 → 約 3.6秒

---

## 2. SLI 設計（4 Golden Signals）

| 種別 | SLI 例 | 計測 |
|------|--------|------|
| **Latency** | P99 < 500ms | histogram |
| **Traffic** | RPS、QPS | counter |
| **Errors** | 5xx率 < 0.1% | counter（error/total） |
| **Saturation** | CPU < 70%、queue depth | gauge |

**SLI 定義テンプレ**:
```
有効リクエストのうち、200ms以内に成功応答した割合
分子: count(status=2xx AND latency<200ms)
分母: count(status IN (2xx,4xx,5xx) - status IN (401,429))
```
（4xx 計測対象除外は要件次第、認証/rate limit除外が定石）

---

## 3. Burn Rate アラート（Multi-window）

| Window | Burn Rate閾値 | 意味 | 通知 |
|--------|--------------|------|------|
| 1h | 14.4 | 1h で 1日分消費 | PagerDuty 緊急 |
| 6h | 6 | 6h で 1日分消費 | Slack 警告 |
| 3d | 1 | 平常通り | 無通知 |

**式**: `burn_rate = error_rate / (1 - SLO)`

---

## 4. 構造化ログ

```json
{
  "timestamp": "2026-04-21T12:34:56Z",
  "level": "ERROR",
  "service": "order-api",
  "trace_id": "abc123...",
  "span_id": "def456...",
  "user_id": "user-789",
  "msg": "payment failed",
  "error": "timeout",
  "duration_ms": 5012
}
```

**必須フィールド**:
- `timestamp`（ISO 8601 UTC）
- `level`（ERROR/WARN/INFO/DEBUG）
- `service`、`trace_id`、`span_id`
- `msg`（人間可読）

**禁止**: PII、APIキー、生PWの出力（rules/enterprise-security.md準拠）。

---

## 5. Metric × Log × Trace 相関

```
Metric (急増検知)
  → Log（trace_id で絞込）
  → Trace（span 追跡で原因特定）
```

**実装**:
- 全 log に `trace_id`/`span_id` 自動付与（OpenTelemetry SDK）
- exemplar で metric ↔ trace 直リンク
- ダッシュボード: metric グラフ → クリックで trace ID 検索 → trace UI

---

## 6. Distributed Tracing

| 要素 | 役割 |
|------|------|
| **trace_id** | 1リクエスト全体を識別（128bit） |
| **span_id** | 1操作を識別（64bit） |
| **parent_span_id** | 親子関係 |
| **W3C Trace Context** | HTTP `traceparent` header で伝播 |

**伝播例**:
```
Client → API Gateway → Order Service → Payment Service
         traceparent header を毎ホップで継承・追加
```

**span に必須属性**:
- `service.name`、`service.version`
- `http.method`、`http.status_code`、`http.url`
- DB操作: `db.system`、`db.statement`（SQL を sanitize）
- error 時: `exception.type`、`exception.message`、`exception.stacktrace`

---

## 7. インストルメンテーション checklist

| 層 | 自動 | 手動追加 |
|----|------|---------|
| HTTP server | OTel auto | カスタムビジネス属性（user.id 等） |
| HTTP client | OTel auto | retry 回数 |
| DB driver | OTel auto | クエリ種別タグ |
| Cache | 手動 | hit/miss |
| Queue | 手動 | publish/consume span 連結 |
| Background job | 手動 | job.name、job.duration |

---

## 8. ダッシュボード設計

**最低3画面**:
1. **Overview**: 4 Golden Signals + Error Budget 残量
2. **Service detail**: 各 endpoint P50/P95/P99、エラー内訳
3. **Trace explorer**: 直近の slow trace 一覧 → drill-down

---

## 9. アラート設計原則

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| CPU > 80% で alert | SLO違反 で alert | 顧客影響直結 |
| 全エラーで alert | burn rate 14.4 / 6 で alert | toil 削減 |
| 即 PagerDuty | 多段（Slack→PD） | 重要度区分 |
| 静的閾値のみ | 異常検知（anomaly） | 季節性吸収 |

**alert fatigue 回避**: 1日に1人あたり 2件以下を目標。

---

## 10. OpenTelemetry Semantic Conventions 2025

主要 semconv:
- HTTP: `http.request.method`、`http.response.status_code`
- DB: `db.system.name`、`db.operation.name`
- Messaging: `messaging.system`、`messaging.operation.type`
- GenAI: `gen_ai.system`、`gen_ai.request.model`（2025 新規）

**2025 安定化領域**: HTTP, Database, Messaging, GenAI（新規）。

---

## 11. 参考

- Google SRE Workbook: Error Budget Policy
- OpenTelemetry Semantic Conventions 公式
- 関連: `backend/database-performance.md`（slow query log）, `operations/monitoring-runbook.md`（インシデント対応）
