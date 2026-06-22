# Multi-tenancy Guidelines

> **Purpose**: Data isolation, performance isolation, and compliance design when serving multiple tenants (customers) in a single system (SaaS etc.).

## Tier classification

| Tier | Content |
|------|---------|
| Tier 1 (required) | Isolation level selection, tenant identification, context propagation, cross-tenant prevention |
| Tier 2 (scale-dependent) | PostgreSQL RLS, noisy neighbor, tenant lifecycle, scaling strategies |
| Tier 3 (advanced) | Tier migration, compliance (GDPR/HIPAA), cross-tenant analytics |

---

## 1. Three isolation strategies

| Strategy | Isolation | Cost | Scale ceiling | Suitable for |
|----------|-----------|------|---------------|-------------|
| **DB isolation** (database-per-tenant) | Strongest | High (DB/license per tenant) | Low-medium (100s) | Enterprise customers, HIPAA/PCI, strict data residency |
| **Schema isolation** (schema-per-tenant, shared DB) | Strong | Medium (tables = tenants × tables) | Medium (1,000s); catalog bloat degrades perf | Mid-scale SaaS, near-strong isolation |
| **Row isolation** (shared schema, `tenant_id` column) | Weak (app-layer enforced) | Lowest | High (100,000s+; sharding possible) | B2B/B2C SaaS, cost-focused |
| **Hybrid** | Variable | Variable | Variable | Tier-based (DB isolation for premium, row for standard) |

**Selection criteria**:
- Compliance requirements (HIPAA/PCI/GDPR data residency) → DB isolation
- Tenant count (100 vs 100,000) → Row isolation
- Noisy neighbor tolerance → DB isolation if strict
- Operations model (per-tenant vs bulk migration/backup/monitoring)

**Default: Row isolation.** Easy to migrate to tier-based hybrid later. Starting with DB isolation is typical over-engineering.

---

## 2. Tenant identification (request → tenant_id resolution)

| Method | Example | Pros | Cons |
|--------|---------|------|------|
| **Subdomain** | `acme.app.com` | Natural SEO, explicit routing, bookmarkable | Requires DNS + wildcard SSL |
| **Path** | `/t/acme/dashboard` | Easy config | Verbose URL, weak SEO |
| **Custom domain** | `portal.acme.com` | White-label possible | Domain management + SSL overhead |
| **JWT claim** | `tenant_id` in token | Natural for APIs | Tenant not visible in URL |
| **Header** | `X-Tenant-ID` | Good for internal APIs | Client must manage |

**Recommendation**: Subdomain for frontend (+ custom domain support); JWT claim for internal APIs.

---

## 3. Tenant context propagation

Safely carry tenant_id throughout the request.

| Language | Mechanism |
|----------|-----------|
| **Go** | Store `tenant_id` in `context.Context`; inject via middleware |
| **Node.js** | `AsyncLocalStorage` (Node 16+) for non-blocking propagation |
| **Python** | `contextvars.ContextVar` (asyncio compatible) |
| **Java** | `ThreadLocal` (blocking) or `Reactor Context` (reactive) |

**Rules**:
- Extract once in middleware at request initialization; use context from that point on
- Inject tenant_id at **all points**: DB queries, external API calls, logs, event publish
- Reject explicitly when context is not set (fail-safe); no default tenant

---

## 4. Row isolation implementation

### Schema

```sql
-- All tenant-scoped tables require tenant_id NOT NULL
CREATE TABLE users (
  id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  email TEXT NOT NULL,
  ...
);
CREATE INDEX idx_users_tenant_email ON users(tenant_id, email);
CREATE UNIQUE INDEX uq_users_tenant_email ON users(tenant_id, email);
```

**Index design**: composite `(tenant_id, ...)` for all lookups. `tenant_id` alone is low-cardinality and inefficient.

### Query enforcement

- Auto-inject `WHERE tenant_id = :current_tenant` via ORM hook / middleware
- Raw SQL locations: detect via code review / lint
- "SELECT without tenant_id condition" → create a **forbidden lint rule**

### Join constraint

```sql
-- OK: same-tenant JOIN
SELECT o.*, u.email FROM orders o
JOIN users u ON o.user_id = u.id AND o.tenant_id = u.tenant_id
WHERE o.tenant_id = :current_tenant;
```

Cross-tenant JOIN is forbidden (always include `u.tenant_id = o.tenant_id` condition).

---

## 5. PostgreSQL RLS (Row-Level Security)

DB-layer defense against app-layer bug exposing tenant data. **Use together with app-layer enforcement** (do not rely on RLS alone).

```sql
-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE users FORCE ROW LEVEL SECURITY;  -- apply to table owner too

-- Define policy
CREATE POLICY tenant_isolation ON users
  USING (tenant_id = current_setting('app.current_tenant', true)::uuid);

-- Set per request: after BEGIN, before business query
BEGIN;
SET LOCAL app.current_tenant = '550e8400-e29b-41d4-a716-446655440000';
-- business query
COMMIT;
```

**Cautions**:
- **`SET LOCAL` is required** (under connection pool/PgBouncer transaction pooling, session-scoped `SET` leaks tenant context to next request → isolation broken). Always use `SET LOCAL` after `BEGIN` to scope to TX.
- `BYPASSRLS` privilege only for admin/migration roles (never for business roles)
- **`pg_dump` bypasses RLS by default** (table owner / superuser has `row_security=off`). For tenant-safe backup/export: (a) run with non-owner role + `row_security=on`, or (b) use app-layer export. Do not rely on pg_dump for tenant isolation.
- Logical replication also ignores RLS if run as owner; use dedicated role.

**MySQL has no RLS**. Pseudo-implementation via definer-rights VIEW + session variable is possible, but app-layer enforcement is the primary approach.

---

## 6. Noisy neighbor mitigation

Prevent one tenant's overload from impacting others.

| Mitigation | Implementation |
|-----------|---------------|
| **Connection pool isolation** | Tier-based pools (dedicated pool for premium tenants) |
| **Query rate limit** | Per-tenant API rate limit (token bucket) |
| **Query timeout** | `SET LOCAL statement_timeout = '5s'` per TX |
| **Resource quota** | CPU/memory limits (cgroup, container per tier) |
| **Monitoring isolation** | Per-tenant latency / error rate / throughput metrics |
| **Background job isolation** | Per-tenant queue or dedicated worker for heavy jobs |

**p99 monitoring**: Aggregated p99 across all tenants hides heavy tenants. Track **per-tenant p99** and global p99 separately for SLO management.

---

## 7. Tenant lifecycle

| Phase | Processing | Caution |
|-------|-----------|---------|
| **Provisioning** | Insert tenant row, seed initial schema/data, register DNS, send welcome email | Make idempotent (retry-safe) |
| **Suspension** | Set read-only; temporary pause for billing failure etc. | No hard delete; allow grace period |
| **Export** | Export all tenant data as CSV/JSON (GDPR data portability) | Large tenants: async + notification |
| **Deletion** | GDPR right to erasure; cascade delete including DB, backup, log, cache, CDN, event store | Retention period + separate audit log; verify minimum legal retention |
| **Tier migration** | Promote row → schema isolation | Minimize downtime (read-only + dump/restore + cutover) |

**Soft delete pitfall**: forgetting `deleted_at IS NULL` leaks deleted tenant data. Use explicit status enum (active/suspended/deleted).

---

## 8. Scaling strategies

### Row isolation scaling

- **Horizontal sharding**: use `tenant_id` as shard key; same tenant on same shard (no cross-shard JOIN)
- **Hot tenant mitigation**: move heavy tenants to dedicated shard (combine with tier upgrade)
- **Consistent hashing**: minimize rebalance cost when adding tenants

### Schema isolation limits

PostgreSQL with 10,000+ schemas causes catalog bloat (pg_class, pg_attribute) → query planner slowdown and autovacuum load increase. Rule of thumb: **redesign when exceeding 1,000 schemas**.

### DB isolation operations

- Run backup / restore / migration per tenant → operations automation required
- Connection pool: per-tenant or shared (PgBouncer transaction pooling)

---

## 9. Compliance

| Requirement | Response |
|-------------|---------|
| **GDPR data residency** | Region pinning (EU tenants on EU region DB); prohibit cross-region replication |
| **GDPR right to erasure** | Complete deletion flow (DB, backup, log, cache, CDN, event store) |
| **HIPAA / PCI DSS** | DB isolation recommended; separate audit log; encryption at rest/in transit; BAA |
| **SOC 2** | Per-tenant access log, change log, anomaly detection |
| **Data export** | Self-service export UI, machine-readable format |

---

## 10. Cross-tenant analytics

Do not run aggregation queries directly against production DB.

- ETL to **dedicated read replica** or **data warehouse** (Snowflake/BigQuery)
- **Anonymization**: hash `tenant_id`; mask PII
- **Aggregate only**: allow only aggregate queries, not individual records
- **Access control**: analytics role has no write access to production DB

---

## 11. Anti-patterns

| Avoid | Use instead | Reason |
|-------|-------------|--------|
| Forgetting `WHERE tenant_id = ?` | ORM hook/middleware auto-inject + lint | Other tenant data leak (critical) |
| `BYPASSRLS` role for all app operations | Business role with RLS; admin only for bypass | Accidental cross-tenant access |
| int auto-increment for tenant_id | UUID v7 or non-sequential | Enumeration attack (tenant enumeration) |
| Cross-tenant JOIN | Include tenant_id in JOIN condition | Data mixing |
| Tenant data in shared lookup table | Tenant-scoped dedicated table | Cascade breaks on deletion |
| schema-per-tenant reaching 10,000+ | Row isolation + sharding | Catalog bloat → planner slowdown |
| `deleted_at` condition omission in soft delete | Explicit status enum + hide via view | Deleted tenant data leak |
| Global list query hiding per-tenant p99 | Isolate tenant-specific monitoring | Heavy tenant goes undetected |

---

## 12. References

- "Multi-Tenant Data Architecture" (Microsoft Azure Architecture Center)
- PostgreSQL RLS official docs, AWS SaaS Factory
- "The SaaS Playbook" (Rob Walling)
- Related: `backend/database-performance.md` (index design), `backend/scalability-patterns.md` (sharding), `backend/security-hardening.md` (authorization), `backend/observability-design.md` (per-tenant metrics)
