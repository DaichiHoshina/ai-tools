# キャッシング戦略 ガイドライン

DB負荷削減・レイテンシ改善・スループット向上が必要な時に参照。Redis/Memcached/in-process問わず適用可。

## Tier 区分

| Tier | 内容 |
|------|------|
| Tier 1（必須） | Cache-Aside、TTL設計、invalidation 基本 |
| Tier 2（規模別） | Stampede対策、2層キャッシュ、warming |
| Tier 3（深掘り） | Redis Cluster、consistent hashing |

---

## 1. キャッシュパターン比較

| パターン | 流れ | メリット | デメリット | 推奨用途 |
|---------|------|---------|----------|---------|
| **Cache-Aside**（推奨） | App: cache miss → DB → cache 書込 | 障害時 fallback 容易、明示的制御 | 実装複雑、初回 miss あり | デフォルト |
| **Read-Through** | Cache library が miss 時 DB 取得 | 実装簡潔 | cache 障害でDB直叩き、cold時 flood | Simple read系 |
| **Write-Through** | Write を cache + DB 同時 | read 時整合 | write 遅延、cache 障害で書込失敗 | 整合性最優先 |
| **Write-Behind** | cache のみ即書込、DB 非同期 | write 高速 | データ損失リスク | スコアボード等 |

**判断**: 迷ったら Cache-Aside。

---

## 2. Cache-Aside 実装（疑似コード）

```go
val, err := cache.Get(key)
if err == ErrCacheMiss {
    val = db.Query(...)
    cache.SetEX(key, val, ttl)
}
return val
```

**書込/更新時**:
```go
db.Update(...)
cache.Del(key)  // invalidate（次回 read で reload）
```

---

## 3. TTL 設計

| 種別 | 推奨 TTL | 例 |
|------|---------|-----|
| ホットデータ（頻繁更新） | 30s - 5min | ランキング |
| マスタデータ（稀更新） | 1h - 24h | 都道府県一覧 |
| ユーザーセッション | sliding 30min | ログイン状態 |
| API応答（idempotent） | 5min - 1h | 価格表 |
| ジッター付与 | TTL × (1 ± 0.1) ランダム化 | stampede予防 |

**原則**: 短すぎ → DB負荷／長すぎ → 整合性破綻。**ジッター必須**（同時失効回避）。

---

## 4. Invalidation 戦略

| 戦略 | 仕組み | 適用場面 |
|------|--------|---------|
| **TTL only** | 期限到来で自然失効 | 整合性緩い、シンプル |
| **Explicit del** | 書込時に明示削除 | ユーザー編集即反映 |
| **Tag-based** | 関連キーをタグ単位一括削除 | カテゴリ更新で配下商品全失効 |
| **Versioning** | キーに version 含める `user:v3:42` | 全件無効化を瞬時に |
| **Pub/Sub** | invalidate イベントを subscriber 配信 | 多インスタンス間同期 |

---

## 5. Cache Stampede 対策

**問題**: 人気キーが TTL 失効した瞬間、N並列がDB殺到。

| 対策 | 仕組み | 推奨 |
|------|--------|------|
| **Lock-based**（mutex） | 1スレッドのみDB照会、他は待機 | シンプル、低QPS |
| **Probabilistic Early Expiration（PER）** | TTL 残り少ない時、確率的に1スレッドが先回り更新 | **1M+ qps 必須** |
| **stale-while-revalidate** | TTL切れ後も短時間 stale 返却、裏で更新 | UX影響最小化 |

**PER 数式**:
```
expires_at - now() < beta * delta * log(rand())
```
（delta = 計算時間、beta ≈ 1.0）

---

## 6. 2層キャッシュ（local + distributed）

```
[App memory (LRU 100ms TTL)] → [Redis (5min TTL)] → [DB]
```

| 層 | レイテンシ | 用途 |
|----|----------|------|
| L1（プロセス内） | < 1ms | 同一リクエスト内重複 |
| L2（Redis等） | 1-5ms | インスタンス間共有 |
| L3（DB） | 10-100ms | 真実の源泉 |

**注意**: L1 が古い → L2 invalidate を pub/sub で全 instance に伝搬必要。

---

## 7. Redis Cluster slot 設計

- ハッシュタグ `{user_id}` で同 slot 集約 → 同 user の複数 key を1ノードに
- 横断アクセスは MGET 不可、別 slot 跨ぐと CROSSSLOT エラー
- 16384 slot を node 間で再配置可能（reshard）

---

## 8. Cache warming

- デプロイ直後、cron で hot key を事前 fetch → cold start 回避
- 失効直前に裏で再計算（PER と同思想）

---

## 9. 監視メトリクス

| 指標 | 計算 | 目標 |
|------|------|------|
| Hit rate | hit / (hit + miss) | > 80% |
| Eviction rate | evicted / total | 急増は容量不足 |
| Memory fragmentation | used_memory_rss / used_memory | 1.5以下 |
| Latency P99 | Redis SLOWLOG | < 5ms |

---

## 10. アンチパターン

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| 全 TTL 同一値 | ジッター付与 | stampede 誘発 |
| 巨大 value（> 100KB） | 分割、参照のみ cache | network/memory 負荷 |
| cache を真実の源泉化 | DB が source of truth | 障害時データロス |
| Write-Behind を整合系に | Write-Through 採用 | 書込ロスト |

---

## 11. 参考

- Redis Cache Stampede: redis.antirez.com/fundamental/cache-stampede-prevention.html
- 関連: `backend/database-performance.md`（cache hit率）, `backend/scalability-patterns.md`（read replica）
