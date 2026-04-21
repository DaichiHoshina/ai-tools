# Guideline Triggers - サブトピックキーワード検出表

`load-guidelines` skill からサブトピック発火時に参照。タスク本文/変更内容に以下キーワードを検出した場合、該当ガイドラインを追加読込する。**一括投入禁止**（該当1-2本のみ）。

## 設計サブトピック

| トリガーキーワード | 追加読込 |
|------------------|---------|
| queue, worker, cron, 非同期ジョブ, job scheduler | `~/.claude/guidelines/design/async-job-patterns.md` |

## バックエンドサブトピック

| トリガーキーワード | 追加読込 |
|------------------|---------|
| slow query, index, N+1, connection pool, PostgreSQL, pg_stat | `~/.claude/guidelines/backend/database-performance.md` |
| MySQL, InnoDB, EXPLAIN FORMAT=JSON, buffer pool, GTID, online DDL, redo log | `~/.claude/guidelines/backend/mysql-performance.md` |
| EXPLAIN（DBMS不明） | 上記2つ両方読込（DBMS確認後に絞る） |
| cache, Redis, TTL, stampede | `~/.claude/guidelines/backend/caching-strategies.md` |
| transaction, saga, isolation, deadlock, idempotency | `~/.claude/guidelines/backend/distributed-transactions.md` |
| SLO, SLI, tracing, OpenTelemetry, observability | `~/.claude/guidelines/backend/observability-design.md` |
| OWASP, rate limit, secret, mTLS, authn, authz | `~/.claude/guidelines/backend/security-hardening.md` |
| scale, sharding, read replica, circuit breaker, bulkhead | `~/.claude/guidelines/backend/scalability-patterns.md` |
| Kafka, Redpanda, RabbitMQ, SQS, SNS, Pub/Sub, event-driven, partition, consumer group, DLQ, exactly-once, schema registry, Debezium, CDC | `~/.claude/guidelines/backend/event-driven-architecture.md` |
| multi-tenant, tenancy, tenant_id, RLS, row-level security, SaaS分離, schema-per-tenant, database-per-tenant | `~/.claude/guidelines/backend/multi-tenancy.md` |

## 言語深堀りサブトピック

| トリガーキーワード | 追加読込 |
|------------------|---------|
| escape analysis, pprof, GOGC, GOMEMLIMIT, sync.Pool, PGO, allocation, benchstat | `~/.claude/guidelines/languages/go-performance.md` |
| goroutine, GOMAXPROCS, scheduler, channel buffer, leak, mutex contention, race condition | `~/.claude/guidelines/languages/go-concurrency.md` |

## 利用原則

- タスクにキーワード含まれない場合は読込しない（トークン節約）
- 複数キーワードヒット時は最も関連性の高い1-2本に絞る
- 新規ガイドライン追加時はこの表のみ更新、skill 本体は変更不要
