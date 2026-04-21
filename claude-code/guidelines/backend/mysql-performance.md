# MySQL/InnoDB パフォーマンス ガイドライン

クエリ遅延・スループット限界・本番MySQL調査時に参照。**MySQL 8.4 LTS / InnoDB** 想定。PostgreSQL は `backend/database-performance.md` 参照。

## Tier 区分

| Tier | 内容 |
|------|------|
| Tier 1（必須） | EXPLAIN、PK/clustered index、N+1、isolation level |
| Tier 2（規模別） | Lock types、buffer pool、Online DDL、partition |
| Tier 3（深掘り） | InnoDB STATUS、binlog、GTID、Histogram統計 |

---

## 1. 「MySQL遅い」診断 5ステップ

| Step | 確認 | コマンド |
|------|------|---------|
| 1 | EXPLAIN（実行計画） | `EXPLAIN FORMAT=JSON <query>` |
| 2 | 実測コスト | `EXPLAIN ANALYZE <query>`（8.0.18+） |
| 3 | slow query log | `long_query_time = 1; slow_query_log = ON` |
| 4 | performance_schema | `events_statements_summary_by_digest` で頻出query抽出 |
| 5 | InnoDB status | `SHOW ENGINE INNODB STATUS\G` で lock waits/deadlock |

---

## 2. EXPLAIN の読み方（PG との違い）

| 列 | 意味 | 注目ポイント |
|----|------|-------------|
| `type` | アクセス方法 | `ALL`（全件）→ index必要、`ref`/`eq_ref`/`const`は良好 |
| `key` | 使用index | NULL → index未使用、複合index は左端一致原則 |
| `rows` | 推定行数 | 統計古いと不正確、`ANALYZE TABLE` で更新 |
| `Extra` | 追加情報 | `Using temporary` `Using filesort` は要注意 |
| `filtered` | WHERE後残存率 | 100%遠い→ index不適合、複合化検討 |

**EXPLAIN FORMAT=JSON**: cost_info / used_columns / nested_loop が見え、tuning に必須。

**PG との差**:
- MySQL: `Using filesort` = メモリ/disk ソート、tmp_table_size 超過で disk へ
- PG: 似た概念は `Sort` ノード、`work_mem` 不足で disk spill

---

## 3. InnoDB Clustered Index（PRIMARY KEY 設計が最重要）

InnoDB は **PRIMARY KEY = データの物理配置順**（clustered index）。これが MySQL の最大の特徴。

| 影響 | 内容 |
|------|------|
| **Secondary index は PK を含む** | `INDEX(name)` は内部的に `(name, id)` 構造、PK肥大化はindex全体に影響 |
| **PK挿入順序** | 非連番 PK（UUID v4等）→ ページ分割多発、書込み劣化 |
| **PK選定原則** | 短く、単調増加、不変 |

**推奨**:
- AUTO_INCREMENT BIGINT（or UUID v7 で時系列性確保）
- ❌ UUID v4 を PK にしない（書込み 30-50% 劣化報告）
- 複合 PK は最も検索される列を先頭

---

## 4. インデックス設計

| 種類 | 用途 | 例 |
|------|------|-----|
| **B+tree**（既定） | 等価・範囲・ORDER BY | 通常のWHERE |
| **Hash** | 等価のみ（MEMORY engineのみ） | 限定 |
| **Spatial** | 地理空間 | `POINT`、`LINESTRING` |
| **Full-Text** | 全文検索 | `MATCH AGAINST` |
| **Functional**（8.0+） | 式 index | `WHERE LOWER(email) = ?` |
| **Multi-Valued**（8.0+） | JSON配列 | `WHERE JSON_CONTAINS(tags, ?)` |

**原則**:
- **左端一致**: 複合index `(a,b,c)` は `WHERE a=?`/`WHERE a=? AND b=?` で効く、`WHERE b=?` 単独は効かない
- **Covering index**: SELECT列を index に含めると table参照不要（`EXTRA: Using index`）
- **Cardinality低い列を先頭にしない**: `is_active`（2値）より `user_id` を先頭に

---

## 5. Isolation Level（PG との違い注意）

| レベル | InnoDB既定 | 防げる現象 | 用途 |
|--------|-----------|-----------|------|
| **READ UNCOMMITTED** | - | （何も） | dirty read許容、稀 |
| **READ COMMITTED** | - | dirty read | 一般 OLTP（PG既定と同じ） |
| **REPEATABLE READ** | ✅ 既定 | + non-repeatable read、**phantom もMVCCで防ぐ** | InnoDB既定 |
| **SERIALIZABLE** | - | 全て | 強整合、競合激しいと性能低下 |

**PG との重要差**:
- InnoDB の REPEATABLE READ は MVCC + Next-Key Lock で **phantom もほぼ防ぐ**（PGのRR は phantom 許す）
- SERIALIZABLE は SSI ではなく純粋 lock ベース（PG とは仕組み別）

---

## 6. Lock Types（InnoDB特有）

| Lock | 対象 | 取得タイミング |
|------|------|--------------|
| **Record Lock** | index record | `SELECT ... FOR UPDATE` |
| **Gap Lock** | index 間の隙間 | RR で範囲SELECT |
| **Next-Key Lock** | Record + Gap | RR の既定（phantom 防止） |
| **Insert Intention Lock** | INSERT 待機 | concurrent INSERT |

**デッドロック対処**:
- `SHOW ENGINE INNODB STATUS` の `LATEST DETECTED DEADLOCK`
- `innodb_print_all_deadlocks = ON` で全デッドロックをエラーログへ
- lock 順序統一、TX 短く保つ

---

## 7. 主要パラメータ

| パラメータ | 推奨 | 説明 |
|-----------|------|------|
| `innodb_buffer_pool_size` | 物理RAM 70-80% | 最重要、データ+index キャッシュ |
| `innodb_log_file_size` | 1-4GB | 大きいほど crash recovery 長い、書込性能向上 |
| `innodb_flush_log_at_trx_commit` | 1（既定）or 2 | 1=ACID完全、2=1秒内データロス可で性能↑ |
| `sync_binlog` | 1（既定） | 0は性能↑だがクラッシュでbinlogロス |
| `max_connections` | 200-500 | 多すぎは memory 食う、PgBouncer類はProxySQL |
| `tmp_table_size` / `max_heap_table_size` | 64-256MB | 小さいと filesort/temp が disk へ |

---

## 8. Online DDL

| アルゴリズム | 影響 | 用途 |
|-------------|------|------|
| **INSTANT** | 即時、メタデータのみ | 末尾カラム追加（8.0+）、特定 ALTER |
| **INPLACE** | コピーなし、blocking少 | index追加、多くのDDL |
| **COPY** | テーブル全コピー、長時間ロック | INSTANT/INPLACE 不可時 |

```sql
ALTER TABLE orders ADD COLUMN note TEXT, ALGORITHM=INSTANT, LOCK=NONE;
```

判定: `ALTER ... ALGORITHM=INSTANT` 試行 → 不可なら INPLACE → 最終手段 COPY（メンテ枠 or pt-online-schema-change）。

---

## 9. パーティショニング

| 戦略 | 適用 | キー例 |
|------|------|-------|
| **RANGE** | 時系列、古いデータDROP | `created_at` 月単位 |
| **LIST** | カテゴリ分離 | `region` |
| **HASH** | 均等分散 | `user_id` |
| **KEY** | MySQL内部hash（FK使える） | `user_id` |

**注意**: パーティション pruning は WHERE が partition key を含む時のみ効く。FK は partitioned table で制限あり。

---

## 10. レプリケーション

| 種類 | 仕組み | 用途 |
|------|--------|------|
| **非同期**（既定） | binlog 送信、適用は非同期 | 一般 |
| **準同期** | 1台以上の relay 受領まで commit待ち | 整合性重視 |
| **GTID** | グローバルトランザクションID | failover 容易 |
| **Parallel Replication**（8.0 LOGICAL_CLOCK） | 並列適用、replica lag削減 | 高負荷 |

**監視**: `SHOW REPLICA STATUS\G` の `Seconds_Behind_Source`、`Replica_SQL_Running_State`。

---

## 11. アンチパターン

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| UUID v4 を PK | AUTO_INCREMENT or UUID v7 | clustered index 書込劣化 |
| `SELECT *` | 必要列のみ | covering index 化機会逃す |
| `OFFSET 100000` | キーセットページネーション（`WHERE id > last_id`）| OFFSET は前N件全走査 |
| `LIKE '%foo%'` | Full-Text or 設計見直し | 左端ワイルドカードはindex不可 |
| 巨大 IN 句（10,000+） | JOIN or temporary table | parser 重い、最適化器負担 |
| 関数を index 列に適用 | Functional index | `WHERE LOWER(email)` は index 効かず（8.0+ で functional index 可） |

---

## 12. 参考

- MySQL 8.4 LTS Reference Manual
- High Performance MySQL（Schwartz et al.）
- Percona Database Performance Blog
- 関連: `backend/database-performance.md`（PG版）、`backend/distributed-transactions.md`（分離レベル）、`backend/caching-strategies.md`
