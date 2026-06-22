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
