# AWS Lambdaガイドライン

**目的**: サーバーレス関数の効率的な開発とセキュアなデプロイ

---

## terraform-aws-modules/lambda

| 項目 | 設定 |
|------|------|
| `function_name` | 環境プレフィックス付き（`${var.environment}-api-handler`） |
| `runtime` | 最新LTS推奨（`nodejs24.x`, `python3.14`） |
| `memory_size` | ワークロードに応じて設定 |
| `timeout` | 処理時間に応じて設定（デフォルト30秒） |

### ランタイム別設定

| ランタイム | 設定 |
|-----------|------|
| Node.js | `runtime = "nodejs24.x"`, `handler = "index.handler"` |
| Python | `runtime = "python3.14"`, `handler = "main.lambda_handler"` |
| Go | `runtime = "provided.al2023"`, `handler = "bootstrap"` |

---

## VPC内Lambda

| 項目 | 内容 |
|------|------|
| インターネットアクセス | NAT Gateway経由 |
| VPCエンドポイント | S3, DynamoDB, Secrets Manager推奨 |
| 注意点 | コールドスタートが長くなる可能性 |

---

## トリガー設定

| トリガー | 設定 |
|---------|------|
| API Gateway | `service = "apigateway"` |
| EventBridge | `principal = "events.amazonaws.com"` |
| S3 | `service = "s3"` |

---

## Lambda@Edge

| 項目 | 設定 |
|------|------|
| 有効化 | `lambda_at_edge = true` でus-east-1に自動デプロイ |
| タイムアウト制限 | Viewer 5秒、Origin 30秒 |
| レスポンスサイズ | 制限あり |

---

## セキュリティ

| ❌ 禁止事項 | ✅ 推奨事項 |
|------------|------------|
| `*` リソースのIAMポリシー | Secrets Manager / SSM Parameter Store |
| 環境変数でのシークレット直接設定 | X-Rayトレーシング有効化 |
| ルートユーザーでの実行 | 最小権限IAMロール |
| - | VPC配置（DBアクセス時） |

---

## パフォーマンス

### コールドスタート対策

| 方式 | 用途 |
|------|------|
| Provisioned Concurrency | クリティカルAPI向け |
| SnapStart | Javaランタイム向け |
| 軽量ランタイム | Node.js, Python推奨 |

### メモリ設定目安

| 処理内容 | メモリサイズ |
|---------|-------------|
| 軽量API | 128-256 MB |
| 一般処理 | 256-512 MB |
| 重い処理 | 1024-3008 MB |
| 機械学習 | 3008-10240 MB |

---

## ログとモニタリング

| 項目 | 設定 |
|------|------|
| ログ保持期間 | `cloudwatch_logs_retention_in_days = 30` |
| トレーシング | `tracing_mode = "Active"`（X-Ray） |

### Powertools活用（Python推奨）

Logger, Tracer, Metricsでログ・トレース・メトリクス統合（デコレーターで簡単実装）

---

## デプロイ

### CI/CDパイプライン

| ステップ | 内容 |
|---------|------|
| 1. テスト | テスト実行 |
| 2. Plan | `terraform plan` |
| 3. レビュー | レビュー |
| 4. Apply | `terraform apply` |
| 5. スモークテスト | スモークテスト |

### バージョニング

| 項目 | 設定 |
|------|------|
| バージョン発行 | `publish = true` |
| エイリアス | `live` で本番参照 |

---

## エラーハンドリング

| 項目 | 設定 |
|------|------|
| DLQ | `dead_letter_target_arn` で失敗メッセージ保存 |
| リトライ | `maximum_retry_attempts = 2` |

---

## コスト最適化

| 項目 | 内容 |
|------|------|
| メモリサイズ | AWS Lambda Power Tuning活用 |
| 依存関係 | 不要な依存関係の削除 |
| アーキテクチャ | ARM64（Graviton2）検討 |
