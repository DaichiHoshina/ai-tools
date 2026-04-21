# スケーラビリティパターン ガイドライン

スループット限界・single point of failure・水平/垂直スケール判断が必要な時に参照。

## Tier 区分

| Tier | 内容 |
|------|------|
| Tier 1（必須） | Read Replica、Circuit Breaker、Timeout |
| Tier 2（規模別） | Sharding、CQRS、Bulkhead |
| Tier 3（深掘り） | Event Sourcing、Geo-distributed、CRDT |

---

## 1. スケール戦略の選択

| 戦略 | 適用 | 限界 |
|------|------|------|
| **垂直スケール**（scale-up） | DB primary、最初の選択肢 | ハード上限、コスト指数関数 |
| **水平スケール**（scale-out） | stateless app、read replica | state管理複雑化 |
| **機能分割**（vertical decomposition） | monolith → service分割 | 通信オーバーヘッド |
| **データ分割**（sharding） | 単一DB限界 | cross-shard 操作困難 |

**順序**: vertical → horizontal → microservice → sharding（過早最適化禁止）。

---

## 2. Read Replica + Eventual Consistency

```text
Write → Primary
Read → Replica (lag 100ms程度)
```

| 課題 | 対処 |
|------|------|
| 書込直後の自分の read | client 側で write後5秒は Primary 参照（cookie/header） |
| Read-your-write 必要 | session affinity、または write timestamp 記録 |
| replica lag 監視 | `pg_stat_replication.replay_lag` |
| 強整合 read | 明示的に Primary 指定 |

---

## 3. Sharding 設計

| 戦略 | 仕組み | 落とし穴 |
|------|--------|---------|
| **Hash sharding**（推奨） | hash(key) % N | reshard 困難（consistent hashing で緩和） |
| **Range sharding** | key範囲で分割 | hot range 偏り（時系列で最新 shard 集中） |
| **Geo sharding** | 地域別 | 越境クエリ高コスト |
| **Lookup table** | 動的マッピング | lookup 自体がボトルネック |

**shard key 選定基準**:
- **高 cardinality**（多様な値）
- **均等分散**（hot key 回避）
- **頻出 query 包含**（cross-shard 回避）

**アンチパターン**:
- monotonic ID（時系列ID）→ 最新 shard hotspot
- 低 cardinality（gender 等）→ shard数制限
- 集計/JOIN 多用 → cross-shard 地獄

---

## 4. CQRS（Command Query Responsibility Segregation）

| Side | 役割 | DB |
|------|------|-----|
| **Command** | 書込、ビジネスロジック | 正規化、tx重視 |
| **Query** | 読込、表示用 | 非正規化、read最適化 |

**適用判断**:
- 読み書きの**比率が大きく異なる**（read 100倍等）
- **複雑な集計クエリ**多発
- **異なる消費者**（モバイル vs 管理画面）

**コスト**: 同期遅延、二重実装、結果整合許容必須。

---

## 5. Event Sourcing

- state ではなく **event 履歴** を保存
- 現在 state は event を再生して復元

| メリット | デメリット |
|---------|----------|
| 完全な監査 | クエリ複雑（snapshot 必要） |
| time travel debug | スキーマ進化大変 |
| event 駆動連携容易 | 学習コスト高 |

**判断**: 監査必須業界（金融、医療）以外は過剰。

---

## 6. Circuit Breaker

```text
Closed（正常） → 失敗閾値超 → Open（即fail返却）
                    ↓ timeout
                Half-Open（試行）→ 成功 → Closed
                                → 失敗 → Open
```

| パラメータ | 例 |
|-----------|-----|
| 失敗閾値 | 50% / 直近20件 |
| Open 時間 | 30s |
| Half-Open 試行数 | 5 |

**ライブラリ**: hystrix（旧）、resilience4j、sony/gobreaker、polly。

---

## 7. Bulkhead パターン

リソース（thread pool, connection pool）を**機能別に分離**し、1機能の障害が全体に波及しないように。

```text
[Order Service]
  - 通常 API: pool A (size=20)
  - レポート: pool B (size=5)  // 重い処理を隔離
```

---

## 8. Timeout 戦略

| 層 | 推奨 timeout |
|----|-------------|
| HTTP client | 5-10s（user影響） |
| DB query | 3-5s |
| Cache | 100-500ms |
| Inter-service | 1-3s |
| Background job | 個別設定（数分〜時間） |

**原則**: 上流 > 下流（上流の方が長い）。下流 retry が上流 timeout を超えない設計。

---

## 9. Backpressure

producer が consumer の処理速度を超える時の対処:

| 戦略 | 仕組み |
|------|--------|
| **Drop**（log系） | 古い/新しいを捨てる |
| **Buffer + spill** | memory満→disk |
| **Flow control** | consumer から credit/window 通知（gRPC, Reactive） |
| **Rate limiting** | producer 側で速度制限 |

---

## 10. キャパシティプランニング

**基本式**:
```text
必要 instance 数 = (peak QPS × 平均 latency) / instance当たり並列数
```

例: 1000 QPS、200ms、instance 100並列 → `(1000 × 0.2) / 100 = 2 instance` + 余裕係数 (×2-3)

**Little's Law**: `L = λ × W`（系内数 = 到着率 × 滞在時間）

**監視**: P99 latency、queue depth、CPU/memory、saturation。

---

## 11. 判定フロー

```text
スループット不足？
├─ DB読み多 → Read Replica + caching
├─ DB書き多 → sharding 検討（key設計慎重）
├─ 単一 service 負荷 → horizontal scale + LB
├─ サービス間結合強 → 機能分割（microservice）
└─ 障害伝播 → Circuit Breaker + Bulkhead + Timeout
```

---

## 12. 参考

- AWS Prescriptive Guidance（patterns）
- Designing Data-Intensive Applications（書籍）
- 関連: `backend/distributed-transactions.md`（Saga）, `backend/caching-strategies.md`（read最適化）
