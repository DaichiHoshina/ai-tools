# CQRS (Command Query Responsibility Segregation) Guidelines

> **Purpose**: Separate read and write paths so each side scales and evolves independently

## Core Principles

| Principle | Detail |
|-----------|--------|
| **Command / Query split** | Command mutates state, returns id/void. Query reads state, no side effect |
| **Model separation** | Write model = normalized, invariant-focused. Read model = denormalized, query-optimized |
| **Single direction** | Query never triggers write. Command never returns business data beyond id |
| **Asymmetric scaling** | Read and write scale independently (different DB / cache / replica count) |

---

## Maturity Levels

| Level | Write side | Read side | Sync | Use case |
|-------|-----------|-----------|------|----------|
| **L1 (light)** | Same DB, dedicated `CommandHandler` | Same DB, dedicated `QueryHandler` / view | Same transaction | Most projects start here |
| **L2 (medium)** | Primary DB | Read replica / dedicated read DB | Replication lag / async projector | Read QPS ≥ 5× write |
| **L3 (heavy)** | Event-sourced (events as source of truth) | Materialized views built from events | Event bus → projector | Audit-heavy, complex domain, multi-consumer |

> L1 covers most cases. Jump to L2/L3 only when the criteria in "When to Adopt" are met.

---

## Read / Write Model Separation

| Aspect | Write model | Read model |
|--------|------------|-----------|
| **Shape** | Normalized, aggregate-bound | Denormalized, view-bound (per use case) |
| **Schema** | Tight invariants, FK, NOT NULL | Loose, optimized for query plan |
| **Validation** | Business rules, domain invariants | Input shape only |
| **Lifecycle** | Mutated by Command | Rebuilt from write side (sync or async) |
| **Owner** | Domain layer | Application / view layer |

---

## Sync Strategies

| Strategy | Mechanism | Consistency | Cost |
|----------|-----------|-------------|------|
| **In-transaction** | Write + read view in same TX | Strong | Limits write throughput, couples schemas |
| **Replication** | DB-native primary→replica | Eventual (replica lag) | Lag handling required, but operationally cheap |
| **Event projection** | Domain event → projector → read DB | Eventual | Needs outbox / idempotent projector / replay path |
| **Hybrid** | Critical path in TX, the rest via events | Mixed | Routing logic per use case |

---

## Consistency Models

| Model | Guarantee | Typical use |
|-------|-----------|------------|
| **Strong** | Read sees latest write immediately | Money, inventory decrement, auth |
| **Read-your-write** | Same session sees own writes | User profile edit + redisplay |
| **Eventual** | Reads converge after some lag | Search index, dashboard, analytics |

> Pick per use case, not per service. Mixing inside one service is normal.

---

## Layer Mapping (Clean Architecture / DDD)

| Layer | Command path | Query path |
|-------|--------------|-----------|
| **Interface** | Controller → CommandHandler | Controller → QueryHandler |
| **Application** | `CommandHandler` (UseCase, TX boundary) | `QueryHandler` (DTO assembly, no domain logic) |
| **Domain** | Aggregate, invariant, domain event | Not used (read model bypasses domain) |
| **Infrastructure** | Repository (write), event publisher | Read DAO / query builder / cached view |

- Write path goes through Domain to keep invariants
- Read path may skip Domain entirely (project DTO directly from read store)
- Domain events flow Command → projector → read model (L2/L3)
- See `clean-architecture.md`, `domain-driven-design.md` for layer details

---

## When to Adopt

| Signal | Threshold |
|--------|-----------|
| **Read / write QPS ratio** | ≥ 5:1 (L2 candidate), ≥ 50:1 (L3 candidate) |
| **Read query complexity** | Aggregations, joins across aggregates, multi-consumer (mobile vs admin) |
| **Write complexity** | Domain logic concentrated, invariants span many fields |
| **Audit / replay need** | Regulatory audit, time-travel debugging → L3 (event-sourced) |
| **Team capacity** | Has distributed-system experience and on-call coverage |

## When NOT to Adopt

| Signal | Reason |
|--------|--------|
| **CRUD-heavy admin tool** | Splitting doubles maintenance with no scaling gain |
| **Read / write ratio near 1:1** | Replication / projection cost exceeds benefit |
| **Small team, no async ops experience** | Eventual consistency bugs are hard to debug |
| **No domain logic** | Domain layer is mostly empty → no invariant to protect |

---

## Anti-Patterns

| Case | NG | OK |
|------|----|----|
| **Scope** | Apply CQRS to every endpoint | Apply per bounded context / use case |
| **Command return** | Return aggregate / DTO from Command | Return id only (or void), client re-queries |
| **Query side effect** | Query writes audit log / updates cache TTL | Query is pure read, side effect via event |
| **Sync via cron** | Periodic SELECT + UPSERT for projection | Outbox + event publisher + idempotent projector |
| **Read model sprawl** | One read table per screen, hundreds of tables | Per bounded context, reuse across screens |
| **Strong consistency assumed** | Read-after-write code path with no wait | Read-your-write via session-pinned primary or version token |
| **Event without outbox** | Publish event inside TX before commit | Outbox pattern: insert event row in same TX, async publisher |
| **No replay path** | Read DB corruption requires manual repair | Projector idempotent, replay from event log rebuilds state |

---

## Migration Path (existing CRUD → CQRS)

| Step | Change | Reversible? |
|------|--------|------------|
| **1. Split handlers** | Separate `CommandHandler` / `QueryHandler` classes, same DB | Yes |
| **2. Split read model** | Add read-optimized views / read replica, route queries | Yes |
| **3. Async projection** | Move projection to event bus, accept eventual consistency | Hard (introduces lag) |
| **4. Event sourcing** | Events become source of truth, current state derived | No (schema redesign) |

> Stop at the lowest step that meets the signal. Each step adds operational cost.

---

## Combination with Event Sourcing

CQRS and Event Sourcing are independent patterns. CQRS at L1/L2 uses state-based storage. ES becomes natural at L3 when audit / replay / time-travel are required. See `backend/event-driven-architecture.md` for event-side detail.

---

## Related

- `clean-architecture.md` — layer dependency direction
- `domain-driven-design.md` — aggregate, domain event, bounded context
- `backend/scalability-patterns.md` — tier classification (CQRS is Tier 2)
- `backend/event-driven-architecture.md` — outbox, projector, event bus
- `backend/distributed-transactions.md` — saga, eventual consistency handling
- `languages/golang.md` §CQRS — Go-specific signature, Unit of Work, mock generation
