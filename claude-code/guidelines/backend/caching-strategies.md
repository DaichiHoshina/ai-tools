# Caching Strategies Guidelines

Reference for reducing DB load, improving latency, and increasing throughput. Applies to Redis/Memcached/in-process caching.

## Tier classification

| Tier | Content |
|------|---------|
| Tier 1 (required) | Cache-Aside, TTL design, basic invalidation |
| Tier 2 (scale-dependent) | Stampede protection, two-tier cache, warming |
| Tier 3 (advanced) | Redis Cluster, consistent hashing |

---

## 1. Cache pattern comparison

| Pattern | Flow | Pros | Cons | Use |
|---------|------|------|------|-----|
| **Cache-Aside** (recommended) | App: cache miss → DB → write cache | Easy fallback on failure, explicit control | More code, cold miss | Default |
| **Read-Through** | Cache library fetches DB on miss | Simple code | Cache failure → DB flood; cold start flood | Simple reads |
| **Write-Through** | Write to cache + DB simultaneously | Consistent on read | Write latency; cache failure breaks writes | Consistency-critical |
| **Write-Behind** | Write cache only; async DB sync | Fast writes | Data loss risk | Scoreboards etc. |

**Default**: Cache-Aside when in doubt.

---

## 2. Cache-Aside implementation

```go
val, err := cache.Get(key)
if err == ErrCacheMiss {
    val = db.Query(...)
    cache.SetEX(key, val, ttl)
}
return val
```

**On write/update**:
```go
db.Update(...)
cache.Del(key)  // invalidate; next read reloads
```

---

## 3. TTL design

| Type | Recommended TTL | Example |
|------|----------------|---------|
| Hot data (frequent updates) | 30s - 5min | Rankings |
| Master data (rare updates) | 1h - 24h | Prefecture list |
| User session | sliding 30min | Login state |
| API response (idempotent) | 5min - 1h | Price table |
| Jitter | TTL × (1 ± 0.1) random | Stampede prevention |

**Rule**: Too short → DB load; too long → stale data. **Jitter is required** (prevents simultaneous expiry).

---

## 4. Invalidation strategies

| Strategy | Mechanism | Use |
|----------|-----------|-----|
| **TTL only** | Natural expiry | Loose consistency, simple |
| **Explicit delete** | Delete on write | Immediate reflect on user edit |
| **Tag-based** | Bulk delete keys by tag | Category update invalidates all child items |
| **Versioning** | Include version in key `user:v3:42` | Instant full invalidation |
| **Pub/Sub** | Publish invalidation event to subscribers | Multi-instance sync |

---

## 5. Cache stampede protection

**Problem**: Popular key expires; N concurrent requests flood DB.

| Strategy | Mechanism | Use |
|----------|-----------|-----|
| **Lock-based (mutex)** | Only 1 thread queries DB; others wait | Simple, low QPS |
| **Probabilistic Early Expiration (PER)** | Near-expiry: 1 thread proactively refreshes | **Required at 1M+ QPS** |
| **stale-while-revalidate** | Serve stale briefly after expiry; refresh in background | Minimize UX impact |

**PER formula**:
```text
expires_at - now() < beta * delta * log(rand())
```
(delta = computation time, beta ≈ 1.0)

---

## 6. Two-tier cache (local + distributed)

```text
[App memory (LRU 100ms TTL)] → [Redis (5min TTL)] → [DB]
```

| Tier | Latency | Use |
|------|---------|-----|
| L1 (in-process) | < 1ms | Dedup within same request |
| L2 (Redis etc.) | 1-5ms | Share across instances |
| L3 (DB) | 10-100ms | Source of truth |

**Note**: L1 stale → propagate L2 invalidation to all instances via pub/sub.

---

## 7. Redis Cluster slot design

- Hash tag `{user_id}` collocates keys → same user's keys on same node
- Cross-slot access: MGET not available; different slots → CROSSSLOT error
- 16384 slots can be resharded across nodes

---

## 8. Cache warming

- Pre-fetch hot keys after deploy via cron → avoids cold start
- Recompute in background before expiry (same idea as PER)

---

## 9. Monitoring metrics

| Metric | Calculation | Target |
|--------|-------------|--------|
| Hit rate | hit / (hit + miss) | > 80% |
| Eviction rate | evicted / total | Rapid increase = capacity issue |
| Memory fragmentation | used_memory_rss / used_memory | ≤ 1.5 |
| Latency P99 | Redis SLOWLOG | < 5ms |

---

## 10. Anti-patterns

| Avoid | Use instead | Reason |
|-------|-------------|--------|
| All TTLs identical | Add jitter | Stampede trigger |
| Large value (> 100KB) | Split; cache reference only | Network/memory overhead |
| Cache as source of truth | DB is source of truth | Data loss on failure |
| Write-Behind for consistency-critical | Write-Through | Write loss risk |

---

## 11. References

- Redis Cache Stampede: redis.antirez.com
- Related: `backend/database-performance.md` (cache hit rate), `backend/scalability-patterns.md` (read replica)
