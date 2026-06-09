# 分散トランザクション ガイドライン

複数サービス/DBにまたがる整合性保証、デッドロック対処、楽観/悲観ロック判定が必要な時に参照。

## Tier区分

| Tier | 内容 |
|------|------|
| Tier 1（必須） | 分離レベル選択、楽観ロック、idempotency |
| Tier 2（規模別） | Saga（orchestration/choreography）、Outbox |
| Tier 3（深掘り） | 2PC、Event Sourcing、CRDT |

---

## 1. 分離レベル使い分け（PostgreSQL想定）

| レベル | 防げる現象 | 推奨用途 | コスト |
|--------|----------|---------|--------|
| **Read Uncommitted** | （PG実質Read Committed） | - | - |
| **Read Committed**（既定） | dirty read | 一般OLTP | 低 |
| **Repeatable Read** | + non-repeatable read, phantom (PGでは) | 集計、レポート | 中、serialization failure |
| **Serializable**（SSI） | 全異常 | 金融、在庫 | 高、retry必須 |

**判定**:
- 単純CRUD → Read Committed
- 同一tx内で複数回read → Repeatable Read
- 真の整合性必要（残高/在庫） → Serializable + retry

---

## 2. 楽観vs悲観ロック

| 種別 | 仕組み | 適用 | 例 |
|------|--------|------|-----|
| **楽観ロック** | version列をWHEREで検証、UPDATE失敗→retry | 競合稀 | 商品編集、設定 |
| **悲観ロック**（SELECT FOR UPDATE） | row lock取得 | 競合多、長tx禁 | 在庫減算、座席予約 |

**楽観ロック実装**:
```sql
UPDATE orders SET status='paid', version=version+1
WHERE id=? AND version=?;  -- 0行更新 → 競合、retry
```

**悲観ロック注意**: 長保持禁止、TX短く保つ、デッドロック対処必要。

---

## 3. デッドロック対処

| 戦略 | 内容 |
|------|------|
| **lock順序統一** | 全txで同じ順序（例: id昇順）でlock取得 |
| **timeout設定** | `SET lock_timeout = '3s'` で諦める |
| **retry with backoff** | deadlock detected時にexponential backoff retry |
| **粒度小さく** | row lock < table lock |

```go
for i := 0; i < 3; i++ {
    err := tx.Run()
    if isDeadlock(err) { time.Sleep(jitter(i)); continue }
    return err
}
```

---

## 4. Sagaパターン

長期txを「補償可能な小txの連鎖」に分解。

| 種別 | 制御 | メリット | デメリット |
|------|------|---------|----------|
| **Orchestration** | 中央orchestratorが各step指示 | 可視性高、デバッグ容易 | SPOF、結合 |
| **Choreography** | event駆動、各service自律 | 疎結合、scale | 全体把握困難 |

**実装ルール**:
- 各stepに対応する **補償アクション**（compensating action）必須
- 失敗時は **逆順** に補償実行
- 中間状態をDBに永続化（クラッシュ復旧）
- 補償も冪等であること

**例（注文）**:
```text
予約座席 → 決済 → 配送手配
失敗時補償: 配送キャンセル → 返金 → 座席解放
```

---

## 5. Transactional Outboxパターン

DB txとmessage publishのatomicity保証。詳細は [event-driven-architecture.md#5-transactional-outboxproducer側exactly-onceの実用解](./event-driven-architecture.md) 参照。

---

## 6. Idempotency

冪等性の実装パターン詳細は [design/async-job-patterns.md#冪等性の確保](../design/async-job-patterns.md) 参照。

---

## 7. 配信保証

| 種別 | 仕組み | 用途 |
|------|--------|------|
| **At-most-once** | fire-and-forget | metrics（消失許容） |
| **At-least-once**（推奨既定） | ack後commit、失敗 → 再送 | + 受信側idempotency必須 |
| **Exactly-once**（実質的） | Kafka tx + idempotent producer | 厳密整合（高コスト） |

**現実解**: At-least-once + 冪等処理 = "Effectively-once"。

---

## 8. 2PC（Two-Phase Commit）

- リソース全体のprepare → commit 2段
- coordinator障害でblocking発生
- 異DB跨ぎは現代ではSaga推奨、2PCは同一DBMS内の限定用途

---

## 9. 判定フロー

```text
分散整合性必要？
├─ いいえ → 単一 DB tx + 適切な分離レベル
└─ はい
   ├─ 可逆操作（補償可）→ Saga
   ├─ event ordering 重要 → Outbox + 順序保証 broker
   └─ 強整合必須（同 DBMS） → 2PC（最終手段）
```

---

## 10. 参考

- PG Transaction Isolation公式
- Saga: ByteByteGo
- Outbox: AWS Prescriptive Guidance
- Idempotency Key RFC: IETF draft
- 関連: `design/async-job-patterns.md`（DLQ）, `backend/observability-design.md`（trace相関）, `backend/event-driven-architecture.md`（Outbox/Kafka実装）
