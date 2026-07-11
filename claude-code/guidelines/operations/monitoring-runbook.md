# Monitoring / Runbook Guidelines

> **Purpose**: SLO burn rate thresholds and response urgency on alert. Reference on production incidents or SLO violation detection.

## SLO Burn Rate Alert Response

### Burn Rate Thresholds and Urgency

| Long Window | Short Window | Burn Rate | Budget exhaustion estimate | Urgency |
|-------------|--------------|-----------|---------------------------|---------|
| 1h | 5m | 14.4 | ~49h | **Immediate** |
| 6h | 30m | 6 | ~114h | Same-day |
| 48h | 240m | 3 | ~192h | Next business day |

### Response Flow

```text
Receive alert
  ↓
Open incident dashboard
  ↓
Identify cause (layer-by-layer triage)
  ├── CDN/LB: 5xx error rate spike? Cache hit rate drop?
  ├── Container: CPU/memory pressure? Task count decrease? 502 increase?
  ├── Application: error log surge? latency degradation on specific endpoint?
  ├── DB: CPU pressure? connection spike?
  └── Cache: hit rate drop? memory pressure?
  ↓
Execute fix or mitigation (LB empty response, scale out, add Reader)
```

## Infra Alert Response Patterns

| Alert type | Triage | Mitigation |
|------------|--------|-----------|
| Container task count drop | deploy failure, platform outage | manual task increase, version downgrade |
| DB CPU > 80% | heavy query, connection spike | add Reader, identify/fix heavy query |
| Lock Wait Timeout | long-running transaction | identify and kill lock-holding transaction |
| Queue backlog | consumer failure, processing delay | check worker errors, check DLQ |
| DLQ received | worker processing failure | inspect message → fix cause → reprocess |
| Cache bandwidth exceeded | GET concentration, cache bloat | add node, review cache strategy |
| LB 502 increase | container OOM etc. | increase memory allocation, investigate memory leak |
| Batch not started | insufficient resources | re-run in another AZ |
| Email send rate exceeded | large-scale delivery | identify sender, request rate limit increase |

## Security Alert Response

| Attack type | Detection condition | Immediate action |
|-------------|--------------------|--------------------|
| Credential stuffing | high request volume to login endpoint | WAF IP block, check affected accounts |
| Credit card fraud | high request volume to payment endpoint | WAF IP block, invalidate fraudulent cards |
| XSS attack | large volume of `<script` pattern detected | verify WAF rules, check for successful hits |
| WAF count spike | high count on specific rule | analyze attack pattern, consider promoting to Block rule |
| Admin panel public exposure | security group change detected | verify SG/WAF config, restore IP restriction |

## API Error Response

| Alert | Action | Note |
|-------|--------|------|
| Critical API 5xx | narrow by trace ID → APM for details | — |
| No success for a period | possible outage → begin investigation | late-night hours may be false positives |
| Payment callback error rate increase | access log → trace ID → detailed investigation | also check for handler not reached |
| Error log surge (threshold exceeded) | check concentration on specific service/endpoint | — |

## Synthetics Test Failure Response

```text
1. Stop scheduled execution (failures will continue)
2. Manually verify target page is accessible
   ├── Not accessible → possible outage → identify cause and recover
   └── Accessible → test scenario is the issue → fix scenario
3. Share findings in notification thread
```

## Escalation Decision

| Severity | Notify | Condition examples |
|----------|--------|--------------------|
| CRITICAL | PagerDuty (immediate) | availability SLO 1h window exceeded |
| HIGH | emergency channel | 6h window exceeded, security, payment outage |
| MEDIUM | standard alert channel | burn rate warning, general prod alert |

## Deploy Failure: ECR image expiry

ECR lifecycle policy (例: `tagStatus: any countMoreThan 30`) が build → deploy 間の経過時間で image を expiry すると、ECS deploy が "failed to wait for service stable" で停止する。

| 項目 | 内容 |
|------|------|
| 症状 | deploy job が service stable 待ちで timeout する |
| 原因 | ECS が参照する image が ECR lifecycle policy で削除済 |
| 対処 | empty commit を push して CI rebuild → re-deploy の正規パスを通す |
| 予防 | deploy は build から 1h 以内に完了させる。間隔が空く運用なら countMoreThan 値を見直す |

直接 task def を触る応急処置は取らない。commit push → CI rebuild → re-deploy を通せば ECS が確実に最新 image を参照する。

## Runbook / SQL のテーブル名は完全名で書く

runbook / SQL コードブロックには実 schema の完全テーブル名を書く。略称を SQL に流用すると `SHOW TABLES LIKE '<短縮名>'` が Empty set を返し、「table 不在」と誤検知して緊急 task 起票まで進む事故が起きる。

- 本文の説明では略称を使ってよい。ただし初出で「`<完全名>` (以下 `<短縮名>` と略す)」と完全名を 1 度提示する
- `LIKE` 句で略称を使うなら `LIKE '%短縮名%'` のようにワイルドカードを付ける。exact match の `LIKE '短縮名'` は危険
- 既存 runbook の略称表記は次回大改修時に一括置換する (急いで一斉置換しない)

## Runbook Template

Structure for new runbook creation:

```markdown
# {Alert name} Response Runbook
## Overview — what is monitored and why it matters
## Monitor info — monitor name / notification target / threshold (specific values)
## Response flow — 1. initial check 2. triage 3. execute fix
## Escalation — who, under what conditions
## Reference links — dashboards, related documents
```
