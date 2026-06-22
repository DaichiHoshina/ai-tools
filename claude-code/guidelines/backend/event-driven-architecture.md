# Event-Driven Architecture Guidelines

> **Purpose**: Reference for async messaging design with Kafka/RabbitMQ/SQS/PubSub etc. For simple batch jobs, see `design/async-job-patterns.md`. For TX consistency, see `backend/distributed-transactions.md`.

## Tier classification

| Tier | Content |
|------|---------|
| Tier 1 (required) | Broker selection, topic/partition design, consumer group, delivery semantics |
| Tier 2 (scale-dependent) | Exactly-once impl, DLQ, retry strategy, schema registry, backpressure |
| Tier 3 (advanced) | Event Sourcing, CDC, stream processing, transactional messaging |

---

## 1. Broker selection (2025-2026)

| Broker | Strengths | Weaknesses | Typical use |
|--------|-----------|-----------|-------------|
| **Kafka** | High throughput (M msg/s), partition order, long retention, ecosystem | Heavy ops; exactly-once requires transactional API | Event streaming, log aggregation, CDC |
| **Redpanda** | Kafka API compatible, lightweight (C++, no ZooKeeper), low latency | Newer; OSS version has feature limits | Kafka replacement, low-latency use |
| **RabbitMQ** | Flexible routing (exchange), low latency, easy ops | Order guarantee per queue only; medium throughput | Task queue, RPC, notification fan-out |
| **AWS SQS Standard** | Fully managed, infinite scale | No order guarantee; at-least-once | Serverless, loosely coupled tasks |
| **AWS SQS FIFO** | Order guarantee (MessageGroupId), dedup | Low throughput (3,000 msg/s/group) | Order-critical, low-throughput |
| **AWS SNS + SQS** | Pub/Sub fan-out + persistence | Complex setup | Multi-subscriber notification |
| **Google Pub/Sub** | Fully managed, ack deadline control, exactly-once delivery (Pull) | GCP only | Event routing in GCP |
| **NATS JetStream** | Lightweight, low latency, stream + KV | Small ecosystem | IoT, edge, low-latency RPC |

**Decision axes**: ordering requirement / throughput / retention / ops cost / vendor lock (5 axes). Default: Kafka-compatible (Kafka / Redpanda / MSK).

---

## 2. Topic / partition design

**Principle**: partition = ordering unit = parallelism ceiling.

| Concern | Guidance |
|---------|---------|
| Partition key | Same entity events to same partition (e.g., `user_id`, `order_id`) |
| Partition count | Match max consumer parallelism. **Easy to increase; impossible to decrease**. Initial: 2-3× expected throughput |
| Hot partition prevention | Check key distribution (`kafka-consumer-groups --describe`); add salt to equalize |
| Topic naming | `{domain}.{entity}.{event}` (e.g., `order.v1.placed`, `user.v1.email_changed`) |
| Retention | Event sourcing → long-term (unlimited or compact); notification → ~7 days |

**Cross-partition ordering is not guaranteed.** Use single partition (low throughput) or timestamp+merge for custom ordering.

---

## 3. Consumer group and delivery semantics

| Semantics | Implementation | Use | Caution |
|-----------|---------------|-----|---------|
| **at-most-once** | Auto commit before processing | Metrics, loss-tolerant | Data loss |
| **at-least-once** (recommended) | Manual commit after processing | General OLTP | **Consumer must be idempotent** |
| **exactly-once** | Kafka transactional producer + read_committed / SQS FIFO + dedup / Transactional Outbox | Finance, inventory | High perf cost |

**Consumer rebalance**: Use **cooperative sticky** (2.4+) for Kafka; old eager rebalance triggers stop-the-world full revoke. Set `partition.assignment.strategy=org.apache.kafka.clients.consumer.CooperativeStickyAssignor`.

**1 partition = max 1 consumer**. Consumers exceeding partition count are idle.

---

## 4. Idempotent consumer (at-least-once receiver)

See [design/async-job-patterns.md#ensuring-idempotency](../design/async-job-patterns.md#ensuring-idempotency) for implementation patterns.

---

## 5. Transactional Outbox (producer-side exactly-once practical solution)

Ensures atomicity of DB update and event publish.

| Step | Processing |
|------|-----------|
| 1 | Business update + `outbox` table INSERT in **same TX** commit |
| 2 | Separate process (relay/poller or Debezium CDC) reads outbox → publishes to broker |
| 3 | On publish success: delete or mark outbox row |

**Pros**: No 2PC required; DB and broker stay consistent. **Cons**: relay delay (ms to seconds); outbox table management.

CDC (Debezium etc.) can read the outbox, eliminating the need for a custom relay.

---

## 6. DLQ (Dead Letter Queue)

See [design/async-job-patterns.md#dlq-dead-letter-queue-design](../design/async-job-patterns.md) for details.

---

## 7. Schema evolution

Avro / Protobuf / JSON Schema + **Schema Registry** (Confluent, Apicurio).

| Compatibility mode | Meaning | Use |
|-------------------|---------|-----|
| **BACKWARD** (default) | New schema reads old data | Consumer-first deploy |
| **FORWARD** | Old schema reads new data | Producer-first deploy |
| **FULL** | Bidirectional compatible | Most strict; recommended |
| **NONE** | Arbitrary change | Temporary when breaking |

**Breaking changes**:
- Add required field → breaks FORWARD
- Delete field → breaks BACKWARD
- Change type → breaks FULL

→ Major version bump + **dual write** (old + new topics in parallel); stop old after consumer migration.

---

## 8. CDC (Change Data Capture)

Convert DB changes to events and propagate to other systems.

| Tool | Target | Mechanism |
|------|--------|-----------|
| **Debezium** | MySQL binlog, PostgreSQL WAL, MongoDB oplog | Via Kafka Connect to broker |
| **AWS DMS** | Various DBs | CDC mode to S3/Kinesis |
| **Native logical replication** (PG) | PostgreSQL | publication/subscription |

**Snapshot + incremental**: initial full snapshot, then incremental (WAL/binlog).

**Outbox vs CDC**: Outbox = explicit event design at app layer; CDC = stream DB changes directly. Outbox preferred (clear event contract; resilient to internal column changes).

---

## 9. Backpressure and lag mitigation

| Monitoring metric | Guidance |
|------------------|---------|
| Consumer lag (`kafka-consumer-groups`) | Steadily increasing → scale horizontally |
| `/sched/latencies` (Go) | Internal processing wait in consumer |
| `max.poll.records` | Reduce to lighten per-batch processing |

**Mitigation priority**:
1. Add consumer instances (up to partition count)
2. Parallelize processing (goroutine pool, worker pool)
3. Increase partition count (requires rebalance; check downtime)
4. Offload heavy processing (separate topic + consumer)

---

## 10. Anti-patterns

| Avoid | Use instead | Reason |
|-------|-------------|--------|
| Queue as long-term store | Event sourcing or DB | Broker retention is finite by design |
| Timestamp as partition key | Entity ID | Hot partition (all traffic at latest timestamp) |
| Blocking heavy DB writes in consumer | Worker pool or separate topic | Lag increases |
| Breaking schema change without notice | Schema Registry + migration doc | Risks consumer downtime |
| Large payload in event | ID only + DB lookup (claim check pattern) | Broker size limits, network cost |
| Custom exactly-once impl | Kafka transactional producer / Outbox | Corner-case bugs break consistency |
| DLQ not monitored | Count SLO + replay flow | Bugs silently cause data loss |

---

## 11. References

- Confluent: Kafka official docs, Schema Registry
- "Designing Data-Intensive Applications" (Martin Kleppmann)
- "Enterprise Integration Patterns" (Hohpe & Woolf)
- Debezium official, AWS SQS/SNS official
- Related: `backend/distributed-transactions.md` (Saga/Outbox consistency), `design/async-job-patterns.md` (task queue), `backend/observability-design.md` (consumer lag monitoring), `design/cqrs.md` (read/write split + event projection)
