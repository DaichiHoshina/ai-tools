# Scalability Patterns Guidelines

Reference for throughput limits, single point of failure, and horizontal/vertical scale decisions.

## Tier classification

| Tier | Content |
|------|---------|
| Tier 1 (required) | Read Replica, Circuit Breaker, Timeout |
| Tier 2 (scale-dependent) | Sharding, CQRS, Bulkhead |
| Tier 3 (advanced) | Event Sourcing, Geo-distributed, CRDT |

---

## 1. Scaling strategy selection

| Strategy | Use | Limits |
|----------|-----|--------|
| **Vertical scale** (scale-up) | DB primary; first option | Hard hardware ceiling; exponential cost |
| **Horizontal scale** (scale-out) | Stateless app, read replica | State management complexity |
| **Functional decomposition** (vertical decomp) | Monolith → service split | Communication overhead |
| **Data partitioning** (sharding) | Single DB at limit | Cross-shard operations difficult |

**Order**: vertical → horizontal → microservice → sharding (no premature optimization).

---

## 2. Read Replica + Eventual Consistency

```text
Write → Primary
Read → Replica (lag ~100ms)
```

| Issue | Fix |
|-------|-----|
| Read immediately after write | Client reads from Primary for 5s after write (cookie/header) |
| Read-your-write required | Session affinity, or record write timestamp |
| Replica lag monitoring | `pg_stat_replication.replay_lag` |
| Strong consistency read | Explicitly direct to Primary |

---

## 3. Sharding design

| Strategy | Mechanism | Pitfall |
|----------|-----------|---------|
| **Hash sharding** (recommended) | `hash(key) % N` | Reshard is difficult (consistent hashing helps) |
| **Range sharding** | Partition by key range | Hot range skew (time-series: latest shard gets all traffic) |
| **Geo sharding** | By region | Cross-region queries expensive |
| **Lookup table** | Dynamic mapping | Lookup itself becomes bottleneck |

**Shard key criteria**:
- **High cardinality** (diverse values)
- **Uniform distribution** (avoid hot key)
- **Includes frequent query predicates** (avoid cross-shard)

**Anti-patterns**:
- Monotonic ID (time-series ID) → latest shard hotspot
- Low cardinality (gender etc.) → shard count limitation
- Heavy aggregation/JOIN → cross-shard complexity

---

## 4. CQRS (Command Query Responsibility Segregation)

| Side | Role | DB |
|------|------|----|
| **Command** | Write, business logic | Normalized, TX-focused |
| **Query** | Read, display-oriented | Denormalized, read-optimized |

**Apply when**:
- Read/write ratio is **very asymmetric** (e.g., 100× more reads)
- **Complex aggregation queries** are frequent
- **Different consumers** (mobile vs admin dashboard)

**Cost**: sync delay, double implementation, eventual consistency required.

---

## 5. Event Sourcing

- Store **event history** rather than current state
- Reconstruct current state by replaying events

| Pros | Cons |
|------|------|
| Complete audit trail | Complex queries (snapshots required) |
| Time-travel debugging | Schema evolution difficult |
| Easy event-driven integration | High learning curve |

**Decision**: overkill unless audit is mandatory (finance, healthcare).

---

## 6. Circuit Breaker

```text
Closed (normal) → failure threshold exceeded → Open (instant fail)
                         ↓ timeout
                   Half-Open (probe) → success → Closed
                                     → failure → Open
```

| Parameter | Example |
|-----------|---------|
| Failure threshold | 50% / last 20 requests |
| Open duration | 30s |
| Half-Open probe count | 5 |

**Libraries**: resilience4j, sony/gobreaker, polly.

---

## 7. Bulkhead pattern

Isolate resources (thread pool, connection pool) **by function** so one function's failure does not cascade.

```text
[Order Service]
  - Normal API: pool A (size=20)
  - Reports:    pool B (size=5)  // isolate heavy processing
```

---

## 8. Timeout strategy

| Layer | Recommended timeout |
|-------|-------------------|
| HTTP client | 5-10s (user-facing) |
| DB query | 3-5s |
| Cache | 100-500ms |
| Inter-service | 1-3s |
| Background job | Per-job config (minutes to hours) |

**Rule**: upstream > downstream. Downstream retry must not exceed upstream timeout.

---

## 9. Backpressure

When producer outpaces consumer:

| Strategy | Mechanism |
|----------|-----------|
| **Drop** (log systems) | Discard old or new items |
| **Buffer + spill** | Memory full → disk |
| **Flow control** | Consumer sends credit/window signal (gRPC, Reactive) |
| **Rate limiting** | Throttle producer |

---

## 10. Capacity planning

**Base formula**:
```text
Required instances = (peak QPS × average latency) / concurrency per instance
```

Example: 1000 QPS, 200ms, 100 concurrency per instance → `(1000 × 0.2) / 100 = 2 instances` + headroom (×2-3)

**Little's Law**: `L = λ × W` (items in system = arrival rate × time in system)

**Monitor**: P99 latency, queue depth, CPU/memory, saturation.

---

## 11. Decision flow

```text
Throughput insufficient?
├─ DB read-heavy → Read Replica + caching
├─ DB write-heavy → Sharding (careful key design)
├─ Single service overloaded → Horizontal scale + LB
├─ Tight service coupling → Functional decomposition (microservice)
└─ Failure propagation → Circuit Breaker + Bulkhead + Timeout
```

---

## 12. References

- AWS Prescriptive Guidance (patterns)
- Designing Data-Intensive Applications (book)
- Related: `backend/distributed-transactions.md` (Saga), `backend/caching-strategies.md` (read optimization), `backend/multi-tenancy.md` (tenant_id shard key)
