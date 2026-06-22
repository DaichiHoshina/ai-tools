# Async Job Design Patterns

> **Purpose**: Selection criteria for messaging (SQS / SNS / Kafka) and async job design patterns. Reference when designing fan-out / ordering guarantees / high-throughput backend workloads.

## Queue/Messaging Selection Criteria

| Requirement | SQS | SNS+SQS | Kafka |
|-------------|-----|---------|-------|
| Single consumer | **Best** | — | — |
| Fan-out (1:N delivery) | — | **Best** | **Best** |
| Ordering guarantee | FIFO support | — | Within-partition guarantee |
| High throughput | — | — | **Best** |
| Replay (reprocessing) | — | — | **Best** |
| Simplicity | **Best** | Medium | Complex |

## Worker/Job Implementation Patterns

### Required Steps (when adding a new Job)

1. **Task implementation** — `Perform` method in `task/{domain}/task.go`
2. **Request definition** — message struct and Job constant in `task/{domain}/request.go`
3. **Job registration** — add Job registration in the init function
4. **Job publishing** — call Publish from business logic

### Directory Structure Example

```text
cmd/worker/
├── main.go           # Job registration (initJobs)
└── task/
    ├── order/
    │   ├── task.go     # Perform(ctx, msg) error
    │   └── request.go  # Message struct, Job constant
    └── notification/
        ├── task.go
        └── request.go
```

## Async Communication Between Bounded Contexts

### publicfunctions Pattern

When a Worker Task needs to call internal logic from another Bounded Context, go through a public interface rather than importing directly.

```text
bounded_context/
└── order/
    └── interface/
        └── publicfunctions/
            ├── order_functions.go       # Interface definition
            └── order_functions_impl.go  # Implementation with internal imports
```

| Rule | Detail |
|------|--------|
| Worker Task imports only the interface package | Direct dependency on internal packages forbidden |
| Public functions aggregated per BC | Do not scatter |
| Only implementation files may have internal imports | Interface files have no external dependencies |

## DLQ (Dead Letter Queue) Design

Prevents consumer total halt from poison pills.

| Config | Recommendation |
|--------|----------------|
| DLQ placement | Required for all queues |
| max retry | 3–5 times (adjust per job characteristics) |
| backoff | Exponential (1s → 4s → 16s) |
| DLQ arrival condition | Retry exceeded or parse failure |
| Alert on DLQ receipt | Count SLO; alert if stale >24h |
| Reprocessing procedure | Inspect DLQ message → fix cause → re-enqueue to main queue |

**Attach per-message cause metadata to DLQ** (error message, stack trace, attempt count). Enables re-enqueueing and analysis later.

## Ensuring Idempotency

At-least-once delivery is assumed; design so "duplicate execution produces the same result" is mandatory.

| Pattern | Implementation |
|---------|----------------|
| **Idempotency Key** | Client generates UUID; server stores fingerprint and detects duplicates |
| **Natural key** | Business key (order number etc.) with unique constraint |
| State check | Check current state before processing; skip if already processed |
| Transaction | Maintain consistency between DB operations and queue operations |

```http
POST /payments
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
```

```go
// dedup table for duplicate elimination (event consumer side)
INSERT INTO event_dedup (event_id, processed_at)
VALUES ($1, now())
ON CONFLICT (event_id) DO NOTHING RETURNING event_id;
// Insert success → unprocessed; failure → duplicate skip
```

**Design notes**:
- Producer assigns UUID as event_id; carry through all paths
- Manage dedup table bloat with TTL/partitioning (e.g., retain 7 days only)
- TTL: delete fingerprint after ~24h (per IETF draft)
- Put business transaction and dedup insert in the **same DB tx** (separate DBs cause two-phase problems)

---

- Related: `backend/event-driven-architecture.md` (Kafka/streaming/exactly-once), `backend/distributed-transactions.md` (Outbox/Saga)
