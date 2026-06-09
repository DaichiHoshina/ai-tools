# 非同期ジョブ設計パターン

メッセージング (SQS / SNS / Kafka) の選定基準と非同期ジョブ設計パターン。バックエンドでfan-out / 順序保証 / 高スループットを設計する時に参照。

## キュー/メッセージング選択基準

| 要件 | SQS | SNS+SQS | Kafka |
|------|-----|---------|-------|
| 単一Consumer | **最適** | - | - |
| Fan-out（1:N配信） | - | **最適** | **最適** |
| 順序保証 | FIFO対応 | - | パーティション内保証 |
| 大量スループット | - | - | **最適** |
| リプレイ（再処理） | - | - | **最適** |
| シンプルさ | **最適** | 中 | 複雑 |

## Worker/Job実装パターン

### 必須ステップ（新規Job追加時）

1. **Task実装** -- `task/{domain}/task.go` に `Perform` メソッド
2. **Request定義** -- `task/{domain}/request.go` にメッセージ構造体・Job定数
3. **Job登録** -- 初期化関数にJob登録を追加
4. **Job発行** -- ビジネスロジックからPublish呼び出し

### ディレクトリ構成例

```text
cmd/worker/
├── main.go           # Job登録（initJobs）
└── task/
    ├── order/
    │   ├── task.go     # Perform(ctx, msg) error
    │   └── request.go  # Message構造体、Job定数
    └── notification/
        ├── task.go
        └── request.go
```

## Bounded Context間の非同期通信

### publicfunctionsパターン

Worker Taskが別のBounded Contextの内部ロジックを呼ぶ必要がある場合、直接importせず公開インターフェースを経由する。

```text
bounded_context/
└── order/
    └── interface/
        └── publicfunctions/
            ├── order_functions.go       # インターフェース定義
            └── order_functions_impl.go  # 内部importを含む実装
```

| ルール | 詳細 |
|--------|------|
| Worker Taskはインターフェースパッケージのみimport | 内部パッケージへの直接依存禁止 |
| 公開関数はBC単位で集約 | 散在させない |
| 実装ファイルのみ内部import許可 | インターフェースファイルは外部依存なし |

## DLQ（Dead Letter Queue）設計

poison pillでconsumer全停止を防ぐ。

| 設定項目 | 推奨 |
|---------|------|
| DLQ設置 | 全キューに必須 |
| max retry | 3〜5回（ジョブ特性に応じて調整） |
| backoff | exponential（1s → 4s → 16s） |
| DLQ到達条件 | retry超過またはparse失敗 |
| DLQ受信時のアラート | 件数SLO、24h以上滞留でalert |
| 再処理手順 | DLQメッセージ確認→原因修正→メインキューに再投入 |

**DLQにmessageごと原因metadataを付与**（error message、stack trace、attempt count）。後で再投入や分析が可能に。

## 冪等性の確保

at-least-once配信前提で「重複実行されても結果同じ」設計が必須。

| パターン | 実装方法 |
|---------|---------|
| **Idempotency Key** | clientがUUID生成、server側でfingerprint保存・重複検出 |
| **Natural key** | 業務キー（注文番号等）をunique制約 |
| 状態チェック | 処理前に現在の状態を確認し、処理済みならスキップ |
| トランザクション | DB操作とキュー操作の整合性を保つ |

```http
POST /payments
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
```

```go
// dedup tableで重複排除（event consumer側）
INSERT INTO event_dedup (event_id, processed_at)
VALUES ($1, now())
ON CONFLICT (event_id) DO NOTHING RETURNING event_id;
// 挿入成功 → 未処理、失敗 → 重複スキップ
```

**設計要点**:
- event_idはproducer側でUUID付与、全経路で保持
- dedup tableはTTL/partitioningで肥大対策（例: 7日分のみ保持）
- TTL: 24h程度でfingerprint削除（IETF draft準拠）
- 業務transactionとdedup insertを**同一DB tx**に（別DBだとtwo-phase問題）

---

- 関連: `backend/event-driven-architecture.md`（Kafka/streaming/exactly-once）, `backend/distributed-transactions.md`（Outbox/Saga）
