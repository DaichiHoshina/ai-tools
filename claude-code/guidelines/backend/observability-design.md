# Observability Design Guidelines

> **Purpose**: Reference for building SLI/SLO, distributed tracing, and metric/log/trace correlation. Follows OpenTelemetry semconv 2025.

## Tier classification

| Tier | Content |
|------|---------|
| Tier 1 (required) | SLI/SLO, structured logging, basic metrics |
| Tier 2 (scale-dependent) | Distributed tracing, Error Budget operation |
| Tier 3 (advanced) | Full OpenTelemetry semconv compliance, auto-instrumentation |

---

## 1. SLI / SLO / Error Budget

| Concept | Definition | Example |
|---------|-----------|---------|
| **SLI** | Observable metric | Availability, latency P99 |
| **SLO** | Internal target | Monthly availability 99.9% |
| **SLA** | Customer contract (looser than SLO) | Monthly availability 99.5% |
| **Error Budget** | Allowable failure rate | `100% - SLO%` = 0.1% |
| **Burn Rate** | Consumption speed | observed_errors / acceptable_errors |

**SLO 99.9% allowed downtime**:
- 30 days → ~43.2 minutes
- 7 days → ~10 minutes
- 1 hour → ~3.6 seconds

---

## 2. SLI design (4 Golden Signals)

| Type | SLI example | Measurement |
|------|-------------|------------|
| **Latency** | P99 < 500ms | histogram |
| **Traffic** | RPS, QPS | counter |
| **Errors** | 5xx rate < 0.1% | counter (error/total) |
| **Saturation** | CPU < 70%, queue depth | gauge |

**SLI definition template**:
```text
Percentage of valid requests that returned a successful response within 200ms
Numerator: count(status=2xx AND latency<200ms)
Denominator: count(status IN (2xx,4xx,5xx) - status IN (401,429))
```
(Exclusion of some 4xx from denominator depends on requirements; excluding auth/rate-limit is standard)

---

## 3. Burn Rate alert (multi-window)

| Window | Burn Rate threshold | Meaning | Notification |
|--------|--------------------|---------|-|
| 1h | 14.4 | 1 day consumed in 1h | PagerDuty urgent |
| 6h | 6 | 1 day consumed in 6h | Slack warning |
| 3d | 1 | Normal rate | No notification |

**Formula**: `burn_rate = error_rate / (1 - SLO)`

---

## 4. Structured logging

Required fields and prohibitions: see `common/logging-standards.md`.

---

## 5. Metric × Log × Trace correlation

```text
Metric (detect spike)
  → Log (filter by trace_id)
  → Trace (follow spans to identify root cause)
```

**Implementation**:
- Auto-attach `trace_id`/`span_id` to all logs (OpenTelemetry SDK)
- Exemplars for metric ↔ trace direct link
- Dashboard: click metric graph → search trace ID → trace UI

---

## 6. Distributed tracing

| Element | Role |
|---------|------|
| **trace_id** | Identifies full request (128-bit) |
| **span_id** | Identifies single operation (64-bit) |
| **parent_span_id** | Parent-child relationship |
| **W3C Trace Context** | Propagate via HTTP `traceparent` header |

**Propagation example**:
```text
Client → API Gateway → Order Service → Payment Service
         inherit + add traceparent header at each hop
```

**Required span attributes**:
- `service.name`, `service.version`
- `http.method`, `http.status_code`, `http.url`
- DB operation: `db.system`, `db.statement` (sanitized SQL)
- On error: `exception.type`, `exception.message`, `exception.stacktrace`

---

## 7. Instrumentation checklist

| Layer | Auto | Manual additions |
|-------|------|----------------|
| HTTP server | OTel auto | Custom business attributes (user.id etc.) |
| HTTP client | OTel auto | Retry count |
| DB driver | OTel auto | Query type tag |
| Cache | Manual | hit/miss |
| Queue | Manual | Link publish/consume spans |
| Background job | Manual | job.name, job.duration |

---

## 8. Dashboard design

**Minimum 3 views**:
1. **Overview**: 4 Golden Signals + Error Budget remaining
2. **Service detail**: P50/P95/P99 per endpoint, error breakdown
3. **Trace explorer**: recent slow traces → drill-down

---

## 9. Alert design principles

| Avoid | Use instead | Reason |
|-------|-------------|--------|
| Alert on CPU > 80% | Alert on SLO violation | Directly tied to customer impact |
| Alert on all errors | Alert on burn rate 14.4 / 6 | Reduces toil |
| PagerDuty immediately | Multi-tier (Slack → PD) | Severity separation |
| Static threshold only | Anomaly detection | Absorbs seasonality |

**Alert fatigue prevention**: target < 2 alerts per person per day.

---

## 10. OpenTelemetry Semantic Conventions 2025

Key semconv:
- HTTP: `http.request.method`, `http.response.status_code`
- DB: `db.system.name`, `db.operation.name`
- Messaging: `messaging.system`, `messaging.operation.type`
- GenAI: `gen_ai.system`, `gen_ai.request.model` (new in 2025)

**2025 stable areas**: HTTP, Database, Messaging, GenAI (new).

---

## 11. References

- Google SRE Workbook: Error Budget Policy
- OpenTelemetry Semantic Conventions official
- Related: `backend/database-performance.md` (slow query log), `backend/security-hardening.md` (audit log integration), `operations/monitoring-runbook.md` (incident response)
