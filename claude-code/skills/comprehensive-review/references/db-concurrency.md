# db-concurrency review reference

InnoDB暗黙デッドロック・lock wait timeout・hot row競合をdiffから検出する観点。SQL文字列 + TX境界 + isolation設定の組み合わせで判定する。

詳細背景は`guidelines/backend/mysql-performance.md` §6-7参照。

## 検出パターン (high precision優先)

### P1. UPDATE/SELECT FOR UPDATE順序不定

**症状**: 同一TXで複数rowを更新する際、入力配列をsortせず発行 → 別TXと逆順アクセスでデッドロック (§7.2パターンA)。

**検出シグナル**:

| シグナル | grepパターン例 |
|---------|---------------|
| ループ内のUPDATE/DELETE | `for .* { .*tx.*Exec.*UPDATE\|DELETE` |
| 関数内2+のUPDATE文、ID元が引数 | UPDATEを2箇所以上 + 引数の`IDs []int64`等 |
| `IN (?, ?, ?)` の引数sort不在 | `IN (` + 直前にsortなし |

**判定基準**: UPDATE発行前に`sort.Slice(ids, ...)` / `ORDER BY` / 単調なPK昇順保証が**ない**場合Warning。引数のID配列が呼び出し元で常にsort保証されているならコメントで明示要求。

**修正提案**: SQL側`ORDER BY id`、またはapp層で`slices.Sort(ids)`してから発行。

### P2. RR + 非unique/範囲FOR UPDATE + 後続INSERT

**症状**: gap lock取得 → 同TX/別TXのINSERTがInsert Intention非互換で待機 → 環状デッドロック (§7.2パターンB)。

**検出シグナル**:

| シグナル | 例 |
|---------|---|
| `SELECT ... FOR UPDATE` + `WHERE <非PK> =` or範囲 | `FOR UPDATE` + `BETWEEN\|IN\|>\|<` |
| 同TX内で同table/同条件のINSERT | 直後に`INSERT INTO <同table>` |
| 8.0未満のisolation明示なし | 既定RR、MySQL 8.0+も既定はRR |

**判定基準**: 3条件 (非unique FOR UPDATE / 同TX後続INSERT / RR isolation) のうち2+成立でWarning、3つ揃えばCritical候補。

**修正提案**:
- isolationをRCへ降格 (`tx.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelReadCommitted})`)
- FOR UPDATEをunique等価条件に書き換え
- TX分割しSELECT結果を外側で受け取りINSERT前に解放

### P3. INSERT ... ON DUPLICATE KEY UPDATEの並行upsert

**症状**: unique検査でS lock → UPDATE経路でX昇格、同keyへの並行upsertが昇格デッドロック (§7.2パターンC)。

**検出シグナル**:

| シグナル | 例 |
|---------|---|
| `ON DUPLICATE KEY UPDATE` | リテラル一致 |
| handler/worker内の直接呼び出し | concurrency想定箇所 |
| multi-row VALUES + ODKU | bulk upsert |

**判定基準**: ODKU使用箇所が並行実行可能な経路 (handler/job/worker) かつ同一keyに集中する可能性ありでWarning。idempotent前提のmigration内ODKUは対象外。

**修正提案**:
- `INSERT IGNORE` + 別途`UPDATE`に分離
- 事前`SELECT FOR UPDATE`でX取得後に分岐
- 同一key集中なら別keyへshardingまたはqueue化

### P4. FKチェーンの暗黙S lock

**症状**: 子INSERT/UPDATE → 親rowに暗黙S lock。別TXが親をX取得 → 待機。子操作と親更新が双方向で起きると環状 (§7.2パターンD)。

**検出シグナル**:

| シグナル | 例 |
|---------|---|
| schema/migrationの`FOREIGN KEY` | `REFERENCES` |
| 同TX内で親UPDATE + 子INSERT/UPDATE混在 | 順序不定 |

**判定基準**: 親子両方の書き込みが同TXに同居 + 親rowが複数handlerから更新されるテーブルならWarning。

**修正提案**: FK削除 (整合性app担保) / 親と子の更新順序統一 / TX分割。

### P5. UPDATE/DELETE without index

**症状**: 非indexed列WHEREのUPDATE/DELETE → 全行scan + 全行row lock → 事実上table lock → デッドロック頻発・lock wait timeout頻発。

**検出シグナル**:

| シグナル | 例 |
|---------|---|
| `UPDATE\|DELETE FROM .+ WHERE <列名>` | 列名がschema上indexedか確認要 |
| migrationにそのWHERE列のindex不在 | `CREATE INDEX` grep |

**判定基準**: schema/migrationを参照して該当列にindexがなければCritical候補 (deadlock直結)。

**修正提案**: index追加。EXPLAIN実行で`type=ALL`なら確定。

### P6. TX内外部I/O

**症状**: TX中にHTTP / gRPC / message publish / time.Sleep → 外部レイテンシ中もlock保持、deadlock/timeout頻発。

**検出シグナル**:

| シグナル | 例 |
|---------|---|
| TX境界内に外部call | `tx.Begin` ~ `tx.Commit`の間に`http.Get` / `client.Call` / `Publish` / `sleep` |
| ORM TX scope内のwait | `db.Transaction(func(tx) { ... external })`内のIO |

**判定基準**: TX scope内に同期外部call検出 → Critical (deadlock以前にlock wait timeoutが頻発)。

**修正提案**: 外部I/O完了後にTX開く / outbox patternでDB commitとmessage送信を分離。

### P7. デッドロックretry不在

**症状**: TX関数がER_LOCK_DEADLOCK (1213) で即fail → ユーザー操作失敗増。InnoDBは敗者TXを自動ROLLBACK済みなのでretry安全。

**検出シグナル**:

| シグナル | 例 |
|---------|---|
| TX wrapper関数にretry loop不在 | `for ... retry`なし |
| error判定なし | mysql errno 1213チェックなし |

**判定基準**: TX境界を持つ共通関数 (repo/store/uow層) でretry実装が欠落 → Warning。1回起動限りのscript/migrationは対象外。

**修正提案**: 指数backoff + jitterのretry実装 (mysql-performance.md §7.4の雛形)。

### P8. AUTO-INC lock mode誤用

**症状**: bulk INSERT + `lastInsertID + i`採番が`innodb_autoinc_lock_mode=2` (8.0既定) で連番非保証 → IDズレ。

**検出シグナル**: mysql-performance.md §17で別途網羅 (bulk-insert-correctness観点)。本観点ではcross-reference扱い、重複出力しない。

## 出力ガイド

| Severity | 条件 |
|----------|-----|
| Critical | P2全条件成立 / P5 (indexed確認後欠如確定) / P6 (外部I/O検出明確) |
| Warning | P1 / P3 / P4 / P7 / P2部分成立 |
| Note | schema未参照で確定できないP5、idempotent前提のP3など |

## False Positive回避

- migration script / 一回起動batch / 単体テストfixture → P3/P7適用外
- TX境界が判定不能 (autocommit前提のORM call) → 検出しない
- isolation設定が`READ COMMITTED`明示済 → P2のgap lock系除外
- schema未参照でindex有無不明 → P5はnote止まり

## 関連

- `guidelines/backend/mysql-performance.md` §6-7 (lock/deadlock詳細)
- `guidelines/backend/database-performance.md` (PG版、PGはMVCC差でserialization failure→retry経路)
- `guidelines/backend/distributed-transactions.md` (isolation level設計判断)
