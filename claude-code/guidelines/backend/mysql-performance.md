# MySQL/InnoDB Performance Guidelines

Reference for query latency, throughput limits, and production MySQL investigation. Assumes **MySQL 8.4 LTS / InnoDB**. For PostgreSQL, see `backend/database-performance.md`.

## Tier classification

| Tier | Content |
|------|---------|
| Tier 1 (required) | EXPLAIN, PK/clustered index, N+1, isolation level |
| Tier 2 (scale-dependent) | Lock types, buffer pool, Online DDL, partition |
| Tier 3 (advanced) | Deadlock analysis, MVCC/undo, InnoDB internals (AHI/change buffer/doublewrite), 2PC group commit, hot row mitigation |

---

## 1. "MySQL slow" — 5-step diagnosis

| Step | Check | Command |
|------|-------|---------|
| 1 | EXPLAIN (execution plan) | `EXPLAIN FORMAT=JSON <query>` |
| 2 | Actual cost | `EXPLAIN ANALYZE <query>` (8.0.18+) |
| 3 | Slow query log | `long_query_time = 1; slow_query_log = ON` |
| 4 | performance_schema | `events_statements_summary_by_digest` to extract hot queries |
| 5 | InnoDB status | `SHOW ENGINE INNODB STATUS\G` for lock waits/deadlocks |

---

## 2. Reading EXPLAIN

| Column | Meaning | Watch for |
|--------|---------|-----------|
| `type` | Access method | `ALL` (full scan) → add index; `ref`/`eq_ref`/`const` = good |
| `key` | Index used | NULL → no index; composite index obeys leftmost-prefix rule |
| `rows` | Estimated row count | Stale stats → run `ANALYZE TABLE` |
| `Extra` | Extra info | `Using temporary`, `Using filesort` = investigate |
| `filtered` | % rows remaining after WHERE | Far from 100% → index mismatch, consider composite index |

`EXPLAIN FORMAT=JSON` reveals `cost_info`, `used_columns`, and `nested_loop` — essential for tuning.

**vs PostgreSQL**: MySQL `Using filesort` = memory/disk sort (overflows when `tmp_table_size` exceeded); PG equivalent is `Sort` node with `work_mem` spill.

---

## 3. InnoDB Clustered Index (PRIMARY KEY is critical)

InnoDB stores data in **PRIMARY KEY order** (clustered index) — MySQL's most important characteristic.

| Impact | Detail |
|--------|--------|
| Secondary indexes include PK | `INDEX(name)` is internally `(name, id)`; large PKs bloat all indexes |
| PK insert order | Non-sequential PKs (UUID v4) → frequent page splits, write degradation |
| PK selection rule | Short, monotonically increasing, immutable |

**Recommendations**:
- AUTO_INCREMENT BIGINT (or UUID v7 for time-ordered inserts)
- UUID v4 as PK → reported 30-50% write degradation
- Composite PK: put the most-searched column first

---

## 4. Index design

| Type | Use | Example |
|------|-----|---------|
| **B+tree** (default) | Equality, range, ORDER BY | Typical WHERE |
| **Spatial** | Geospatial | `POINT`, `LINESTRING` |
| **Full-Text** | Full-text search | `MATCH AGAINST` |
| **Functional** (8.0+) | Expression index | `WHERE LOWER(email) = ?` |
| **Multi-Valued** (8.0+) | JSON array | `WHERE JSON_CONTAINS(tags, ?)` |

**Rules**:
- **Leftmost prefix**: composite `(a,b,c)` works for `WHERE a=?` or `WHERE a=? AND b=?`; `WHERE b=?` alone does not use the index
- **Covering index**: include SELECT columns in index to avoid table lookup (`Extra: Using index`)
- **Avoid low-cardinality leading column**: put `user_id` before `is_active` (binary)

---

## 5. Isolation level (differs from PostgreSQL)

| Level | InnoDB default | Prevents | Use |
|-------|---------------|----------|-----|
| **READ UNCOMMITTED** | - | (nothing) | Rare |
| **READ COMMITTED** | - | dirty read | General OLTP (same as PG default) |
| **REPEATABLE READ** | ✅ default | + non-repeatable read, phantom (via Next-Key Lock) | InnoDB default |
| **SERIALIZABLE** | - | all | Strong consistency, heavy contention hurts perf |

**Key difference vs PG**: both prevent phantom at RR, but differently:
- InnoDB RR: MVCC + **Next-Key Lock** (gap lock for range locking)
- PG RR: pure MVCC snapshot (no lock, Snapshot Isolation)

Result: write contention in InnoDB = lock wait; in PG = serialization failure (retry required).

---

## 6. Lock types (InnoDB)

| Lock | Scope | Description |
|------|-------|-------------|
| Shared (S) | row | Read; compatible with other S |
| Exclusive (X) | row | Write; exclusive |
| Intent Shared (IS) | table | Intent to take S |
| Intent Exclusive (IX) | table | Intent to take X |
| Record Lock | index record | Specific index entry only |
| Gap Lock | gap between index records | Prevents range insert (RR/SER) |
| Next-Key Lock | Record + preceding Gap | RR default; prevents phantom |
| Insert Intention Lock | gap | INSERT wait signal; incompatible with gap lock |
| AUTO-INC Lock | table | Reserves AUTO_INCREMENT values |

**Table-level lock compatibility**:

|    | IS | IX | S  | X  |
|----|----|----|----|----|
| IS | OK | OK | OK | NG |
| IX | OK | OK | NG | NG |
| S  | OK | NG | OK | NG |
| X  | NG | NG | NG | NG |

Gap locks are mutually compatible; Insert Intention is incompatible with existing gap locks.

**Next-Key Lock trigger**:

| Isolation | Access | Lock acquired |
|-----------|--------|---------------|
| RC | `FOR UPDATE` | Record Lock only (no gap) |
| RR | unique index equality (`WHERE id=5 FOR UPDATE`) | Record Lock only (gap skipped) |
| RR | non-unique / range | Next-Key Lock |

---

## 7. Deadlock analysis

### 7.1 Reading SHOW ENGINE INNODB STATUS

```
*** (1) TRANSACTION:
TRANSACTION 12345, ACTIVE 3 sec starting index read
*** (1) HOLDS THE LOCK(S):
RECORD LOCKS ... index PRIMARY ... lock_mode X locks rec but not gap
*** (1) WAITING FOR THIS LOCK TO BE GRANTED:
RECORD LOCKS ... index idx_status ... lock_mode X locks gap before rec insert intention waiting
*** WE ROLL BACK TRANSACTION (2)
```

Parse: HOLDS/WAITING FOR per TX → identify `lock_mode` → confirm circular wait → victim = lower-weight TX.

### 7.2 Common deadlock patterns

| Pattern | Cause | Fix |
|---------|-------|-----|
| **Row order mismatch** | TX1: id=1→2; TX2: id=2→1 | Always UPDATE in ascending id order |
| **Gap lock + INSERT** | `FOR UPDATE` (RR) acquires gap lock; another TX INSERTs → cycle | Downgrade to RC / use unique equality condition |
| **ON DUPLICATE KEY UPDATE** | Concurrent S→X upgrade on unique check | `INSERT IGNORE` + separate UPDATE |
| **FK check** | Child INSERT/UPDATE → S lock on parent row; another TX waits on parent X | Remove FK / unify parent-child operation order |

### 7.3 Monitoring and retry

```sql
SELECT * FROM performance_schema.data_lock_waits;
SHOW GLOBAL STATUS LIKE 'Innodb_deadlocks';
SET GLOBAL innodb_print_all_deadlocks = ON;
```
SLO target: deadlock rate > 0.1% TX/min → redesign TX; < 0.01% → absorb with retry.

```go
const maxRetry = 3
for i := 0; i < maxRetry; i++ {
    err := tx(ctx, func(tx *sql.Tx) error { ... })
    if err == nil { return nil }
    if !isDeadlock(err) { return err }
    time.Sleep(time.Duration(rand.Intn(50*(1<<i))) * time.Millisecond)
}
return ErrTooManyRetries
```

`1213` (ER_LOCK_DEADLOCK): already rolled back, retry safe. `1205` (ER_LOCK_WAIT_TIMEOUT): TX state unclear, retry carefully.

---

## 8. MVCC and undo log

| Concept | Description |
|---------|-------------|
| trx_id | Latest updating TX id; basis for read view judgment |
| roll_pointer | Pointer to undo log for historical version reconstruction |
| read view | Active TX snapshot at TX start. RR: 1 per TX; RC: 1 per statement |
| undo log | Old versions from UPDATE/DELETE; stored in undo tablespaces |
| purge thread | GC for stale undo; `innodb_purge_threads` (default 4) |

**Long-running TX**: even read-only TXs block purge → undo bloat. Root cause: autocommit OFF + idle session.

```sql
SHOW ENGINE INNODB STATUS\G  -- "History list length"
SELECT trx_id, trx_started, trx_mysql_thread_id, trx_query
FROM information_schema.innodb_trx ORDER BY trx_started LIMIT 10;
```

Threshold: history list length > 10M → severe purge lag; pressure on buffer pool and DDL.

---

## 9. InnoDB architecture

**Buffer Pool**: LRU midpoint insertion — new pages at 5/8 position; promoted after `innodb_old_blocks_time` (default 1000ms). Scan resistance. Target hit rate > 99%.

**Change Buffer**: buffers secondary index changes when target page not in buffer pool. Effective for write-heavy + many secondary indexes. Not applied to unique indexes. Consider `innodb_change_buffering = none` on SSD.

**Adaptive Hash Index (AHI)**: internalizes frequent B+tree lookups to O(1). Under heavy writes + contention, AHI latch becomes a bottleneck — monitor `btr_search_latch` waits in SEMAPHORES.

**Doublewrite Buffer**: prevents partial page write. On SSDs with atomic write, `innodb_doublewrite = OFF` halves writes. Leave ON otherwise.

**Redo Log**: WAL. Use `innodb_redo_log_capacity` (8.0.30+). Redo full → forced checkpoint → write stall. Target: 60-90 min of peak write throughput.

---

## 10. Hot row / contention mitigation

```sql
-- Counter sharding (16-way)
UPDATE counters SET value = value + 1 WHERE id = CONCAT('global_', FLOOR(RAND() * 16));
-- Read: SUM(value) WHERE id LIKE 'global_%'
-- SKIP LOCKED queue (8.0+)
SELECT id FROM jobs WHERE status = 'pending' ORDER BY id LIMIT 10 FOR UPDATE SKIP LOCKED;
```

**Short TX rules**:

| Situation | Rule |
|-----------|------|
| TX held during RPC | Open TX after external I/O completes |
| TX held waiting for user input | Never |
| Large row batch | Chunk commit every 1,000 rows |

---

## 11. 2PC and Group Commit

InnoDB + binlog uses XA 2PC: (1) redo prepare (fsync) → (2) binlog write (fsync) → (3) redo commit (fsync).

Group Commit: `binlog_group_commit_sync_delay` / `binlog_group_commit_sync_no_delay_count` batches commits to reduce fsyncs. Tune at high OLTP TPS (e.g., `delay=100us, count=20`). Monitor: `Binlog_commits / Binlog_group_commits` ratio — higher = better.

---

## 12. Key parameters

| Parameter | Recommendation | Description |
|-----------|---------------|-------------|
| `innodb_buffer_pool_size` | 70-80% of RAM | Most critical; caches data + indexes |
| `innodb_redo_log_capacity` (8.0.30+) | 1-8 GB | Total redo log capacity; old `innodb_log_file_size` deprecated in 8.4 |
| `innodb_flush_log_at_trx_commit` | 1 (default) or 2 | 1=full ACID; 2=up to 1s data loss but faster |
| `sync_binlog` | 1 (default) | 0 = faster but binlog loss on crash |
| `max_connections` | 200-500 | Too many consumes memory; use ProxySQL for external pooling |
| `tmp_table_size` / `max_heap_table_size` | 64-256 MB | Small = filesort/temp spills to disk |

---

## 13. Online DDL

| Algorithm | Impact | Use |
|-----------|--------|-----|
| **INSTANT** | Instant; metadata only | Append column (8.0+), specific ALTERs |
| **INPLACE** | No copy; minimal blocking | Add index, most DDLs |
| **COPY** | Full table copy; long lock | When INSTANT/INPLACE not applicable |

```sql
ALTER TABLE orders ADD COLUMN note TEXT, ALGORITHM=INSTANT, LOCK=NONE;
```

Decision: try INSTANT → fallback to INPLACE → last resort COPY (maintenance window or pt-online-schema-change).

---

## 14. Partitioning

| Strategy | Use | Key example |
|----------|-----|-------------|
| **RANGE** | Time-series, DROP old data | `created_at` monthly |
| **LIST** | Category separation | `region` |
| **HASH** | Uniform distribution | `user_id` |

**Caution**: partition pruning only works when WHERE includes partition key. InnoDB partitioned tables do not support FOREIGN KEY (MySQL 8.4). Partition key must be part of PK/UNIQUE constraint.

---

## 15. Replication

| Type | Mechanism | Use |
|------|-----------|-----|
| **Async** (default) | binlog sent, applied async | General |
| **Semi-sync** | Commit waits for ≥1 replica relay ack | Consistency-critical |
| **GTID** | Global transaction ID | Easy failover |
| **Parallel replication** (8.0 LOGICAL_CLOCK) | Parallel apply, reduces replica lag | High load |

Monitor: `SHOW REPLICA STATUS\G` → `Seconds_Behind_Source`, `Replica_SQL_Running_State`.

---

## 16. Anti-patterns

| Avoid | Use instead | Reason |
|-------|-------------|--------|
| UUID v4 as PK | AUTO_INCREMENT or UUID v7 | Clustered index write degradation |
| `SELECT *` | Only required columns | Misses covering index opportunities |
| `OFFSET 100000` | Keyset pagination (`WHERE id > last_id`) | OFFSET scans all preceding rows |
| `LIKE '%foo%'` | Full-Text or schema redesign | Leading wildcard disables index |
| Large IN clause (10,000+) | JOIN or temporary table | Parser overhead |
| Function on indexed column | Functional index | `WHERE LOWER(email)` skips index (8.0+ functional index available) |

---

## 17. Bulk INSERT AUTO_INCREMENT safety (`lastInsertID + i`)

**Precondition**: `LastInsertId() + i` assignment is only safe for **simple inserts** (multi-row `VALUES`). Not guaranteed for bulk inserts or mixed-mode inserts.

### NG patterns

| # | Pattern | grep keyword | What breaks |
|---|---------|--------------|-------------|
| 1 | `INSERT ... SELECT` to same table | `INSERT.*SELECT` | Treated as bulk insert; breaks sequential reservation |
| 2 | Bulk INSERT with `ON DUPLICATE KEY UPDATE` | `ON DUPLICATE KEY UPDATE` | Row count unknown at parse time; UPDATE rows consume no ID |
| 3 | Migration `INSERT ... SELECT` backfill | migration `.sql` + `INSERT.*SELECT` | Breaks concurrent simple inserts if run outside maintenance |
| 4 | Mixed-mode insert (some explicit IDs) | `INSERT INTO.*\(.*id.*\)` + `NULL` mix | `LastInsertId()` return value not guaranteed |
| 5 | Loop INSERT with dynamic row count | `for` + `placeholders` + `LastInsertId` | `len(entities) ≠ actual inserted rows` → ID misassignment |

```go
// Safe: pre-determined row count, all rows auto-assigned ID
query := `INSERT INTO entities (col_a, col_b) VALUES (?,?), (?,?), (?,?)`
res, _ := tx.Exec(query, values...)
firstID, _ := res.LastInsertId()
for i := range entities { entities[i].ID = int(firstID) + i }
```

Warning comment template for bulk insert functions relying on `LastInsertId() + i`:

```go
// Relies on sequential ID assignment (LastInsertId() + i) for simple inserts.
// Breaks with: INSERT...SELECT / ON DUPLICATE KEY UPDATE / mixed-mode inserts / migration backfill.
// Ref: https://dev.mysql.com/doc/refman/8.4/en/innodb-auto-increment-handling.html
```

Detection: `bulk-insert-correctness` check in `/review` (`skills/comprehensive-review/skill.md`).

---

## 18. MySQL 8 / InnoDB 8.0 feature index

Cross-references the 8.0 features scattered through earlier sections, plus capabilities not yet covered.

### Already covered in this guide

| Feature | Section | Note |
|---------|---------|------|
| INSTANT ALGORITHM (instant column add) | §13 | Try INSTANT first for ALTER TABLE |
| LOGICAL_CLOCK parallel replication | §15 | Reduces replica lag on write-heavy workloads |
| Partition + FK incompatibility (8.4) | §14 | InnoDB partitioned tables reject FOREIGN KEY |
| Bulk INSERT `LastInsertId() + i` safety | §17 | Depends on consecutive AUTO_INCREMENT allocation |

### Not yet covered (use as needed)

| Feature | Use | Caveat |
|---------|-----|--------|
| **Generated Invisible Primary Key (GIPK)** (8.0.30+) | Auto-add hidden PK when `sql_generate_invisible_primary_key=ON` for tables created without one | `mysqldump --skip-generated-invisible-primary-key` for replication to pre-8.0.30 |
| **Window functions** (`OVER`, `RANK()`, `LAG()`, `LEAD()`) | Per-group ranking, running totals, prev/next row comparison | Replaces self-join / correlated subquery patterns |
| **Common Table Expressions** (`WITH`, recursive `WITH RECURSIVE`) | Hierarchical queries, query readability | Optimizer may materialize the CTE (check `EXPLAIN`) |
| **Lateral derived tables** (`JOIN LATERAL`) (8.0.14+) | Top-N per group, correlated derived tables | Equivalent to PostgreSQL `LATERAL` |
| **`SKIP LOCKED` / `NOWAIT`** on `SELECT … FOR UPDATE` | Job queue dequeue (skip rows another worker holds) | Cannot replace ordering — readers see queue out of order |
| **JSON functions** (`JSON_TABLE`, `JSON_EXTRACT`, `->`, `->>`, `JSON_OVERLAPS`) | Semi-structured data without a schema migration | No statistics on JSON paths — index a virtual generated column for predicates |
| **Functional indexes** (`CREATE INDEX … ON t ((LOWER(col)))`) | Index a computed expression directly | Query must use the same expression verbatim |
| **Descending indexes** (`INDEX (col DESC)`) | Avoid `filesort` on `ORDER BY col DESC` mixed with ASC | Prior to 8.0 the `DESC` keyword was parsed but ignored |
| **Invisible indexes** (`INDEX … INVISIBLE`) | Stage index removal: optimizer ignores it, but maintained on write | Toggle visible/invisible to A/B before `DROP INDEX` |
| **Resource groups** | Cap CPU for analytics / batch sessions to protect OLTP | Set per-session via `SET RESOURCE GROUP …` |
| **Hash join** (8.0.18+, default 8.0.20+) | Joins without usable index now use hash join instead of block-nested-loop | Memory-bound — large joins still need an index |
| **`EXPLAIN ANALYZE`** | Actual execution time, row counts, loop counts | Use after `EXPLAIN FORMAT=TREE` for runtime evidence |
| **Histogram statistics** (`ANALYZE TABLE … UPDATE HISTOGRAM`) | Help the optimizer on skewed columns lacking an index | Not auto-refreshed — re-run after large data shifts |

### Removed / changed since 5.7 (migration hazards)

| Item | 5.7 → 8.0 change |
|------|------------------|
| `utf8` charset alias | Still `utf8mb3`; **always use `utf8mb4`** for new tables |
| Default charset | `utf8mb4`, default collation `utf8mb4_0900_ai_ci` |
| Query cache | Removed — rely on application cache (`backend/caching-strategies.md`) |
| Implicit sorting by `GROUP BY` | Removed — add explicit `ORDER BY` if needed |
| `mysql_native_password` default | Changed to `caching_sha2_password`; old clients need `default_authentication_plugin=mysql_native_password` or driver upgrade |
| `SHOW SLAVE STATUS` | Use `SHOW REPLICA STATUS` |
| Atomic DDL | DDL no longer leaves half-applied state on crash |

---

## 19. References

- MySQL 8.4 Reference Manual — [InnoDB Locking](https://dev.mysql.com/doc/refman/8.4/en/innodb-locking.html) / [Deadlocks](https://dev.mysql.com/doc/refman/8.4/en/innodb-deadlocks.html) / [Multi-Versioning](https://dev.mysql.com/doc/refman/8.4/en/innodb-multi-versioning.html) / [AUTO_INCREMENT Handling](https://dev.mysql.com/doc/refman/8.4/en/innodb-auto-increment-handling.html)
- MySQL 8.4 Reference Manual — [Buffer Pool](https://dev.mysql.com/doc/refman/8.4/en/innodb-buffer-pool.html) / [Change Buffer](https://dev.mysql.com/doc/refman/8.4/en/innodb-change-buffer.html) / [Adaptive Hash Index](https://dev.mysql.com/doc/refman/8.4/en/innodb-adaptive-hash.html) / [Doublewrite Buffer](https://dev.mysql.com/doc/refman/8.4/en/innodb-doublewrite-buffer.html)
- High Performance MySQL (Schwartz et al.) / MySQL Internals / Jeremy Cole "InnoDB" series
- Percona Database Performance Blog
- Related: `backend/database-performance.md` (PG), `backend/distributed-transactions.md` (isolation levels), `backend/caching-strategies.md`
