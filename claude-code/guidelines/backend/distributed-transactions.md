# 分散トランザクション ガイドライン

複数サービス/DBにまたがる整合性保証、デッドロック対処、楽観/悲観ロック判定が必要な時に参照。

## Tier 区分

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
| **Read Committed**（既定） | dirty read | 一般 OLTP | 低 |
| **Repeatable Read** | + non-repeatable read, phantom (PG では) | 集計、レポート | 中、serialization failure |
| **Serializable**（SSI） | 全異常 | 金融、在庫 | 高、retry 必須 |

**判定**:
- 単純 CRUD → Read Committed
- 同一 tx 内で複数回 read → Repeatable Read
- 真の整合性必要（残高/在庫） → Serializable + retry

---

## 2. 楽観 vs 悲観ロック

| 種別 | 仕組み | 適用 | 例 |
|------|--------|------|-----|
| **楽観ロック** | version列を WHERE で検証、UPDATE失敗→retry | 競合稀 | 商品編集、設定 |
| **悲観ロック**（SELECT FOR UPDATE） | row lock 取得 | 競合多、長tx禁 | 在庫減算、座席予約 |

**楽観ロック実装**:
```sql
UPDATE orders SET status='paid', version=version+1
WHERE id=? AND version=?;  -- 0行更新 → 競合、retry
```

**悲観ロック注意**: 長保持禁止、TX 短く保つ、デッドロック対処必要。

---

## 3. デッドロック対処

| 戦略 | 内容 |
|------|------|
| **lock 順序統一** | 全 tx で同じ順序（例: id 昇順）で lock 取得 |
| **timeout 設定** | `SET lock_timeout = '3s'` で諦める |
| **retry with backoff** | deadlock detected 時に exponential backoff retry |
| **粒度小さく** | row lock < table lock |

```go
for i := 0; i < 3; i++ {
    err := tx.Run()
    if isDeadlock(err) { time.Sleep(jitter(i)); continue }
    return err
}
```

---

## 4. Saga パターン

長期 tx を「補償可能な小 tx の連鎖」に分解。

| 種別 | 制御 | メリット | デメリット |
|------|------|---------|----------|
| **Orchestration** | 中央 orchestrator が各 step 指示 | 可視性高、デバッグ容易 | SPOF、結合 |
| **Choreography** | event 駆動、各 service 自律 | 疎結合、scale | 全体把握困難 |

**実装ルール**:
- 各 step に対応する **補償アクション**（compensating action）必須
- 失敗時は **逆順** に補償実行
- 中間状態を DB に永続化（クラッシュ復旧）
- 補償も冪等であること

**例（注文）**:
```text
予約座席 → 決済 → 配送手配
失敗時補償: 配送キャンセル → 返金 → 座席解放
```

---

## 5. Transactional Outbox パターン

DB tx と message publish の atomicity 保証。

```text
TX 内:
  INSERT INTO orders ...
  INSERT INTO outbox (event, payload) ...
COMMIT;

別 worker:
  outbox から poll → message broker publish → outbox 削除
```

| 利点 | 欠点 |
|------|------|
| DB tx で完全 atomic | DB 負荷増 |
| メッセージ消失なし | 順序保証は別途必要 |
| event sourcing 入口 | poll 実装必要 |

**代替**: CDC（Change Data Capture, Debezium 等）で WAL から直接 publish。

---

## 6. Idempotency

分散環境で「重複実行されても結果同じ」必須。

| 実装 | 仕組み |
|------|--------|
| **Idempotency Key** | client が UUID 生成、server 側で fingerprint 保存・重複検出 |
| **Natural key** | 業務キー（注文番号等）を unique 制約 |
| **Version check** | 更新前 state hash を引数化 |

```http
POST /payments
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
```

**TTL**: 24h 程度で fingerprint 削除（IETF draft 準拠）。

---

## 7. 配信保証

| 種別 | 仕組み | 用途 |
|------|--------|------|
| **At-most-once** | fire-and-forget | metrics（消失許容） |
| **At-least-once**（推奨既定） | ack 後 commit、失敗 → 再送 | + 受信側 idempotency 必須 |
| **Exactly-once**（実質的） | Kafka tx + idempotent producer | 厳密整合（高コスト） |

**現実解**: At-least-once + 冪等処理 = "Effectively-once"。

---

## 8. 2PC（Two-Phase Commit）

- リソース全体の prepare → commit 2段
- coordinator 障害で blocking 発生
- 異 DB 跨ぎは現代では Saga 推奨、2PC は同一 DBMS 内の限定用途

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

- PG Transaction Isolation 公式
- Saga: ByteByteGo
- Outbox: AWS Prescriptive Guidance
- Idempotency Key RFC: IETF draft
- 関連: `design/async-job-patterns.md`（DLQ）, `backend/observability-design.md`（trace相関）
