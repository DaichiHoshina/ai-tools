# DBパフォーマンス ガイドライン

クエリが遅い・スループット頭打ち・本番DB調査時に参照。**PostgreSQL 16-18専用**（pg_stat_statements、EXPLAIN BUFFERS等PG固有）。MySQL/InnoDBは `backend/mysql-performance.md` 参照。Oracle/SQLiteは本書適用外。

## Tier区分

| Tier | 内容 |
|------|------|
| Tier 1（必須） | EXPLAIN、index基本、N+1検出、connection pool |
| Tier 2（規模別） | パーティショニング、partial index、covering index |
| Tier 3（深掘り） | query plan強制、HOT update、bloat管理 |

---

## 1. 「DB遅い」診断5ステップ

| Step | 確認 | コマンド/ツール |
|------|------|---------------|
| 1 | EXPLAIN ANALYZEで実行計画 | `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) <query>` |
| 2 | seq_scan vs index_scan確認 | プラン中の `Seq Scan` / `Index Scan` |
| 3 | N+1発生有無 | クエリログ件数、ORM eager load設定 |
| 4 | connection pool飽和 | `SHOW POOLS;`（PgBouncer）/ `pg_stat_activity` |
| 5 | cache hit率 | `pg_statio_user_tables.heap_blks_hit / (hit + read)` |

各Stepで原因特定したら下記の対応セクションへ。

---

## 2. EXPLAIN読み方（PG 18更新含む）

| プラン要素 | 意味 | 対処 |
|-----------|------|------|
| `Seq Scan` | 全件走査 | WHERE列にindex検討 |
| `Index Scan` | index利用 | OK（ただしBuffers大ならカバリング検討） |
| `Bitmap Heap Scan` | 複数index結合 | 複合indexで1本化検討 |
| `Hash Join` | hash結合（メモリ内） | work_mem確認、Disk spillなら拡大 |
| `Nested Loop` + 大件数 | N×M実行 | join順入替、index追加 |
| `rows estimated` 大乖離 | 統計情報古い | `ANALYZE <table>` |

**PG 18改善点**: 行推定が0.15単位で精緻化、Memory/Disk spill表示が標準化。

---

## 3. インデックス設計

| 種類 | 用途 | 例 |
|------|------|-----|
| **B-tree**（既定） | 等価・範囲・ORDER BY | `WHERE created_at > ?`, `ORDER BY id` |
| **Hash** | 等価のみ（範囲不可） | `WHERE token = ?`（B-treeで十分なケース多い） |
| **GIN** | 配列/JSONB/全文検索 | `WHERE tags @> ARRAY['x']` |
| **BRIN** | 時系列・連続値 | 巨大logテーブル、`WHERE ts BETWEEN ...` |

**設計原則**:
- 列順序 = WHERE/JOIN/ORDER BYの述語順に揃える
- 複合index `(a, b)` は `WHERE a = ?` でも効くが `WHERE b = ?` は効かない
- カバリングindex（INCLUDE句）でindex-only scan化
- 未使用indexは定期削除（`pg_stat_user_indexes.idx_scan = 0`）

```sql
CREATE INDEX idx_orders_user_status ON orders (user_id, status) INCLUDE (total);
```

---

## 4. N+1検出と対策

| ORM | 検出 | 対策 |
|-----|------|------|
| Prisma | `@prisma/sqlcommenter` でSQL trace | `include`, `select` でeager load |
| GORM | `gorm.io/plugin/prometheus` のquery count metric | `Preload("Relation")` |
| SQLAlchemy | `sqlalchemy.event` でquery count log | `joinedload`, `selectinload` |
| DataLoader | - | バッチローダーパターンで1クエリ化 |

**判定基準**: 1リクエストで同種クエリがN>10発生 → 即対処。

---

## 5. Connection Pool sizing

| 設定 | 公式 | 例（4 cores, 100 backend） |
|------|------|--------------------------|
| アプリpool max | `(CPU cores × 2) + 1` | 9 |
| PgBouncer `default_pool_size` | 10-25 / DB | 25 |
| PgBouncer `max_client_conn` | アプリ実max × backend数 | 1000 |
| `reserve_pool_size` | 管理者用 | 5 |

**監視**: PgBouncer `SHOW POOLS;` の `cl_waiting > 0` が継続 → pool不足、拡張。

---

## 6. Slow Query運用

```sql
-- PG: 1秒超のクエリをログ
ALTER SYSTEM SET log_min_duration_statement = '1000';
SELECT pg_reload_conf();

-- 統計情報拡張（pg_stat_statements）
SELECT query, calls, mean_exec_time, total_exec_time
FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10;
```

**alert閾値例**: P95レイテンシ > 200msが5分継続 → Slack通知。

---

## 7. パーティショニング

| 戦略 | 適用 | キー例 |
|------|------|-------|
| **Range（時系列）** | 古いデータ削除/集計 | `created_at` 月単位 |
| **Hash** | 均等分散、hot partition回避 | `user_id` |
| **List** | 明示的カテゴリ分離 | `region = 'jp'/'us'` |

**判定**: 単一テーブル100M行超、または直近データのみアクセス頻繁 → Range partition検討。

---

## 8. よくあるアンチパターン

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| `SELECT *` | 必要列のみ列挙 | I/O削減、index-only scan化 |
| `OFFSET 100000` | カーソルベース（`WHERE id > last_id`） | OFFSETは前N件全走査 |
| 1リクエストで複数round-trip | バッチ化、JOIN | latency累積 |
| ORMのlazy load放置 | eager load明示 | N+1温床 |
| 全列にindex | 必要列のみ、複合検討 | 書込みoverhead |
| 巨大トランザクション | 短く分割 | lock期間短縮 |

---

## 9. 参考

- PostgreSQL 18 EXPLAIN: future-architect.github.io/articles/20251008a/
- Prisma Query Optimization公式
- PgBouncer公式admin docs
- 関連ガイドライン: `backend/distributed-transactions.md`（分離レベル）, `backend/caching-strategies.md`（cache先行）
