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

Full DLQ design (mandatory config, alarms, replay procedure): `../languages/async-messaging.md` §DLQ.

Backoff for this repo's workers: exponential, 1s → 4s → 16s.

## Ensuring Idempotency

Full idempotency strategy comparison (dedup table / conditional update / natural key upsert / outbox): `../languages/async-messaging.md` §Idempotency.

Go/Postgres dedup table used in this repo's consumers:

```go
INSERT INTO event_dedup (event_id, processed_at)
VALUES ($1, now())
ON CONFLICT (event_id) DO NOTHING RETURNING event_id;
// Insert success → unprocessed; failure → duplicate skip
```

Put the business transaction and the dedup insert in the **same DB tx**; TTL the dedup table (~24h) to bound growth.

---

- Related: `../languages/async-messaging.md` (SQS/Pub-Sub, DLQ, idempotency, ordering — canonical for messaging-level design), `backend/event-driven-architecture.md` (Kafka/streaming/exactly-once), `backend/distributed-transactions.md` (Outbox/Saga)
