# Event-Driven Architectureガイドライン

Kafka/RabbitMQ/SQS/PubSub等の非同期メッセージング設計時に参照。単純バッチは `design/async-job-patterns.md`、TX整合は `backend/distributed-transactions.md` 参照。

## Tier区分

| Tier | 内容 |
|------|------|
| Tier 1（必須） | broker選定、topic/partition設計、consumer group、delivery semantics |
| Tier 2（規模別） | exactly-once実装、DLQ、retry戦略、schema registry、backpressure |
| Tier 3（深掘り） | Event Sourcing、CDC、stream processing、transactional messaging |

---

## 1. Broker選定（2025-2026時点）

| Broker | 強み | 弱み | 代表用途 |
|--------|------|------|---------|
| **Kafka** | 高throughput（M msg/s）、partition順序、長期retention、エコシステム | 運用重、exactly-onceはtransactional API必要 | Event streaming、log aggregation、CDC |
| **Redpanda** | Kafka API互換、軽量（C++、ZooKeeperなし）、低遅延 | 新しい、OSS版は機能制限 | Kafka代替、低遅延用途 |
| **RabbitMQ** | 柔軟なrouting（exchange）、低遅延、運用簡単 | 順序保証はqueue単位、throughput中位 | Task queue、RPC、通知fan-out |
| **AWS SQS Standard** | フルマネージド、無限scale | 順序保証なし、at-least-once | serverless、疎結合tasks |
| **AWS SQS FIFO** | 順序保証（MessageGroupId）、dedup | throughput低（3,000 msg/s/group） | 順序必須・低throughput |
| **AWS SNS + SQS** | Pub/Sub fan-out + 永続化 | 構成複雑 | マルチsubscriber通知 |
| **Google Pub/Sub** | フルマネージド、ack deadline制御、exactly-once delivery (Pull) | GCP前提 | GCP環境のevent流通 |
| **NATS JetStream** | 軽量、低遅延、stream + KV | ecosystem小 | IoT、edge、低遅延RPC |

**判定軸**: 順序保証要件 / throughput / retention期間 / 運用コスト / vendor lockの5軸。迷ったらKafka互換（Kafka / Redpanda / MSK）。

---

## 2. Topic / Partition設計

**原則**: partition = 順序単位 = 並列度上限。

| 観点 | 指針 |
|------|------|
| partition key | 同一entityのeventを同一partitionに（例: `user_id`, `order_id`） |
| partition数 | consumer最大並列数に合わせる。**増やすのは容易、減らすは不可**。初期は消費throughputの2-3倍 |
| hot partition回避 | key分布の偏り検査（`kafka-consumer-groups --describe`）、salt付与で均等化 |
| topic命名 | `{domain}.{entity}.{event}`（例: `order.v1.placed`、`user.v1.email_changed`） |
| retention | event sourcing → 長期（無期限or compact）、通知系 → 7日程度 |

**cross-partition順序は保証されない**。必要ならsingle partition（低throughput）or timestamp+mergeの自前実装。

---

## 3. Consumer GroupとDelivery Semantics

| Semantics | 実装 | 用途 | 注意 |
|-----------|------|------|------|
| **at-most-once** | auto commit前に処理 | metrics送信、ロス許容 | データ欠損 |
| **at-least-once**（推奨） | 処理完了後manual commit | 一般OLTP | **消費側でidempotent必須** |
| **exactly-once** | Kafka transactional producer + read_committed / SQS FIFO + dedup / Transactional Outbox | 金融、在庫 | 性能コスト大 |

**Consumer rebalance**: Kafkaは **cooperative sticky**（2.4+）推奨、旧eagerは全revokeでstop-the-world。`partition.assignment.strategy=org.apache.kafka.clients.consumer.CooperativeStickyAssignor`。

**1 partition = 最大1 consumer**。consumer数 > partition数 で余剰consumerはidle。

---

## 4. Idempotent Consumer（at-least-once受信側）

重複受信前提で設計。

```go
// dedup table で重複排除
INSERT INTO event_dedup (event_id, processed_at)
VALUES ($1, now())
ON CONFLICT (event_id) DO NOTHING RETURNING event_id;
// 挿入成功 → 未処理、失敗 → 重複スキップ
```

**設計要点**:
- event_idはproducer側でUUID付与、全経路で保持
- dedup tableはTTL/partitioningで肥大対策（例: 7日分のみ保持 + retention延長はidempotency keyで代替）
- 業務transactionとdedup insertを **同一DB tx** に（別DBだとtwo-phase問題）

---

## 5. Transactional Outbox（producer側exactly-onceの実用解）

DB更新とevent発行のatomicity確保。

| Step | 処理 |
|------|------|
| 1 | 業務更新 + `outbox` テーブルinsertを **同一tx** でcommit |
| 2 | 別プロセス（relay/poller or Debezium CDC）がoutboxを読み → brokerにpublish |
| 3 | publish成功でoutbox rowを削除or marked |

**利点**: 2PC不要、DBとbrokerの整合。**欠点**: relay遅延（数ms〜秒）、outboxテーブル管理。

CDC（Debezium等）でoutbox読取りするとrelay自前実装不要。

---

## 6. DLQ（Dead Letter Queue）

poison pillでconsumer全停止を防ぐ。

| 設定項目 | 推奨 |
|---------|------|
| max retry | 3〜5回 |
| backoff | exponential（1s → 4s → 16s） |
| DLQ到達条件 | retry超過or parse失敗 |
| DLQ監視 | 件数SLO、24h以上滞留でalert |
| 再投入フロー | 手動or自動（原因解決後scriptでmain topicへ） |

**DLQにmessageごと原因metadataを付与**（error message、stack trace、attempt count）。後で再投入や分析が可能に。

---

## 7. Schema Evolution

Avro / Protobuf / JSON Schema + **Schema Registry**（Confluent、Apicurio）で管理。

| 互換性モード | 意味 | 用途 |
|-------------|------|------|
| **BACKWARD**（既定） | 新schemaで旧data読める | consumer先行更新 |
| **FORWARD** | 旧schemaで新data読める | producer先行更新 |
| **FULL** | 双方向互換 | 最も厳格、推奨 |
| **NONE** | 任意変更 | 非互換変更時の一時解除 |

**破壊的変更**:
- 必須field追加 → FORWARD壊れる
- field削除 → BACKWARD壊れる
- 型変更 → FULL壊れる

→ major version bump + **dual write**（旧・新topic並走）、consumer移行後に旧停止。

---

## 8. CDC（Change Data Capture）

DB変更をevent化して他システムに伝播。

| ツール | 対象 | 仕組み |
|--------|------|--------|
| **Debezium** | MySQL binlog、PostgreSQL WAL、MongoDB oplog | Kafka Connect経由でbrokerへ |
| **AWS DMS** | 各種DB | CDCモードでS3/Kinesisへ |
| **native logical replication**（PG） | PostgreSQL | publication/subscription |

**snapshot + incremental**: 初回は全件snapshot、以降は差分（WAL / binlog）。

**Outbox vs CDC**: Outboxはapp層で明示的なevent設計、CDCはDB変更をそのまま流す。Outbox推奨（event契約が明確、内部カラム変更に強い）。

---

## 9. BackpressureとLag対策

consumerがproducerに追いつかない時の対処。

| 監視metric | 指針 |
|------------|------|
| consumer lag（`kafka-consumer-groups`） | 定常lagが増加 → 水平scale |
| `/sched/latencies`（Go） | consumer内部の処理待ち |
| max.poll.records | 1回poll取得数、下げるとper-batch処理軽減 |

**対策優先順**:
1. consumer instance増（partition数まで）
2. 処理並列化（goroutine pool、worker pool）
3. partition数増（要rebalance、downtime検討）
4. 処理軽量化（重い処理は別topic + 別consumerに分離）

---

## 10. アンチパターン

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| queueを長期store代わり | event sourcing or DB | brokerはretention有限が前提 |
| partition keyにtimestamp | entity ID | hot partition（最新に集中） |
| consumer内で重いDB書込をblock | worker pool経由or別topic | lag増大 |
| schema破壊的変更を無告知 | Schema Registry + 移行ドキュメント | consumer全停止リスク |
| eventに巨大payload | IDのみ + DB参照（claim checkパターン） | broker size制限、network cost |
| exactly-onceを自前実装 | Kafka transactional producer / Outbox | 隅のバグで整合崩壊 |
| DLQを監視せず放置 | 件数SLO + 再投入フロー | バグ無視 → データ欠損 |

---

## 11. 参考

- Confluent: Kafka公式ドキュメント、Schema Registry
- 「Designing Data-Intensive Applications」(Martin Kleppmann)
- 「Enterprise Integration Patterns」(Hohpe & Woolf)
- Debezium公式、AWS SQS/SNS公式
- 関連: `backend/distributed-transactions.md`（Saga/Outboxの整合）、`design/async-job-patterns.md`（task queue）、`backend/observability-design.md`（consumer lag監視）
