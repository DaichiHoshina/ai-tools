# Event-Driven Architecture ガイドライン

Kafka/RabbitMQ/SQS/PubSub 等の非同期メッセージングでシステム間疎結合を実現する時に参照。Task queue 中心の単純なバッチは `design/async-job-patterns.md`、トランザクション整合は `backend/distributed-transactions.md` 参照。

## Tier 区分

| Tier | 内容 |
|------|------|
| Tier 1（必須） | broker選定、topic/partition設計、consumer group、delivery semantics |
| Tier 2（規模別） | exactly-once 実装、DLQ、retry戦略、schema registry、backpressure |
| Tier 3（深掘り） | Event Sourcing、CDC、stream processing、transactional messaging |

---

## 1. Broker 選定（2025-2026 時点）

| Broker | 強み | 弱み | 代表用途 |
|--------|------|------|---------|
| **Kafka** | 高throughput（M msg/s）、partition順序、長期retention、エコシステム | 運用重、exactly-once は transactional API必要 | Event streaming、log aggregation、CDC |
| **Redpanda** | Kafka API互換、軽量（C++、ZooKeeperなし）、低遅延 | 新しい、OSS版は機能制限 | Kafka代替、低遅延用途 |
| **RabbitMQ** | 柔軟な routing（exchange）、低遅延、運用簡単 | 順序保証はqueue単位、throughput中位 | Task queue、RPC、通知 fan-out |
| **AWS SQS Standard** | フルマネージド、無限scale | 順序保証なし、at-least-once | serverless、疎結合tasks |
| **AWS SQS FIFO** | 順序保証（MessageGroupId）、dedup | throughput低（3,000 msg/s/group） | 順序必須・低throughput |
| **AWS SNS + SQS** | Pub/Sub fan-out + 永続化 | 構成複雑 | マルチ subscriber通知 |
| **Google Pub/Sub** | フルマネージド、ack deadline制御、exactly-once delivery (Pull) | GCP前提 | GCP環境の event流通 |
| **NATS JetStream** | 軽量、低遅延、stream + KV | ecosystem小 | IoT、edge、低遅延RPC |

**判定軸**: 順序保証要件 / throughput / retention期間 / 運用コスト / vendor lock の 5軸。迷ったら Kafka 互換（Kafka / Redpanda / MSK）。

---

## 2. Topic / Partition 設計

**原則**: partition = 順序単位 = 並列度上限。

| 観点 | 指針 |
|------|------|
| partition key | 同一 entity の event を同一 partition に（例: `user_id`, `order_id`） |
| partition 数 | consumer 最大並列数に合わせる。**増やすのは容易、減らすは不可**。初期は消費 throughput の 2-3倍 |
| hot partition 回避 | key分布の偏り検査（`kafka-consumer-groups --describe`）、salt 付与で均等化 |
| topic 命名 | `{domain}.{entity}.{event}`（例: `order.v1.placed`、`user.v1.email_changed`） |
| retention | event sourcing → 長期（無期限 or compact）、通知系 → 7日程度 |

**cross-partition 順序は保証されない**。必要なら single partition（低 throughput）or timestamp+merge の自前実装。

---

## 3. Consumer Group と Delivery Semantics

| Semantics | 実装 | 用途 | 注意 |
|-----------|------|------|------|
| **at-most-once** | auto commit前に処理 | metrics送信、ロス許容 | データ欠損 |
| **at-least-once**（推奨） | 処理完了後 manual commit | 一般 OLTP | **消費側で idempotent 必須** |
| **exactly-once** | Kafka transactional producer + read_committed / SQS FIFO + dedup / Transactional Outbox | 金融、在庫 | 性能コスト大 |

**Consumer rebalance**: Kafka は **cooperative sticky**（2.4+）推奨、旧 eager は全 revoke で stop-the-world。`partition.assignment.strategy=org.apache.kafka.clients.consumer.CooperativeStickyAssignor`。

**1 partition = 最大1 consumer**。consumer 数 > partition 数 で余剰 consumer は idle。

---

## 4. Idempotent Consumer（at-least-once 受信側）

重複受信前提で設計。

```go
// dedup table で重複排除
INSERT INTO event_dedup (event_id, processed_at)
VALUES ($1, now())
ON CONFLICT (event_id) DO NOTHING RETURNING event_id;
// 挿入成功 → 未処理、失敗 → 重複スキップ
```

**設計要点**:
- event_id は producer 側で UUID 付与、全経路で保持
- dedup table は TTL/partitioning で肥大対策（例: 7日分のみ保持 + retention延長は idempotency key で代替）
- 業務 transaction と dedup insert を **同一 DB tx** に（別DBだと two-phase 問題）

---

## 5. Transactional Outbox（producer 側 exactly-once の実用解）

DB 更新と event 発行の atomicity 確保。

| Step | 処理 |
|------|------|
| 1 | 業務更新 + `outbox` テーブル insert を **同一 tx** で commit |
| 2 | 別プロセス（relay/poller or Debezium CDC）が outbox を読み → broker に publish |
| 3 | publish 成功で outbox row を削除 or marked |

**利点**: 2PC 不要、DB と broker の整合。**欠点**: relay 遅延（数 ms〜秒）、outbox テーブル管理。

CDC（Debezium 等）で outbox 読取りすると relay 自前実装不要。

---

## 6. DLQ（Dead Letter Queue）

poison pill で consumer 全停止を防ぐ。

| 設定項目 | 推奨 |
|---------|------|
| max retry | 3〜5回 |
| backoff | exponential（1s → 4s → 16s） |
| DLQ 到達条件 | retry 超過 or parse 失敗 |
| DLQ 監視 | 件数 SLO、24h以上滞留で alert |
| 再投入フロー | 手動 or 自動（原因解決後 script で main topic へ） |

**DLQ に message ごと原因 metadata を付与**（error message、stack trace、attempt count）。後で再投入や分析が可能に。

---

## 7. Schema Evolution

Avro / Protobuf / JSON Schema + **Schema Registry**（Confluent、Apicurio）で管理。

| 互換性モード | 意味 | 用途 |
|-------------|------|------|
| **BACKWARD**（既定） | 新 schema で旧 data 読める | consumer 先行更新 |
| **FORWARD** | 旧 schema で新 data 読める | producer 先行更新 |
| **FULL** | 双方向互換 | 最も厳格、推奨 |
| **NONE** | 任意変更 | 非互換変更時の一時解除 |

**破壊的変更**:
- 必須 field 追加 → FORWARD 壊れる
- field 削除 → BACKWARD 壊れる
- 型変更 → FULL 壊れる

→ major version bump + **dual write**（旧・新 topic 並走）、consumer 移行後に旧停止。

---

## 8. CDC（Change Data Capture）

DB 変更を event 化して他システムに伝播。

| ツール | 対象 | 仕組み |
|--------|------|--------|
| **Debezium** | MySQL binlog、PostgreSQL WAL、MongoDB oplog | Kafka Connect 経由で broker へ |
| **AWS DMS** | 各種 DB | CDC モードで S3/Kinesis へ |
| **native logical replication**（PG） | PostgreSQL | publication/subscription |

**snapshot + incremental**: 初回は全件 snapshot、以降は差分（WAL / binlog）。

**Outbox vs CDC**: Outbox は app 層で明示的な event 設計、CDC は DB 変更をそのまま流す。Outbox 推奨（event 契約が明確、内部カラム変更に強い）。

---

## 9. Backpressure と Lag 対策

consumer が producer に追いつかない時の対処。

| 監視 metric | 指針 |
|------------|------|
| consumer lag（`kafka-consumer-groups`） | 定常 lag が増加 → 水平 scale |
| `/sched/latencies`（Go） | consumer 内部の処理待ち |
| max.poll.records | 1回 poll 取得数、下げると per-batch 処理軽減 |

**対策優先順**:
1. consumer instance 増（partition 数まで）
2. 処理並列化（goroutine pool、worker pool）
3. partition 数増（要 rebalance、downtime 検討）
4. 処理軽量化（重い処理は別 topic + 別 consumer に分離）

---

## 10. アンチパターン

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| queue を長期 store 代わり | event sourcing or DB | broker は retention 有限が前提 |
| partition key に timestamp | entity ID | hot partition（最新に集中） |
| consumer 内で重い DB 書込を block | worker pool 経由 or 別 topic | lag 増大 |
| schema 破壊的変更を無告知 | Schema Registry + 移行ドキュメント | consumer 全停止リスク |
| event に巨大 payload | ID のみ + DB 参照（claim check パターン） | broker size 制限、network cost |
| exactly-once を自前実装 | Kafka transactional producer / Outbox | 隅のバグで整合崩壊 |
| DLQ を監視せず放置 | 件数 SLO + 再投入フロー | バグ無視 → データ欠損 |

---

## 11. 参考

- Confluent: Kafka 公式ドキュメント、Schema Registry
- 「Designing Data-Intensive Applications」(Martin Kleppmann)
- 「Enterprise Integration Patterns」(Hohpe & Woolf)
- Debezium 公式、AWS SQS/SNS 公式
- 関連: `backend/distributed-transactions.md`（Saga/Outbox の整合）、`design/async-job-patterns.md`（task queue）、`backend/observability-design.md`（consumer lag 監視）
