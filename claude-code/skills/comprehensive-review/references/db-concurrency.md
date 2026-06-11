# db-concurrency review reference

Detect InnoDB implicit deadlock / lock wait timeout / hot row contention from diff. Judge by combination of SQL string + TX boundary + isolation setting.

Background: `guidelines/backend/mysql-performance.md` §6-7.

## Detection patterns (high precision first)

### P1. UPDATE/SELECT FOR UPDATE undefined order

**Symptom**: Updating multiple rows in same TX without sorting input array → reverse-order access with another TX → deadlock (§7.2 pattern A).

**Detection signals**:

| Signal | grep pattern example |
|--------|----------------------|
| UPDATE/DELETE in loop | `for .* { .*tx.*Exec.*UPDATE\|DELETE` |
| 2+ UPDATE statements in function, ID from args | 2+ UPDATE locations + args `IDs []int64` etc |
| `IN (?, ?, ?)` with no prior sort | `IN (` + no sort before |

**Judgment**: Warning when no `sort.Slice(ids, ...)` / `ORDER BY` / monotonic PK ascending guarantee before UPDATE. If caller always guarantees sort, require explicit comment.

**Fix**: SQL-side `ORDER BY id`, or app-side `slices.Sort(ids)` before issue.

### P2. RR + non-unique/range FOR UPDATE + subsequent INSERT

**Symptom**: Gap lock acquired → INSERT in same/other TX incompatible with Insert Intention → circular deadlock (§7.2 pattern B).

**Detection signals**:

| Signal | Example |
|--------|---------|
| `SELECT ... FOR UPDATE` + `WHERE <non-PK> =` or range | `FOR UPDATE` + `BETWEEN\|IN\|>\|<` |
| INSERT into same table/condition in same TX | Followed by `INSERT INTO <same table>` |
| No explicit isolation below 8.0 | Default RR, MySQL 8.0+ also defaults to RR |

**Judgment**: Warning if 2+ of 3 conditions (non-unique FOR UPDATE / subsequent INSERT in TX / RR isolation) met; Critical candidate if all 3.

**Fix**:
- Downgrade isolation to RC (`tx.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelReadCommitted})`)
- Rewrite FOR UPDATE to unique equality condition
- Split TX, release before INSERT

### P3. INSERT ... ON DUPLICATE KEY UPDATE concurrent upsert

**Symptom**: S lock on unique check → X upgrade on UPDATE path, concurrent upsert on same key → upgrade deadlock (§7.2 pattern C).

**Detection signals**:

| Signal | Example |
|--------|---------|
| `ON DUPLICATE KEY UPDATE` | Literal match |
| Direct call in handler/worker | Concurrency-expected location |
| Multi-row VALUES + ODKU | Bulk upsert |

**Judgment**: Warning if ODKU location is in concurrent execution path (handler/job/worker) and key concentration possible. ODKU inside idempotent migration is out of scope.

**Fix**:
- Separate into `INSERT IGNORE` + separate `UPDATE`
- Acquire X lock with `SELECT FOR UPDATE` then branch
- Sharding or queue if same key concentration

### P4. FK chain implicit S lock

**Symptom**: Child INSERT/UPDATE → implicit S lock on parent row. Other TX acquires X on parent → wait. Circular if child and parent updates happen bidirectionally (§7.2 pattern D).

**Detection signals**:

| Signal | Example |
|--------|---------|
| `FOREIGN KEY` in schema/migration | `REFERENCES` |
| Parent UPDATE + child INSERT/UPDATE coexist in same TX | Undefined order |

**Judgment**: Warning if both parent/child writes in same TX and parent row is updated from multiple handlers.

**Fix**: Remove FK (app-enforced integrity) / unify parent-child update order / split TX.

### P5. UPDATE/DELETE without index

**Symptom**: UPDATE/DELETE with non-indexed column WHERE → full scan + full row lock → effective table lock → frequent deadlock/lock wait timeout.

**Detection signals**:

| Signal | Example |
|--------|---------|
| `UPDATE\|DELETE FROM .+ WHERE <column>` | Check if column is indexed in schema |
| Index absent for that WHERE column in migration | `CREATE INDEX` grep |

**Judgment**: Critical candidate if index absent on column after checking schema/migration (deadlock-direct).

**Fix**: Add index. Run EXPLAIN; `type=ALL` confirms.

### P6. External I/O inside TX

**Symptom**: HTTP / gRPC / message publish / time.Sleep inside TX → lock held during external latency → frequent deadlock/timeout.

**Detection signals**:

| Signal | Example |
|--------|---------|
| External call within TX boundary | `http.Get` / `client.Call` / `Publish` / `sleep` between `tx.Begin` and `tx.Commit` |
| Wait in ORM TX scope | External IO inside `db.Transaction(func(tx) { ... external })` |

**Judgment**: Critical if synchronous external call detected in TX scope (lock wait timeout before deadlock).

**Fix**: Open TX after external I/O completes / use outbox pattern to separate DB commit and message send.

### P7. Missing deadlock retry

**Symptom**: TX function immediately fails on ER_LOCK_DEADLOCK (1213) → increased user-facing failures. InnoDB auto-rolls back loser TX, so retry is safe.

**Detection signals**:

| Signal | Example |
|--------|---------|
| No retry loop in TX wrapper function | No `for ... retry` |
| No error judgment | No mysql errno 1213 check |

**Judgment**: Warning if retry missing in common TX-boundary function (repo/store/uow layer). One-shot scripts/migrations out of scope.

**Fix**: Implement exponential backoff + jitter retry (template in mysql-performance.md §7.4).

### P8. AUTO-INC lock mode misuse

**Symptom**: Bulk INSERT + `lastInsertID + i` numbering with `innodb_autoinc_lock_mode=2` (8.0 default) → non-sequential IDs → ID mismatch.

**Detection signals**: Covered separately in mysql-performance.md §17 (bulk-insert-correctness perspective). Treat as cross-reference here, do not duplicate output.

## Output guide

| Severity | Condition |
|----------|-----------|
| Critical | P2 all conditions met / P5 (index absence confirmed) / P6 (external I/O clearly detected) |
| Warning | P1 / P3 / P4 / P7 / P2 partial |
| Note | P5 without schema reference, idempotent-assumed P3, etc |

## False positive avoidance

- Migration script / one-shot batch / unit test fixture → P3/P7 out of scope
- TX boundary undeterminable (autocommit-assumed ORM call) → do not detect
- `READ COMMITTED` isolation explicitly set → exclude P2 gap lock patterns
- Index presence unknown without schema reference → P5 stays at note

## Related

- `guidelines/backend/mysql-performance.md` §6-7 (lock/deadlock details)
- `guidelines/backend/database-performance.md` (PG version; PG uses MVCC → serialization failure → retry path)
- `guidelines/backend/distributed-transactions.md` (isolation level design decisions)
