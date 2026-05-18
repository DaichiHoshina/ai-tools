# Multi-tenancyガイドライン

SaaS等で複数テナント（顧客）を1システムで捌く時のデータ分離・性能隔離・compliance設計。

## Tier区分

| Tier | 内容 |
|------|------|
| Tier 1（必須） | 分離レベル選択、tenant識別、context伝播、誤クロス防止 |
| Tier 2（規模別） | PostgreSQL RLS、noisy neighbor、tenant lifecycle、scaling戦略 |
| Tier 3（深掘り） | tier間migration、compliance（GDPR/HIPAA）、cross-tenant analytics |

---

## 1. 分離レベル3戦略

| 戦略 | 分離粒度 | コスト | スケール上限 | 向く用途 |
|------|---------|--------|------------|---------|
| **DB分離**（database-per-tenant） | 最強 | 高（tenant数だけDB／ライセンス） | 低〜中（100s） | Enterprise顧客、HIPAA/PCI、data residency厳格 |
| **Schema分離**（schema-per-tenant、shared DB） | 強 | 中（table数 = tenant × table） | 中（1,000s）、catalog肥大で性能劣化 | 中規模SaaS、準強い分離 |
| **Row分離**（shared schema、`tenant_id` 列） | 弱（app層強制） | 最低 | 高（100,000s〜、sharding可） | B2B/B2C SaaS、コスト重視 |
| **Hybrid** | 可変 | 可変 | 可変 | tier別（premiumのみDB分離、standardはrow） |

**選定軸**:
- compliance要件（HIPAA/PCI/GDPR data residency）→ DB分離
- tenant数（想定100 vs 100,000）→ Row分離
- noisy neighbor許容度 → 厳格ならDB分離
- 運用体制（migration、backup、monitoringをtenant毎vs一括）

**既定はRow分離**。後からtier別hybridに移行しやすい。初期からDB分離はoverengineeringの典型。

---

## 2. Tenant識別（リクエスト → tenant_id解決）

| 方式 | 例 | 利点 | 欠点 |
|------|-----|------|------|
| **subdomain** | `acme.app.com` | SEO自然、routing明示、ブックマーク可能 | DNS + wildcard SSL必要 |
| **path** | `/t/acme/dashboard` | 設定簡単 | URL冗長、SEO弱 |
| **custom domain** | `portal.acme.com` | white-label可 | domain管理・SSL追加 |
| **JWT claim** | token内 `tenant_id` | APIに自然 | URLからtenant不明、リンク共有しにくい |
| **header** | `X-Tenant-ID` | 内部APIに好適 | クライアント側で管理必要 |

**推奨**: フロント向けはsubdomain（+ custom domainサポート）、内部APIはJWT claim。

---

## 3. Tenant Context伝播

request全体でtenant_idを安全に引き回す。

| 言語 | 手段 |
|------|------|
| **Go** | `context.Context` に `tenant_id` 格納、middlewareで注入 |
| **Node.js** | `AsyncLocalStorage`（Node 16+）でnon-blocking伝播 |
| **Python** | `contextvars.ContextVar`（asyncio対応） |
| **Java** | `ThreadLocal`（blocking）or `Reactor Context`（reactive） |

**原則**:
- middlewareでrequest初期化時に1回だけ抽出、以降はcontext経由
- DB query、外部API呼出、log、event publishの **全箇所でtenant_id注入**
- context未設定時は **明示的にreject**（fail-safe）、デフォルトtenant禁止

---

## 4. Row分離の実装

### スキーマ

```sql
-- 全 tenant-scoped テーブルに tenant_id NOT NULL
CREATE TABLE users (
  id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  email TEXT NOT NULL,
  ...
);
CREATE INDEX idx_users_tenant_email ON users(tenant_id, email);
CREATE UNIQUE INDEX uq_users_tenant_email ON users(tenant_id, email);
```

**index設計**: `(tenant_id, ...)` 複合indexを全lookupに。`tenant_id` 単独indexはcardinality低で非効率。

### Query強制

- ORM hook / middlewareで全queryに `WHERE tenant_id = :current_tenant` 自動注入
- 生SQL書く箇所はcode review / lintで検出
- 「tenant_idを条件に含まないSELECT」は **禁止lint rule** を作る

### 結合の制約

```sql
-- OK: 同一 tenant 内 JOIN
SELECT o.*, u.email FROM orders o
JOIN users u ON o.user_id = u.id AND o.tenant_id = u.tenant_id
WHERE o.tenant_id = :current_tenant;
```

cross-tenant JOINは禁止（`u.tenant_id = o.tenant_id` 条件を必ず付ける）。

---

## 5. PostgreSQL RLS（Row-Level Security）

app層bugでtenant漏洩を防ぐDB層防御。**app層強制と併用**（RLSだけに依存せず二重化）。

```sql
-- RLS 有効化
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE users FORCE ROW LEVEL SECURITY;  -- table owner にも適用

-- policy 定義
CREATE POLICY tenant_isolation ON users
  USING (tenant_id = current_setting('app.current_tenant', true)::uuid);

-- request 毎に BEGIN 直後で SET LOCAL（tx 終了で自動解除）
BEGIN;
SET LOCAL app.current_tenant = '550e8400-e29b-41d4-a716-446655440000';
-- 業務 query
COMMIT;
```

**注意**:
- **`SET LOCAL` 必須**（connection pool/PgBouncer transaction pooling下でsession-scoped `SET` は次requestにtenant contextが漏洩 → isolation崩壊）。必ず `BEGIN` 後に `SET LOCAL` でtx scopeに限定
- `BYPASSRLS` 権限を持つroleでadmin/migration操作（業務roleは持たせない）
- **`pg_dump` はRLSをbypassするのが既定**（table owner / superuserは `row_security=off` デフォルト）。backup/exportをtenant-safeにするには (a) 非owner role + `row_security=on` で実行、または (b) app経由のexportを使う。pg_dumpにtenant隔離を任せない
- logical replicationもowner実行ならRLS無視、専用role必須

**MySQLはRLS非対応**。定義者権限付きVIEW + session variableで擬似実装可能だが、基本app層強制が本命。

---

## 6. Noisy Neighbor対策

1 tenantの過負荷が他に波及しない仕組み。

| 対策 | 実装 |
|------|------|
| **connection pool分離** | tier別pool（premium tenantにdedicated pool） |
| **query rate limit** | tenant毎のAPI rate limit（token bucket） |
| **query timeout** | `SET LOCAL statement_timeout = '5s'` per tx |
| **resource quota** | CPU/memory limit（cgroup、container per tier） |
| **monitoring分離** | tenant毎のlatency / error rate / throughput metric |
| **background job分離** | heavy jobはper-tenant queue or dedicated worker |

**p99 monitoring**: 全tenant合算だとheavy tenantがp99を支配してinvisibleに。**tenant別p99** と全体p99を分けてSLO管理。

---

## 7. Tenant Lifecycle

| Phase | 処理 | 注意 |
|-------|------|------|
| **provisioning** | tenant行insert、初期schema/data seed、DNS登録、welcome email | idempotentに（retry安全） |
| **suspension** | 読取専用化、billing failure等で一時停止 | hard deleteしない、猶予期間 |
| **export** | 全tenant dataをCSV/JSONでエクスポート（GDPR data portability） | large tenantはasync + 通知 |
| **deletion** | GDPR right to erasure、cascade delete、backup含む完全消去 | retention期間 + audit log別保存、法的最低保持義務確認 |
| **tier migration** | row → schema分離への昇格 | 低down-time（読取専用化 + dump/restore + 切替） |

**soft deleteの落とし穴**: `deleted_at IS NULL` 条件を忘れると削除済みtenantのdataがleak。tenant statusはenum（active/suspended/deleted）で明示。

---

## 8. Scaling戦略

### Row分離でのscaling

- **水平sharding**: `tenant_id` をshard keyに。同一tenantは同一shardに集約（cross-shard JOIN不要）
- **hot tenant対策**: heavy tenantをdedicated shardに分離（tier昇格と組合せ）
- **consistent hashing**: tenant追加時のrebalanceコスト最小化

### Schema分離の限界

PostgreSQLでschema 10,000+ はcatalog肥大（pg_class、pg_attribute）でquery planner遅延、autovacuum負荷増。経験則で **1,000 schemas超えたら要設計見直し**。

### DB分離の運用

- tenant毎にbackup / restore / migration実行 → 運用自動化必須
- connection poolはtenant単位or shared（PgBouncerのtransaction pooling）

---

## 9. Compliance

| 要件 | 対応 |
|------|------|
| **GDPR data residency** | region pinning（EU tenantはEU region DB）、cross-region replication禁止 |
| **GDPR right to erasure** | 完全削除フロー（DB、backup、log、cache、CDN、event store） |
| **HIPAA / PCI DSS** | DB分離推奨、audit log分離、encryption at rest/in transit、BAA |
| **SOC 2** | tenant毎のaccess log、change log、anomaly detection |
| **data export** | self-service export UI、machine-readable format |

---

## 10. Cross-tenant Analytics

集約データ分析はproduction DBで直接やらない。

- **dedicated read replica** or **data warehouse**（Snowflake/BigQuery）にETL
- **anonymization**: `tenant_id` をhash化、PIIマスク
- **aggregate only**: 個別recordでなく集計queryのみ許可
- **access control**: analytics用roleはproduction DB書込権限なし

---

## 11. アンチパターン

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| `WHERE tenant_id = ?` 書き忘れ | ORM hook / middleware自動注入 + lint | 他tenant data漏洩（critical） |
| `BYPASSRLS` roleで全app動作 | 業務roleはRLS適用、adminのみbypass | 事故で全tenant横断 |
| tenant_idをint auto-increment | UUID v7等の非連番 | enumeration攻撃（tenant列挙） |
| cross-tenant JOIN | tenant_idをJOIN条件に含める | データ混在 |
| shared lookup tableにtenantデータ混在 | tenant-scoped専用table | 削除時cascade破綻 |
| schema-per-tenantで10,000+ 到達 | row分離 + sharding | catalog肥大 → planner遅延 |
| soft deleteの `deleted_at` 条件漏れ | status enumで明示 + viewで隠蔽 | 削除済tenant data leak |
| global一覧queryがtenant別p99を隠す | tenant別metricを分離監視 | heavy tenant見逃し |

---

## 12. 参考

- 「Multi-Tenant Data Architecture」(Microsoft Azure Architecture Center)
- PostgreSQL RLS公式、AWS SaaS Factory
- 「The SaaS Playbook」(Rob Walling)
- 関連: `backend/database-performance.md`（index設計）、`backend/scalability-patterns.md`（sharding）、`backend/security-hardening.md`（認可）、`backend/observability-design.md`（tenant別metric）
