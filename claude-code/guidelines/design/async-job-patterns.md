# 非同期ジョブ設計パターン

## キュー/メッセージング選択基準

| 要件 | SQS | SNS+SQS | Kafka |
|------|-----|---------|-------|
| 単一Consumer | **最適** | - | - |
| Fan-out（1:N配信） | - | **最適** | **最適** |
| 順序保証 | FIFO対応 | - | パーティション内保証 |
| 大量スループット | - | - | **最適** |
| リプレイ（再処理） | - | - | **最適** |
| シンプルさ | **最適** | 中 | 複雑 |

## Worker/Job 実装パターン

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

### publicfunctions パターン

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

| 項目 | 推奨 |
|------|------|
| DLQ設置 | 全キューに必須 |
| リトライ回数 | 2-3回（ジョブ特性に応じて調整） |
| DLQ受信時のアラート | 即時通知（メッセージ数 > 0） |
| 再処理手順 | DLQメッセージ確認→原因修正→メインキューに再投入 |

## 冪等性の確保

| パターン | 実装方法 |
|---------|---------|
| 一意キーによる重複排除 | メッセージIDやリクエストIDでDB制約 |
| 状態チェック | 処理前に現在の状態を確認し、処理済みならスキップ |
| トランザクション | DB操作とキュー操作の整合性を保つ |

---

- 関連: `backend/event-driven-architecture.md`（Kafka/streaming/exactly-once）, `backend/distributed-transactions.md`（Outbox/Saga）
