# MySQL/InnoDBパフォーマンス ガイドライン

クエリ遅延・スループット限界・本番MySQL調査時に参照。**MySQL 8.4 LTS / InnoDB** 想定。PostgreSQLは `backend/database-performance.md` 参照。

## Tier区分

| Tier | 内容 |
|------|------|
| Tier 1（必須） | EXPLAIN、PK/clustered index、N+1、isolation level |
| Tier 2（規模別） | Lock types、buffer pool、Online DDL、partition |
| Tier 3（上級） | デッドロック解析、MVCC/undo、InnoDB内部 (AHI/change buffer/doublewrite)、2PC group commit、hot row緩和 |

---

## 1. 「MySQL遅い」診断5ステップ

| Step | 確認 | コマンド |
|------|------|---------|
| 1 | EXPLAIN（実行計画） | `EXPLAIN FORMAT=JSON <query>` |
| 2 | 実測コスト | `EXPLAIN ANALYZE <query>`（8.0.18+） |
| 3 | slow query log | `long_query_time = 1; slow_query_log = ON` |
| 4 | performance_schema | `events_statements_summary_by_digest` で頻出query抽出 |
| 5 | InnoDB status | `SHOW ENGINE INNODB STATUS\G` でlock waits/deadlock |

---

## 2. EXPLAINの読み方（PGとの違い）

| 列 | 意味 | 注目ポイント |
|----|------|-------------|
| `type` | アクセス方法 | `ALL`（全件）→ index必要、`ref`/`eq_ref`/`const`は良好 |
| `key` | 使用index | NULL → index未使用、複合indexは左端一致原則 |
| `rows` | 推定行数 | 統計古いと不正確、`ANALYZE TABLE` で更新 |
| `Extra` | 追加情報 | `Using temporary` `Using filesort` は要注意 |
| `filtered` | WHERE後残存率 | 100%遠い→ index不適合、複合化検討 |

**EXPLAIN FORMAT=JSON**: cost_info / used_columns / nested_loopが見え、tuningに必須。

**PGとの差**:
- MySQL: `Using filesort` = メモリ/diskソート、tmp_table_size超過でdiskへ
- PG: 似た概念は `Sort` ノード、`work_mem` 不足でdisk spill

---

## 3. InnoDB Clustered Index（PRIMARY KEY設計が最重要）

InnoDBは **PRIMARY KEY = データの物理配置順**（clustered index）。これがMySQLの最大の特徴。

| 影響 | 内容 |
|------|------|
| **Secondary indexはPKを含む** | `INDEX(name)` は内部的に `(name, id)` 構造、PK肥大化はindex全体に影響 |
| **PK挿入順序** | 非連番PK（UUID v4等）→ ページ分割多発、書込み劣化 |
| **PK選定原則** | 短く、単調増加、不変 |

**推奨**:
- AUTO_INCREMENT BIGINT（or UUID v7で時系列性確保）
- ❌ UUID v4をPKにしない（書込み30-50% 劣化報告）
- 複合PKは最も検索される列を先頭

---

## 4. インデックス設計

| 種類 | 用途 | 例 |
|------|------|-----|
| **B+tree**（既定） | 等価・範囲・ORDER BY | 通常のWHERE |
| **Hash** | 等価のみ（MEMORY engineのみ） | 限定 |
| **Spatial** | 地理空間 | `POINT`、`LINESTRING` |
| **Full-Text** | 全文検索 | `MATCH AGAINST` |
| **Functional**（8.0+） | 式index | `WHERE LOWER(email) = ?` |
| **Multi-Valued**（8.0+） | JSON配列 | `WHERE JSON_CONTAINS(tags, ?)` |

**原則**:
- **左端一致**: 複合index `(a,b,c)` は `WHERE a=?`/`WHERE a=? AND b=?` で効く、`WHERE b=?` 単独は効かない
- **Covering index**: SELECT列をindexに含めるとtable参照不要（`EXTRA: Using index`）
- **Cardinality低い列を先頭にしない**: `is_active`（2値）より `user_id` を先頭に

---

## 5. Isolation Level（PGとの違い注意）

| レベル | InnoDB既定 | 防げる現象 | 用途 |
|--------|-----------|-----------|------|
| **READ UNCOMMITTED** | - | （何も） | dirty read許容、稀 |
| **READ COMMITTED** | - | dirty read | 一般OLTP（PG既定と同じ） |
| **REPEATABLE READ** | ✅ 既定 | + non-repeatable read, phantom（InnoDB特有のロック挙動） | InnoDB既定 |
| **SERIALIZABLE** | - | 全て | 強整合、競合激しいと性能低下 |

**PGとの重要差**:
- 両者ともRRでphantomを実質的に防ぐが**仕組みが異なる**:
  - InnoDB RR: MVCC + **Next-Key Lock**（gap lockで範囲ロック）
  - PG RR: pure MVCCスナップショット（lockなし、SI = Snapshot Isolation）
- 結果、**書込競合時の挙動差**: InnoDBはlock待ち、PGはserialization failure（retry必要）
- **SERIALIZABLE**: PGはSSI（Serializable Snapshot Isolation、競合検出時abort）、InnoDBは純粋lockベース（impl別物）

---

## 6. Lock Types（InnoDB詳細）

InnoDBのlockはrow-level、index recordを対象。table-level latchとは別物。

### 6.1 lock種類一覧

| Lock | 対象 | 説明 |
|------|------|------|
| Shared (S) | row | 読み取り、他Sと互換 |
| Exclusive (X) | row | 書き込み、独占 |
| Intent Shared (IS) | table | Sを取る意図表明 |
| Intent Exclusive (IX) | table | Xを取る意図表明 |
| Record Lock | index record | 該当index entryのみ |
| Gap Lock | index間の隙間 | 範囲挿入防止 (RR/SER) |
| Next-Key Lock | Record + 直前Gap | RR既定、phantom防止 |
| Insert Intention Lock | gap | INSERT待機表明、gap lockと非互換 |
| Predicate Lock | spatial index | SPATIAL index範囲 |
| AUTO-INC Lock | table | AUTO_INCREMENT列予約 |

### 6.2 table-level lock互換性

|       | IS | IX | S  | X  |
|-------|----|----|----|----|
| IS    | OK | OK | OK | NG |
| IX    | OK | OK | NG | NG |
| S     | OK | NG | OK | NG |
| X     | NG | NG | NG | NG |

Gap lock同士は互換 (X gap lock含む)、ただしInsert Intentionは既存gap lockと非互換。

### 6.3 Next-Key Lock発動条件

| isolation | アクセス | 取得lock |
|-----------|---------|----------|
| RC | `FOR UPDATE` 全般 | Record Lockのみ (gapなし) |
| RR | unique index等価 (`WHERE id=5 FOR UPDATE`) | Record Lockのみ (gap省略最適化) |
| RR | non-unique / 範囲 | Next-Key Lock |
| RR | range scan (`WHERE x BETWEEN..`) | 範囲全体にNext-Key Lock |

EXPLAIN `type=const`/`eq_ref` ならgap省略期待。

### 6.4 AUTO-INC Lock Mode (`innodb_autoinc_lock_mode`)

| Mode | 名前 | 仕組み | 連番性 | 並行性 |
|------|------|-------|--------|--------|
| 0 | traditional | TX終了までtable lock | 完全連番 | 低 |
| 1 | consecutive | simple insertは短期lock、bulkはtable lock | simpleは連番 | 中 |
| 2 | interleaved (8.0既定) | 全INSERTで短期lockのみ | 連番非保証、ギャップ可 | 高 |

binlog `ROW`/`MIXED` 前提。`STATEMENT` 時はmode 2不可。

---

## 7. デッドロック深掘り

### 7.1 SHOW ENGINE INNODB STATUS読み方

`LATEST DETECTED DEADLOCK` セクションのフィールド意味:

```
*** (1) TRANSACTION:
TRANSACTION 12345, ACTIVE 3 sec starting index read
LOCK WAIT 4 lock struct(s), heap size 1136, 2 row lock(s)
*** (1) HOLDS THE LOCK(S):
RECORD LOCKS space id 5 page no 4 n bits 72 index PRIMARY of table `db`.`t`
trx id 12345 lock_mode X locks rec but not gap
*** (1) WAITING FOR THIS LOCK TO BE GRANTED:
RECORD LOCKS space id 5 page no 4 n bits 72 index idx_status of table `db`.`t`
trx id 12345 lock_mode X locks gap before rec insert intention waiting
*** WE ROLL BACK TRANSACTION (2)
```

読み解き:

1. 各TXのHOLDSとWAITING FORを抽出
2. `lock_mode` 表記で種別判定:
   - `locks rec but not gap` → Record Lock
   - `locks gap before rec` → Gap Lock
   - `locks rec but not gap insert intention` → Insert Intention Lock
3. 環状待機 (TX A holds R1 wait R2 / TX B holds R2 wait R1) を確認
4. `index PRIMARY` vs `index idx_xxx` でprimary/secondary競合判定
5. ROLLBACK対象TXはweight小さい方が犠牲

### 7.2よくあるデッドロックパターン

| パターン | 原因 | 対処 |
|---------|------|------|
| **A: row順序違い** | TX1がid=1→2、TX2がid=2→1でUPDATE → 環状待機 | id昇順でUPDATE統一 |
| **B: gap lock + INSERT** | `FOR UPDATE` (RR) でgap lock取得後、別TXがINSERT待機 → 循環 | RCへ降格 / unique等価条件に変更 |
| **C: ON DUPLICATE KEY UPDATE** | unique検査S lock → X昇格を複数TXが同時実行 | `INSERT IGNORE` + 別UPDATE / 事前 `SELECT FOR UPDATE` |
| **D: FKチェック** | 子INSERT/UPDATE → 親rowにS lock / 別TXが親XをUPDATE待機 | FK削除 / 親更新と子操作の順序統一 |

### 7.3監視

```sql
-- 8.0+: performance_schema 経由
SELECT * FROM performance_schema.data_lock_waits;
SELECT * FROM performance_schema.data_locks WHERE OBJECT_NAME = 'orders';

-- 累積数
SHOW GLOBAL STATUS LIKE 'Innodb_deadlocks';

-- 全 deadlock を error log へ
SET GLOBAL innodb_print_all_deadlocks = ON;
```

SLO目安: deadlock rate > 0.1% TX/min → TX設計見直し、< 0.01% はretryで吸収可。

### 7.4 retryパターン

```go
const maxRetry = 3
for i := 0; i < maxRetry; i++ {
    err := tx(ctx, func(tx *sql.Tx) error { ... })
    if err == nil { return nil }
    if !isDeadlock(err) { return err }
    time.Sleep(time.Duration(rand.Intn(50*(1<<i))) * time.Millisecond) // exp backoff + jitter
}
return ErrTooManyRetries
```

`1213` (ER_LOCK_DEADLOCK): 即時ROLLBACK済、retry安全。`1205` (ER_LOCK_WAIT_TIMEOUT): TX状態不明瞭、慎重に。

---

## 8. MVCCとundo log

InnoDBはper-rowで `trx_id` + `roll_pointer` を保持、read view経由で過去版を再構成。

| 概念 | 説明 |
|------|------|
| trx_id | row最新更新TX id、read view判定の基準 |
| roll_pointer | undo logへのpointer、過去版再構成リンク |
| read view | TX開始時のactive TX snapshot。RRはTX中1個、RCは文ごと |
| undo log | UPDATE/DELETEの旧版保持、undo tablespacesに格納 |
| purge thread | 不要undoのGC、`innodb_purge_threads` (既定4) |

### 8.1 long-running TXの害

read-only TXでも開放されないとpurgeが進まずundo肥大。autocommit OFF + idle sessionが頻発源。

```sql
-- history list 監視
SHOW ENGINE INNODB STATUS\G  -- "History list length"
SELECT * FROM information_schema.innodb_metrics WHERE name = 'trx_rseg_history_len';

-- 長時間 TX 検出
SELECT trx_id, trx_started, trx_mysql_thread_id, trx_query
FROM information_schema.innodb_trx ORDER BY trx_started LIMIT 10;
```

閾値: history list length > 10M → purge遅延深刻、buffer pool圧迫 + DDL阻害。

対処: idle TX kill (`KILL <id>`)、ORMのTX scope短縮、autocommit確認。

---

## 9. InnoDBアーキテクチャ

### 9.1 Buffer Pool

LRUはmidpoint insertion: 新規pageはLRUの5/8地点に挿入、`innodb_old_blocks_time` (既定1000ms) 経過後の再アクセスでnew sublist昇格。目的: 大量scanでhot pageを退避させない (scan resistance)。

```sql
SHOW ENGINE INNODB STATUS\G  -- BUFFER POOL AND MEMORY セクション
-- Buffer pool hit rate: > 99% 維持目標
```

`innodb_buffer_pool_instances` (8.0既定8) で内部mutex分散。100GB超のpoolは16推奨。

### 9.2 Change Buffer

secondary indexのINSERT/DELETE/UPDATEで対象pageがbuffer poolになければchange bufferに記録、後でmerge。writes重視 + secondary index多 + flush頻繁のworkloadで効果。

注意: unique secondary indexには適用されない。SSD環境では効果限定的。`innodb_change_buffering = none` で無効化検討。

### 9.3 Adaptive Hash Index (AHI)

頻出B+tree探索を内部hash化、O(log N) → O(1)。Read-heavy + 同一prefix頻出で効くが、書込み多 + 競合多ではAHI自体のlatch競合がボトルネック化。

監視: SHOW ENGINE INNODB STATUSのSEMAPHORESセクションで `btr_search_latch` 待機頻出 → 無効化検討 (`innodb_adaptive_hash_index = OFF`)。

### 9.4 Doublewrite Buffer

partial page write対策でsystem tablespaceへ事前書き出し。SSDのatomic write対応環境では `innodb_doublewrite = OFF` でwrite半減可。保証ない環境では絶対ON。

### 9.5 Redo Log

WAL。`innodb_redo_log_capacity` で総量指定 (8.0.30+)。redo full → checkpoint強制 → 書込みストール。

目安: peak write throughputの60-90分相当のサイズ確保。

### 9.6 Purge

undo logの不要レコードをGC。`innodb_purge_threads` (既定4) で並列度。purge lagはhistory list lengthで観測。

---

## 10. Hot Row / Contention緩和

### 10.1カウンタsharding

```sql
-- ❌ hot row
UPDATE counters SET value = value + 1 WHERE id = 'global';

-- ✅ N way shard
UPDATE counters SET value = value + 1
WHERE id = CONCAT('global_', FLOOR(RAND() * 16));
-- 読み取りは SUM(value) WHERE id LIKE 'global_%'
```

### 10.2 SKIP LOCKEDでキュー化 (8.0+)

```sql
SELECT id FROM jobs WHERE status = 'pending' ORDER BY id LIMIT 10
FOR UPDATE SKIP LOCKED;
-- 他 worker が lock 中の row を飛ばして取得、deadlock 回避
```

### 10.3 INSERT-onlyパターン

UPDATE競合が激しければappend-onlyログテーブル + 定期集約でhot row解消。

### 10.4短TX原則

| 状況 | 推奨 |
|------|------|
| RPC中でTX保持 | 外部I/O完了後に開く |
| ユーザ入力待ちのTX | 絶対回避 |
| 大量row処理 | 1000 rowずつchunk commit |

---

## 11. 2PCとGroup Commit

InnoDB + binlogはXA 2PCで整合性保証:

1. InnoDB redo prepare (fsync)
2. binlog write (fsync)
3. InnoDB redo commit (fsync)

Group Commit: `binlog_group_commit_sync_delay` / `binlog_group_commit_sync_no_delay_count` で同時commitを集約、fsync回数削減。OLTP高TPSでは必須チューニング、例 `delay=100us, count=20`。

監視: `Binlog_commits / Binlog_group_commits` 比が同時commit効率指標、大きい方が効率高。

---

## 12. 主要パラメータ

| パラメータ | 推奨 | 説明 |
|-----------|------|------|
| `innodb_buffer_pool_size` | 物理RAM 70-80% | 最重要、データ+indexキャッシュ |
| `innodb_redo_log_capacity`（8.0.30+ 推奨） | 1-8GB | redo log総容量。旧 `innodb_log_file_size` は8.4でdeprecated |
| `innodb_flush_log_at_trx_commit` | 1（既定）or 2 | 1=ACID完全、2=1秒内データロス可で性能↑ |
| `sync_binlog` | 1（既定） | 0は性能↑だがクラッシュでbinlogロス |
| `max_connections` | 200-500 | 多すぎはmemory食う、外部poolingはProxySQL（MySQL版PgBouncer相当） |
| `tmp_table_size` / `max_heap_table_size` | 64-256MB | 小さいとfilesort/tempがdiskへ |

---

## 13. Online DDL

| アルゴリズム | 影響 | 用途 |
|-------------|------|------|
| **INSTANT** | 即時、メタデータのみ | 末尾カラム追加（8.0+）、特定ALTER |
| **INPLACE** | コピーなし、blocking少 | index追加、多くのDDL |
| **COPY** | テーブル全コピー、長時間ロック | INSTANT/INPLACE不可時 |

```sql
ALTER TABLE orders ADD COLUMN note TEXT, ALGORITHM=INSTANT, LOCK=NONE;
```

判定: `ALTER ... ALGORITHM=INSTANT` 試行 → 不可ならINPLACE → 最終手段COPY（メンテ枠or pt-online-schema-change）。

---

## 14. パーティショニング

| 戦略 | 適用 | キー例 |
|------|------|-------|
| **RANGE** | 時系列、古いデータDROP | `created_at` 月単位 |
| **LIST** | カテゴリ分離 | `region` |
| **HASH** | 均等分散 | `user_id` |
| **KEY** | MySQL内部hash（任意の型に対応） | `user_id` |

**注意**:
- パーティションpruningはWHEREがpartition keyを含む時のみ効く
- **InnoDB partitioned tableはFOREIGN KEY非対応**（MySQL 8.4時点）→ FK必要ならpartitionせず別解（archive table等）
- partition keyはPK/UNIQUE constraintに含まれる必要あり

---

## 15. レプリケーション

| 種類 | 仕組み | 用途 |
|------|--------|------|
| **非同期**（既定） | binlog送信、適用は非同期 | 一般 |
| **準同期** | 1台以上のrelay受領までcommit待ち | 整合性重視 |
| **GTID** | グローバルトランザクションID | failover容易 |
| **Parallel Replication**（8.0 LOGICAL_CLOCK） | 並列適用、replica lag削減 | 高負荷 |

**監視**: `SHOW REPLICA STATUS\G` の `Seconds_Behind_Source`、`Replica_SQL_Running_State`。

---

## 16. アンチパターン

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| UUID v4をPK | AUTO_INCREMENT or UUID v7 | clustered index書込劣化 |
| `SELECT *` | 必要列のみ | covering index化機会逃す |
| `OFFSET 100000` | キーセットページネーション（`WHERE id > last_id`）| OFFSETは前N件全走査 |
| `LIKE '%foo%'` | Full-Text or設計見直し | 左端ワイルドカードはindex不可 |
| 巨大IN句（10,000+） | JOIN or temporary table | parser重い、最適化器負担 |
| 関数をindex列に適用 | Functional index | `WHERE LOWER(email)` はindex効かず（8.0+ でfunctional index可） |

---

## 17. Bulk INSERT AUTO_INCREMENT採番安全パターン（`lastInsertID + i`）

**前提**: multi-row `VALUES` の `INSERT` 後に `LastInsertId() + i` でentityにIDを割り振るパターンは、MySQL AUTO_INCREMENT仕様上「単純挿入（simple inserts）」でのみ連番保証される。「一括挿入（bulk inserts）」「混合モード挿入（mixed-mode inserts）」では保証されない。

**該当キーワード**（grep用）: `lastInsertID + i` / `LastInsertId() + i` / `INSERT ... SELECT` / `ON DUPLICATE KEY UPDATE` / `innodb_autoinc_lock_mode`

### NGパターン一覧

| # | パターン | grepキーワード | 何が起きるか |
|---|---------|----------------|--------------|
| 1 | 同テーブルへの `INSERT ... SELECT` 追加 | `INSERT.*SELECT` | bulk inserts扱い、並行単純挿入の連番ブロック予約が崩れる |
| 2 | `ON DUPLICATE KEY UPDATE` 付きbulk INSERT | `ON DUPLICATE KEY UPDATE` | 実行時までINSERT行数不確定→一括挿入扱い、UPDATE行はID消費なし |
| 3 | migrationでの `INSERT ... SELECT` backfill | migration `.sql` + `INSERT.*SELECT` | maintenance外実行で並行単純挿入を破壊、運用ルール依存 |
| 4 | 混合モード挿入（id列の一部明示・一部自動採番） | `INSERT INTO.*\(.*id.*\)` + `NULL` 混在 | `LastInsertId()` の戻り値・連番ともに保証なし |
| 5 | 動的に行数が決まるループINSERT | `for` + `placeholders` + `LastInsertId` | `len(entities) ≠ INSERT実行行数` でIDズレ |

### コード例

```go
// ❌ NG1: INSERT...SELECT → bulk扱いで連番崩れ
tx.Exec(`INSERT INTO entities (col_a, col_b) SELECT col_a, col_b FROM legacy WHERE migrated = 0`)

// ❌ NG2: ON DUPLICATE KEY UPDATE → UPDATE行はID消費せず連番崩れ
// ❌ NG4: id一部明示の混合モード → LastInsertId不定
// ❌ NG5: ループで行数動的決定 → len(entities)と挿入行数ズレ

// ✅ 安全: 行数事前確定・id全行自動採番のmulti-row VALUES
query := `INSERT INTO entities (col_a, col_b) VALUES (?,?), (?,?), (?,?)`
res, _ := tx.Exec(query, values...)
firstID, _ := res.LastInsertId()
for i := range entities { entities[i].ID = int(firstID) + i } // mode=2でも連番保証
```

### 警告コメント雛形

`LastInsertId() + i` 採番に依存するbulk insert関数の冒頭に貼る。将来のレビュアーがNGパターン追加を検知できる。

```go
// bulkInsert は単純挿入（multi-row VALUES、行数事前確定、id 全行自動採番）の
// 連番採番（LastInsertId() + i）に依存している。
// 以下を追加するときはこの関数の前提が崩れるため要見直し:
//   - 同テーブルへの INSERT ... SELECT / LOAD DATA / ON DUPLICATE KEY UPDATE
//   - 混合モード挿入（id 指定行と自動採番行の混在）
//   - migration での同テーブル大量データ backfill
// 参照: https://dev.mysql.com/doc/refman/8.4/en/innodb-auto-increment-handling.html
```

### 検知

`/review` の `bulk-insert-correctness` 観点で自動検知（[skills/comprehensive-review/skill.md](../../skills/comprehensive-review/skill.md) 参照）。

---

## 18. 参考

- MySQL 8.4 Reference Manual — [InnoDB Locking](https://dev.mysql.com/doc/refman/8.4/en/innodb-locking.html) / [Deadlocks](https://dev.mysql.com/doc/refman/8.4/en/innodb-deadlocks.html) / [Multi-Versioning](https://dev.mysql.com/doc/refman/8.4/en/innodb-multi-versioning.html) / [AUTO_INCREMENT Handling](https://dev.mysql.com/doc/refman/8.4/en/innodb-auto-increment-handling.html)
- MySQL 8.4 Reference Manual — [Buffer Pool](https://dev.mysql.com/doc/refman/8.4/en/innodb-buffer-pool.html) / [Change Buffer](https://dev.mysql.com/doc/refman/8.4/en/innodb-change-buffer.html) / [Adaptive Hash Index](https://dev.mysql.com/doc/refman/8.4/en/innodb-adaptive-hash.html) / [Doublewrite Buffer](https://dev.mysql.com/doc/refman/8.4/en/innodb-doublewrite-buffer.html)
- High Performance MySQL（Schwartz et al.）/ MySQL Internals公式 / Jeremy Cole "InnoDB" シリーズ
- Percona Database Performance Blog（lock解析記事多数）
- 関連: `backend/database-performance.md`（PG版）、`backend/distributed-transactions.md`（分離レベル）、`backend/caching-strategies.md`
