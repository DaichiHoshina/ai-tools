# Guideline Triggers — Subtopic Keyword Detection Table

Referenced by `load-guidelines` skill when subtopic triggers fire. When the following keywords appear in task text / changes, load the corresponding guideline. **Do not load in bulk** (only 1-2 relevant files).

## Design subtopics

| Trigger keywords | Load |
|------------------|---------|
| queue, worker, cron, async job, job scheduler | `~/.claude/guidelines/design/async-job-patterns.md` |

## Backend subtopics

| Trigger keywords | Load |
|------------------|---------|
| slow query, index, N+1, connection pool, PostgreSQL, pg_stat | `~/.claude/guidelines/backend/database-performance.md` |
| MySQL, InnoDB, EXPLAIN FORMAT=JSON, buffer pool, GTID, online DDL, redo log | `~/.claude/guidelines/backend/mysql-performance.md` |
| EXPLAIN (DBMS unknown) | Load both above (narrow after DBMS confirmed) |
| cache, Redis, TTL, stampede | `~/.claude/guidelines/backend/caching-strategies.md` |
| transaction, saga, isolation, deadlock, idempotency | `~/.claude/guidelines/backend/distributed-transactions.md` |
| SLO, SLI, tracing, OpenTelemetry, observability | `~/.claude/guidelines/backend/observability-design.md` |
| OWASP, rate limit, secret, mTLS, authn, authz | `~/.claude/guidelines/backend/security-hardening.md` |
| scale, sharding, read replica, circuit breaker, bulkhead | `~/.claude/guidelines/backend/scalability-patterns.md` |
| Kafka, Redpanda, RabbitMQ, event-driven, partition, consumer group, schema registry, Debezium, CDC | `~/.claude/guidelines/backend/event-driven-architecture.md` |
| SQS, SNS, Pub/Sub, DLQ, visibility timeout, ack deadline, exactly-once, outbox, consumer idempotency | `~/.claude/guidelines/languages/async-messaging.md` |
| multi-tenant, tenancy, tenant_id, RLS, row-level security, SaaS isolation, schema-per-tenant, database-per-tenant | `~/.claude/guidelines/backend/multi-tenancy.md` |

## Language deep-dive subtopics

| Trigger keywords | Load |
|------------------|---------|
| escape analysis, pprof, GOGC, GOMEMLIMIT, sync.Pool, PGO, allocation, benchstat | `~/.claude/guidelines/languages/go-performance.md` |
| goroutine, GOMAXPROCS, scheduler, channel buffer, leak, mutex contention, race condition | `~/.claude/guidelines/languages/go-concurrency.md` |

## Usage principles

- If task contains no keywords, do not load (token savings)
- When multiple keywords hit, narrow to most relevant 1-2 files
- When adding new guidelines, update only this table — no changes needed to skill body
