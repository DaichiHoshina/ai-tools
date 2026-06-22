# Async Messaging Guidelines

> **Purpose**: AWS SQS (primary) + Google Cloud Pub/Sub v2 (secondary, when GCP-native services already exist). Common guidelines: `~/.claude/guidelines/common/`. Related: `languages/go-concurrency.md` (goroutine + ctx lifecycle).

## Core Principles

- **At-least-once delivery** is the baseline — duplicates are normal, design consumers to be **idempotent**
- **Producer commits before publish, never after**: publish from inside the DB transaction = lost-update on rollback; publish *after* commit via outbox or post-commit hook
- **Consumer**: process → ack on success; let ack timeout / nack on transient error so the broker retries
- **Visibility timeout / ack deadline must cover p99 processing time** with margin; otherwise the broker redelivers while you are still working
- **Dead Letter Queue (DLQ) is mandatory**: after N redeliveries, move the message off the main queue so it stops blocking the consumer
- **Ordering is a feature you opt into**, not a default. Default to "ordering not guaranteed" and design accordingly

## Choosing AWS SQS vs GCP Pub/Sub

| Aspect | AWS SQS | GCP Pub/Sub |
|--------|---------|-------------|
| Model | Queue (point-to-point) | Topic + multiple subscriptions (pub/sub fan-out) |
| Multiple consumers per message | Use SNS → SQS fan-out | Native (one topic → N subscriptions) |
| Ordering | FIFO queue with `MessageGroupId` only | Ordering keys (per-key in-order, cross-key parallel) |
| Exactly-once | FIFO queue dedup window 5 min | Subscription-level exactly-once delivery (best-effort window) |
| Max message size | 256 KB (Extended Client → S3 for larger) | 10 MB |
| Visibility / ack | Visibility timeout (default 30s) | Ack deadline (default 10s, modack to extend) |
| Default pick | **AWS SQS** when AWS is the primary cloud | **Pub/Sub** for fan-out, GCP-native source events |

**Default**: AWS SQS for general async work in AWS workloads. Pub/Sub only when the producer is already a GCP service (e.g., Cloud Run / Vertex AI event) or when fan-out to multiple independent subscribers is required.

## Idempotency

Every consumer MUST be idempotent. Pick one strategy:

| Strategy | Pattern | Trade-off |
|----------|---------|-----------|
| **Idempotency key + dedup table** | Producer attaches `idempotencyKey`; consumer `INSERT ... ON DUPLICATE KEY UPDATE` into a dedup table inside the work transaction | Simple, durable; requires DB write |
| **Conditional update** | `UPDATE rows SET … WHERE state = 'pending'` — second delivery is a no-op | No extra table, but only fits state-machine work |
| **Natural key upsert** | `INSERT … ON DUPLICATE KEY UPDATE` keyed on business identifier | No extra metadata; needs schema support |
| **Outbox + relay** | Producer writes event to outbox table inside business TX; separate relay publishes once committed | Solves dual-write; needs relay process |

Anti-patterns: in-memory dedup map (lost on restart), "we'll just turn off retries" (breaks at-least-once guarantee).

## Producer (publish)

### Outbox pattern (recommended for cross-system events)

```text
business TX {
  UPDATE order SET status = 'paid';
  INSERT INTO outbox (id, topic, payload) VALUES (...);
}
COMMIT;

-- relay (separate process, polling or CDC):
SELECT * FROM outbox WHERE published_at IS NULL;
publish(...);
UPDATE outbox SET published_at = NOW() WHERE id = ?;
```

Solves: "DB committed but publish failed" / "published but DB rolled back" dual-write race.

### Post-commit publish (lighter, less safe)

If outbox is overkill, publish *after* `tx.Commit()` returns. Accept that a crash between commit and publish loses the event — only suitable when downstream can reconcile by polling.

### Producer rules

- Do **not** publish inside the business transaction (publish succeeds → TX rolls back = ghost event)
- Set `messageId` / `idempotencyKey` attribute so the consumer can dedupe
- Include schema version (`v` field) — events outlive your code
- Keep payload small (< 256 KB SQS / < 10 MB Pub/Sub); reference S3/GCS for large blobs

## Consumer

### Loop shape

```text
for {
  msgs := receive(ctx, batchSize)
  for each msg in msgs (concurrently, bounded) {
    if idempotencyCheck(msg) == alreadyProcessed { ack; continue }
    err := process(ctx, msg)
    if err == transient { nack (let it redeliver) }
    else if err == permanent { ack + log + DLQ-route or skip }
    else { recordProcessed(msg); ack }
  }
}
```

### Visibility timeout / ack deadline

- Set to **p99 processing time × 2** with a floor (e.g., 30s)
- Extend during long work: SQS `ChangeMessageVisibility`, Pub/Sub `ModifyAckDeadline` (or use the client library's lease management)
- Too short → duplicate processing storms; too long → DLQ takes forever to trigger after a real failure

### Concurrency

- Bound concurrent in-flight messages (semaphore / `errgroup` with limit) — receiving 1000 messages but spawning 1000 goroutines starves DB connections and CPU
- Use a per-consumer prefetch / `MaxNumberOfMessages` matched to processing throughput
- See `languages/go-concurrency.md` for goroutine lifecycle and leak prevention

### Error classification

| Error | Action | Example |
|-------|--------|---------|
| Transient (retryable) | Nack / let visibility expire → broker redelivers | DB timeout, downstream 5xx, network blip |
| Permanent (poisonous) | Ack + route to DLQ / log + skip | malformed payload, schema mismatch, business invariant violation |
| Ambiguous | Default to transient (broker retries are cheaper than dropped events) | unknown 4xx |

Anti-pattern: `catch err; log; ack` — silently drops every error including transient ones.

## DLQ (Dead Letter Queue)

- **Mandatory** on every queue / subscription handling business-critical events
- SQS: configure `RedrivePolicy` with `maxReceiveCount` (typically 3–5)
- Pub/Sub: configure `deadLetterPolicy` with `maxDeliveryAttempts` (≥ 5)
- DLQ depth must be alarmed — silent DLQ growth = silent data loss
- Have a documented replay procedure (re-drive DLQ → main queue after fixing the bug)

## Ordering

Default: **no ordering**. If a use case truly needs it:

| Need | AWS SQS | GCP Pub/Sub |
|------|---------|-------------|
| Global FIFO | FIFO queue, single `MessageGroupId` (throughput cap ~300 msg/s) | Single ordering key (per-key serial) |
| Per-entity ordering | FIFO queue, `MessageGroupId = entityId` | `OrderingKey = entityId` (per-key serial, cross-key parallel) |
| No ordering | Standard queue (default) | No ordering key |

Per-entity ordering is the practical sweet spot: keeps work parallel across entities while preserving per-entity order. Avoid global FIFO unless absolutely required (it's a hard throughput cap and a single-consumer chokepoint).

## Testing

- **Unit**: mock the publisher; assert correct topic / attributes / payload schema
- **Integration**: LocalStack (SQS) or Pub/Sub emulator (`gcloud beta emulators pubsub`) — never hit real prod
- **Idempotency test**: feed the same message twice, assert exactly-once effect on state
- **Poison message test**: feed malformed payload, assert it goes to DLQ within `maxReceiveCount` attempts
- **Crash-recovery test**: kill the consumer mid-process, restart, assert the message is reprocessed and ends consistent

## Observability

- Per-message: emit `messageId`, `idempotencyKey`, `attemptCount` in logs (structured, e.g., `slog`)
- Metrics: receive rate, ack rate, nack rate, DLQ depth, e2e latency (publish → ack), processing duration p50/p95/p99
- Tracing: propagate trace context via message attributes (W3C `traceparent`); link producer span to consumer span
- Alarms: DLQ depth > 0 (warning), DLQ depth growing (critical), main queue age > SLO

## Common Mistakes

| Avoid | Use | Reason |
|-------|-----|--------|
| Publish inside DB TX | Outbox or post-commit publish | TX rollback → ghost event |
| Ack before processing | Ack only after successful commit of side effects | crash between ack and work = lost message |
| No DLQ on production queue | `maxReceiveCount` + DLQ + alarm on depth | poison message blocks consumer forever |
| Visibility = 30s for 60s work | Set to p99 × 2 or extend mid-work | duplicate processing storm |
| Unbounded goroutines per batch | Semaphore / `errgroup` with limit | resource exhaustion |
| In-memory dedup map | Persistent dedup table or natural key upsert | lost on restart |
| Default to FIFO "for safety" | Standard queue + idempotent consumer | FIFO throughput cap (300 msg/s) is a real ceiling |
| Same topic for events + commands | Split: events (past tense, fan-out) vs commands (target one handler) | conflated semantics |
| Schema-less payload | Versioned schema (`v` field, proto / JSON Schema) | events outlive code; old consumers need to coexist |

## SDK Quick Reference (Go)

### AWS SQS (`aws-sdk-go-v2/service/sqs`)

```go
client := sqs.NewFromConfig(cfg)

// Receive (long-polling)
out, err := client.ReceiveMessage(ctx, &sqs.ReceiveMessageInput{
  QueueUrl:            &queueURL,
  MaxNumberOfMessages: 10,
  WaitTimeSeconds:     20,             // long poll
  VisibilityTimeout:   60,             // p99 × 2
})

// Delete = ack
_, err = client.DeleteMessage(ctx, &sqs.DeleteMessageInput{
  QueueUrl: &queueURL, ReceiptHandle: msg.ReceiptHandle,
})

// Extend visibility mid-work
_, err = client.ChangeMessageVisibility(ctx, &sqs.ChangeMessageVisibilityInput{
  QueueUrl: &queueURL, ReceiptHandle: msg.ReceiptHandle,
  VisibilityTimeout: 120,
})
```

### GCP Pub/Sub v2 (`cloud.google.com/go/pubsub/v2`)

```go
client, _ := pubsub.NewClient(ctx, projectID)

// Publish
publisher := client.Publisher("topic-name")
result := publisher.Publish(ctx, &pubsub.Message{
  Data:        payload,
  OrderingKey: entityID,                 // optional, per-key ordering
  Attributes:  map[string]string{"idempotencyKey": key, "v": "1"},
})
_, err := result.Get(ctx)                // block to surface publish errors

// Subscribe (library manages ack-deadline lease automatically)
subscriber := client.Subscriber("subscription-name")
err = subscriber.Receive(ctx, func(ctx context.Context, m *pubsub.Message) {
  if err := process(ctx, m); err != nil {
    m.Nack()                              // retry
    return
  }
  m.Ack()
})
```

## References

- AWS SQS developer guide: docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/
- GCP Pub/Sub overview: cloud.google.com/pubsub/docs/overview
- Outbox pattern: microservices.io/patterns/data/transactional-outbox.html
