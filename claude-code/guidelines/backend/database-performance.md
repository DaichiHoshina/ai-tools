# DB Performance Guidelines

> **Purpose**: Reference for query latency, throughput limits, and production DB investigation. **PostgreSQL 16-18 only** (PG-specific: pg_stat_statements / EXPLAIN BUFFERS). For MySQL/InnoDB, see `backend/mysql-performance.md`.

## Tier classification

| Tier | Content |
|------|---------|
| Tier 1 (required) | EXPLAIN, index basics, N+1 detection, connection pool |
| Tier 2 (scale-dependent) | Partitioning, partial index, covering index |
| Tier 3 (advanced) | Force query plan, HOT update, bloat management |

---

## 1. "DB slow" — 5-step diagnosis

| Step | Check | Command/Tool |
|------|-------|--------------|
| 1 | EXPLAIN ANALYZE execution plan | `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) <query>` |
| 2 | Seq scan vs index scan | `Seq Scan` / `Index Scan` in plan |
| 3 | N+1 occurrence | Query log count, ORM eager load config |
| 4 | Connection pool saturation | `SHOW POOLS;` (PgBouncer) / `pg_stat_activity` |
| 5 | Cache hit rate | `pg_statio_user_tables.heap_blks_hit / (hit + read)` |

---

## 2. Reading EXPLAIN (PG 18 updates included)

| Plan element | Meaning | Action |
|-------------|---------|--------|
| `Seq Scan` | Full table scan | Consider index on WHERE column |
| `Index Scan` | Index used | OK (check Buffers; consider covering if large) |
| `Bitmap Heap Scan` | Multiple index merge | Consolidate with composite index |
| `Hash Join` | In-memory hash join | Check `work_mem`; expand if disk spill |
| `Nested Loop` + large rows | N×M executions | Swap join order, add index |
| `rows estimated` large gap | Stale statistics | Run `ANALYZE <table>` |

**PG 18**: row estimation improved to 0.15 granularity; Memory/Disk spill display standardized.

---

## 3. Index design

| Type | Use | Example |
|------|-----|---------|
| **B-tree** (default) | Equality, range, ORDER BY | `WHERE created_at > ?`, `ORDER BY id` |
| **Hash** | Equality only (no range) | `WHERE token = ?` (B-tree often sufficient) |
| **GIN** | Array/JSONB/full-text | `WHERE tags @> ARRAY['x']` |
| **BRIN** | Time-series, sequential values | Large log table, `WHERE ts BETWEEN ...` |

**Design rules**:
- Column order = matches WHERE/JOIN/ORDER BY predicate order
- Composite `(a, b)` works for `WHERE a = ?`; `WHERE b = ?` alone does not
- Covering index (INCLUDE) for index-only scan
- Drop unused indexes periodically (`pg_stat_user_indexes.idx_scan = 0`)

```sql
CREATE INDEX idx_orders_user_status ON orders (user_id, status) INCLUDE (total);
```

---

## 4. N+1 detection and fix

| ORM | Detection | Fix |
|-----|-----------|-----|
| Prisma | `@prisma/sqlcommenter` SQL trace | `include`, `select` for eager load |
| GORM | `gorm.io/plugin/prometheus` query count metric | `Preload("Relation")` |
| SQLAlchemy | `sqlalchemy.event` query count log | `joinedload`, `selectinload` |
| DataLoader | - | Batch loader pattern for single query |

**Threshold**: same-type query N>10 per request → fix immediately.

---

## 5. Connection pool sizing

| Setting | Formula | Example (4 cores, 100 backends) |
|---------|---------|----------------------------------|
| App pool max | `(CPU cores × 2) + 1` | 9 |
| PgBouncer `default_pool_size` | 10-25 / DB | 25 |
| PgBouncer `max_client_conn` | app real max × backend count | 1000 |
| `reserve_pool_size` | Admin use | 5 |

**Monitor**: PgBouncer `SHOW POOLS;` — `cl_waiting > 0` persisting → pool insufficient, expand.

---

## 6. Slow query operation

```sql
-- Log queries over 1 second
ALTER SYSTEM SET log_min_duration_statement = '1000';
SELECT pg_reload_conf();

-- Top queries by total time
SELECT query, calls, mean_exec_time, total_exec_time
FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10;
```

**Alert threshold example**: P95 latency > 200ms for 5 minutes → Slack notification.

---

## 7. Partitioning

| Strategy | Use | Key example |
|----------|-----|-------------|
| **Range (time-series)** | Delete/aggregate old data | `created_at` monthly |
| **Hash** | Uniform distribution, avoid hot partition | `user_id` |
| **List** | Explicit category separation | `region = 'jp'/'us'` |

**Threshold**: single table > 100M rows, or only recent data accessed frequently → consider Range partition.

---

## 8. Common anti-patterns

| Avoid | Use instead | Reason |
|-------|-------------|--------|
| `SELECT *` | List required columns | Reduces I/O; enables index-only scan |
| `OFFSET 100000` | Cursor-based (`WHERE id > last_id`) | OFFSET scans all preceding rows |
| Multiple round-trips per request | Batch / JOIN | Latency accumulates |
| ORM lazy load unchecked | Explicit eager load | N+1 source |
| Index on every column | Required columns only; consider composite | Write overhead |
| Large transactions | Split into smaller | Reduces lock duration |

---

## 9. References

- PostgreSQL 18 EXPLAIN: future-architect.github.io/articles/20251008a/
- Prisma Query Optimization docs
- PgBouncer admin docs
- Related: `backend/distributed-transactions.md` (isolation levels), `backend/caching-strategies.md` (cache first)
