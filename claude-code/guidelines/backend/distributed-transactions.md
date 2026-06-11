# Distributed Transactions Guidelines

Reference for consistency guarantees across multiple services/DBs, deadlock handling, and optimistic/pessimistic lock decisions.

## Tier classification

| Tier | Content |
|------|---------|
| Tier 1 (required) | Isolation level selection, optimistic lock, idempotency |
| Tier 2 (scale-dependent) | Saga (orchestration/choreography), Outbox |
| Tier 3 (advanced) | 2PC, Event Sourcing, CRDT |

---

## 1. Isolation level selection (PostgreSQL)

| Level | Prevents | Recommended use | Cost |
|-------|----------|----------------|------|
| **Read Uncommitted** | (PG: effectively Read Committed) | - | - |
| **Read Committed** (default) | Dirty read | General OLTP | Low |
| **Repeatable Read** | + non-repeatable read, phantom (in PG) | Aggregates, reports | Medium; serialization failure possible |
| **Serializable** (SSI) | All anomalies | Finance, inventory | High; retry required |

**Decision**:
- Simple CRUD → Read Committed
- Multiple reads in same TX → Repeatable Read
- True consistency required (balance/inventory) → Serializable + retry

---

## 2. Optimistic vs pessimistic lock

| Type | Mechanism | Use | Example |
|------|-----------|-----|---------|
| **Optimistic** | Validate version column in WHERE; UPDATE failure → retry | Low contention | Product edit, settings |
| **Pessimistic** (SELECT FOR UPDATE) | Acquire row lock | High contention, short TX | Inventory deduction, seat reservation |

**Optimistic lock implementation**:
```sql
UPDATE orders SET status='paid', version=version+1
WHERE id=? AND version=?;  -- 0 rows updated → conflict, retry
```

**Pessimistic lock caution**: never hold long; keep TX short; handle deadlocks.

---

## 3. Deadlock handling

| Strategy | Detail |
|----------|--------|
| **Unified lock order** | All TXs acquire locks in same order (e.g., ascending id) |
| **Timeout** | `SET lock_timeout = '3s'` to give up |
| **Retry with backoff** | Exponential backoff on deadlock detection |
| **Smaller granularity** | Row lock < table lock |

```go
for i := 0; i < 3; i++ {
    err := tx.Run()
    if isDeadlock(err) { time.Sleep(jitter(i)); continue }
    return err
}
```

---

## 4. Saga pattern

Decompose long TXs into "a chain of compensatable small TXs".

| Type | Control | Pros | Cons |
|------|---------|------|------|
| **Orchestration** | Central orchestrator directs each step | High visibility, easy debug | SPOF, coupling |
| **Choreography** | Event-driven, each service self-directed | Loose coupling, scalable | Hard to grasp overall flow |

**Implementation rules**:
- Each step requires a corresponding **compensating action**
- On failure, execute compensation in **reverse order**
- Persist intermediate state to DB (crash recovery)
- Compensating actions must also be idempotent

**Example (order)**:
```text
Reserve seat → Payment → Arrange shipping
Compensation: Cancel shipping → Refund → Release seat
```

---

## 5. Transactional Outbox pattern

Guarantees atomicity of DB TX and message publish. See [event-driven-architecture.md#5-transactional-outbox-producer-side-exactly-once-practical-solution](./event-driven-architecture.md) for details.

---

## 6. Idempotency

See [design/async-job-patterns.md#idempotency](../design/async-job-patterns.md) for implementation patterns.

---

## 7. Delivery guarantees

| Type | Mechanism | Use |
|------|-----------|-----|
| **At-most-once** | Fire-and-forget | Metrics (loss acceptable) |
| **At-least-once** (recommended default) | Ack after commit; failure → resend | + receiver idempotency required |
| **Exactly-once** (practical) | Kafka TX + idempotent producer | Strict consistency (high cost) |

**Practical solution**: At-least-once + idempotent processing = "Effectively-once".

---

## 8. 2PC (Two-Phase Commit)

- prepare → commit in 2 phases across all resources
- Coordinator failure causes blocking
- For cross-DB use, prefer Saga in modern systems; 2PC limited to same-DBMS scenarios

---

## 9. Decision flow

```text
Distributed consistency needed?
├─ No → Single DB TX + appropriate isolation level
└─ Yes
   ├─ Reversible operations (compensatable) → Saga
   ├─ Event ordering critical → Outbox + ordered broker
   └─ Strong consistency required (same DBMS) → 2PC (last resort)
```

---

## 10. References

- PG Transaction Isolation official docs
- Saga: ByteByteGo
- Outbox: AWS Prescriptive Guidance
- Idempotency Key RFC: IETF draft
- Related: `design/async-job-patterns.md` (DLQ), `backend/observability-design.md` (trace correlation), `backend/event-driven-architecture.md` (Outbox/Kafka impl)
