# Multi-tenancy ガイドライン

SaaS等で複数テナント（顧客）を1システムで捌く時のデータ分離・性能隔離・compliance 設計。

## Tier 区分

| Tier | 内容 |
|------|------|
| Tier 1（必須） | 分離レベル選択、tenant 識別、context 伝播、誤クロス防止 |
| Tier 2（規模別） | PostgreSQL RLS、noisy neighbor、tenant lifecycle、scaling 戦略 |
| Tier 3（深掘り） | tier 間 migration、compliance（GDPR/HIPAA）、cross-tenant analytics |

---

## 1. 分離レベル 3戦略

| 戦略 | 分離粒度 | コスト | スケール上限 | 向く用途 |
|------|---------|--------|------------|---------|
| **DB 分離**（database-per-tenant） | 最強 | 高（tenant数だけDB／ライセンス） | 低〜中（100s） | Enterprise顧客、HIPAA/PCI、data residency厳格 |
| **Schema 分離**（schema-per-tenant、shared DB） | 強 | 中（table数 = tenant × table） | 中（1,000s）、catalog肥大で性能劣化 | 中規模 SaaS、準強い分離 |
| **Row 分離**（shared schema、`tenant_id` 列） | 弱（app層強制） | 最低 | 高（100,000s〜、sharding可） | B2B/B2C SaaS、コスト重視 |
| **Hybrid** | 可変 | 可変 | 可変 | tier別（premium のみ DB分離、standard は row） |

**選定軸**:
- compliance 要件（HIPAA/PCI/GDPR data residency）→ DB 分離
- tenant 数（想定100 vs 100,000）→ Row 分離
- noisy neighbor 許容度 → 厳格なら DB 分離
- 運用体制（migration、backup、monitoring を tenant 毎 vs 一括）

**既定は Row 分離**。後から tier別 hybrid に移行しやすい。初期から DB 分離は overengineering の典型。

---

## 2. Tenant 識別（リクエスト → tenant_id 解決）

| 方式 | 例 | 利点 | 欠点 |
|------|-----|------|------|
| **subdomain** | `acme.app.com` | SEO自然、routing明示、ブックマーク可能 | DNS + wildcard SSL 必要 |
| **path** | `/t/acme/dashboard` | 設定簡単 | URL 冗長、SEO 弱 |
| **custom domain** | `portal.acme.com` | white-label 可 | domain 管理・SSL 追加 |
| **JWT claim** | token 内 `tenant_id` | API に自然 | URL から tenant 不明、リンク共有しにくい |
| **header** | `X-Tenant-ID` | 内部 API に好適 | クライアント側で管理必要 |

**推奨**: フロント向けは subdomain（+ custom domain サポート）、内部 API は JWT claim。

---

## 3. Tenant Context 伝播

request 全体で tenant_id を安全に引き回す。

| 言語 | 手段 |
|------|------|
| **Go** | `context.Context` に `tenant_id` 格納、middleware で注入 |
| **Node.js** | `AsyncLocalStorage`（Node 16+）で non-blocking 伝播 |
| **Python** | `contextvars.ContextVar`（asyncio 対応） |
| **Java** | `ThreadLocal`（blocking）or `Reactor Context`（reactive） |

**原則**:
- middleware で request 初期化時に 1回だけ抽出、以降は context 経由
- DB query、外部 API 呼出、log、event publish の **全箇所で tenant_id 注入**
- context 未設定時は **明示的に reject**（fail-safe）、デフォルト tenant 禁止

---

## 4. Row 分離の実装

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

**index 設計**: `(tenant_id, ...)` 複合 index を全 lookup に。`tenant_id` 単独 index は cardinality 低で非効率。

### Query 強制

- ORM hook / middleware で全 query に `WHERE tenant_id = :current_tenant` 自動注入
- 生 SQL 書く箇所は code review / lint で検出
- 「tenant_id を条件に含まない SELECT」は **禁止 lint rule** を作る

### 結合の制約

```sql
-- OK: 同一 tenant 内 JOIN
SELECT o.*, u.email FROM orders o
JOIN users u ON o.user_id = u.id AND o.tenant_id = u.tenant_id
WHERE o.tenant_id = :current_tenant;
```

cross-tenant JOIN は禁止（`u.tenant_id = o.tenant_id` 条件を必ず付ける）。

---

## 5. PostgreSQL RLS（Row-Level Security）

app 層 bug で tenant 漏洩を防ぐ DB 層防御。**app 層強制と併用**（RLS だけに依存せず二重化）。

```sql
-- RLS 有効化
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE users FORCE ROW LEVEL SECURITY;  -- table owner にも適用

-- policy 定義
CREATE POLICY tenant_isolation ON users
  USING (tenant_id = current_setting('app.current_tenant', true)::uuid);

-- connection 毎に session variable 設定
SET app.current_tenant = '550e8400-e29b-41d4-a716-446655440000';
```

**注意**:
- `SET LOCAL app.current_tenant` は tx 内限定（connection pool 使用時は必須）
- `BYPASSRLS` 権限を持つ role で admin/migration 操作（業務 role は持たせない）
- pg_dump / logical replication の挙動確認（RLS 適用される）

**MySQL は RLS 非対応**。定義者権限付き VIEW + session variable で擬似実装可能だが、基本 app 層強制が本命。

---

## 6. Noisy Neighbor 対策

1 tenant の過負荷が他に波及しない仕組み。

| 対策 | 実装 |
|------|------|
| **connection pool 分離** | tier別 pool（premium tenant に dedicated pool） |
| **query rate limit** | tenant 毎の API rate limit（token bucket） |
| **query timeout** | `SET LOCAL statement_timeout = '5s'` per tx |
| **resource quota** | CPU/memory limit（cgroup、container per tier） |
| **monitoring 分離** | tenant 毎の latency / error rate / throughput metric |
| **background job 分離** | heavy job は per-tenant queue or dedicated worker |

**p99 monitoring**: 全 tenant 合算だと heavy tenant が p99 を支配して invisible に。**tenant 別 p99** と全体 p99 を分けて SLO 管理。

---

## 7. Tenant Lifecycle

| Phase | 処理 | 注意 |
|-------|------|------|
| **provisioning** | tenant 行 insert、初期 schema/data seed、DNS 登録、welcome email | idempotent に（retry 安全） |
| **suspension** | 読取専用化、billing failure等で一時停止 | hard delete しない、猶予期間 |
| **export** | 全 tenant data を CSV/JSON でエクスポート（GDPR data portability） | large tenant は async + 通知 |
| **deletion** | GDPR right to erasure、cascade delete、backup 含む完全消去 | retention 期間 + audit log 別保存、法的最低保持義務確認 |
| **tier migration** | row → schema 分離への昇格 | 低 down-time（読取専用化 + dump/restore + 切替） |

**soft delete の落とし穴**: `deleted_at IS NULL` 条件を忘れると削除済み tenant の data が leak。tenant status は enum（active/suspended/deleted）で明示。

---

## 8. Scaling 戦略

### Row 分離での scaling

- **水平 sharding**: `tenant_id` を shard key に。同一 tenant は同一 shard に集約（cross-shard JOIN 不要）
- **hot tenant 対策**: heavy tenant を dedicated shard に分離（tier 昇格と組合せ）
- **consistent hashing**: tenant 追加時の rebalance コスト最小化

### Schema 分離の限界

PostgreSQL で schema 10,000+ は catalog 肥大（pg_class、pg_attribute）で query planner 遅延、autovacuum 負荷増。経験則で **1,000 schemas 超えたら要設計見直し**。

### DB 分離の運用

- tenant 毎に backup / restore / migration 実行 → 運用自動化必須
- connection pool は tenant 単位 or shared（PgBouncer の transaction pooling）

---

## 9. Compliance

| 要件 | 対応 |
|------|------|
| **GDPR data residency** | region pinning（EU tenant は EU region DB）、cross-region replication 禁止 |
| **GDPR right to erasure** | 完全削除フロー（DB、backup、log、cache、CDN、event store） |
| **HIPAA / PCI DSS** | DB分離推奨、audit log 分離、encryption at rest/in transit、BAA |
| **SOC 2** | tenant 毎の access log、change log、anomaly detection |
| **data export** | self-service export UI、machine-readable format |

---

## 10. Cross-tenant Analytics

集約データ分析は production DB で直接やらない。

- **dedicated read replica** or **data warehouse**（Snowflake/BigQuery）に ETL
- **anonymization**: `tenant_id` を hash 化、PII マスク
- **aggregate only**: 個別 record でなく集計 query のみ許可
- **access control**: analytics 用 role は production DB 書込権限なし

---

## 11. アンチパターン

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| `WHERE tenant_id = ?` 書き忘れ | ORM hook / middleware 自動注入 + lint | 他 tenant data 漏洩（critical） |
| `BYPASSRLS` role で全 app 動作 | 業務 role は RLS 適用、admin のみ bypass | 事故で全 tenant 横断 |
| tenant_id を int auto-increment | UUID v7 等の非連番 | enumeration 攻撃（tenant 列挙） |
| cross-tenant JOIN | tenant_id を JOIN 条件に含める | データ混在 |
| shared lookup table に tenant データ混在 | tenant-scoped 専用 table | 削除時 cascade 破綻 |
| schema-per-tenant で 10,000+ 到達 | row 分離 + sharding | catalog 肥大 → planner 遅延 |
| soft delete の `deleted_at` 条件漏れ | status enum で明示 + view で隠蔽 | 削除済 tenant data leak |
| global 一覧 query が tenant別 p99 を隠す | tenant 別 metric を分離監視 | heavy tenant 見逃し |

---

## 12. 参考

- 「Multi-Tenant Data Architecture」(Microsoft Azure Architecture Center)
- PostgreSQL RLS 公式、AWS SaaS Factory
- 「The SaaS Playbook」(Rob Walling)
- 関連: `backend/database-performance.md`（index 設計）、`backend/scalability-patterns.md`（sharding）、`backend/security-hardening.md`（認可）、`backend/observability-design.md`（tenant 別 metric）
