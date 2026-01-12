# AWS Lambda ガイドライン

**目的**: サーバーレス関数の効率的な開発とセキュアなデプロイ

---

## terraform-aws-modules/lambda

| 項目 | 設定 |
|------|------|
| `function_name` | 環境プレフィックス付き（`${var.environment}-api-handler`） |
| `runtime` | 最新LTS推奨（`nodejs20.x`, `python3.12`） |
| `memory_size` | ワークロードに応じて設定 |
| `timeout` | 処理時間に応じて設定（デフォルト30秒） |

### ランタイム別設定

| ランタイム | 設定 |
|-----------|------|
| Node.js | `runtime = "nodejs20.x"`, `handler = "index.handler"` |
| Python | `runtime = "python3.12"`, `handler = "main.lambda_handler"` |
| Go | `runtime = "provided.al2023"`, `handler = "bootstrap"` |

---

## VPC 内 Lambda

| 項目 | 内容 |
|------|------|
| インターネットアクセス | NAT Gateway 経由 |
| VPC エンドポイント | S3, DynamoDB, Secrets Manager 推奨 |
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
| 有効化 | `lambda_at_edge = true` で us-east-1 に自動デプロイ |
| タイムアウト制限 | Viewer 5秒、Origin 30秒 |
| レスポンスサイズ | 制限あり |

---

## セキュリティ

| ❌ 禁止事項 | ✅ 推奨事項 |
|------------|------------|
| `*` リソースの IAM ポリシー | Secrets Manager / SSM Parameter Store |
| 環境変数でのシークレット直接設定 | X-Ray トレーシング有効化 |
| ルートユーザーでの実行 | 最小権限 IAM ロール |
| - | VPC 配置（DB アクセス時） |

---

## パフォーマンス

### コールドスタート対策

| 方式 | 用途 |
|------|------|
| Provisioned Concurrency | クリティカル API 向け |
| SnapStart | Java ランタイム向け |
| 軽量ランタイム | Node.js, Python 推奨 |

### メモリ設定目安

| 処理内容 | メモリサイズ |
|---------|-------------|
| 軽量 API | 128-256 MB |
| 一般処理 | 256-512 MB |
| 重い処理 | 1024-3008 MB |
| 機械学習 | 3008-10240 MB |

---

## ログとモニタリング

| 項目 | 設定 |
|------|------|
| ログ保持期間 | `cloudwatch_logs_retention_in_days = 30` |
| トレーシング | `tracing_mode = "Active"`（X-Ray） |

### Powertools 活用（Python推奨）

Logger, Tracer, Metrics でログ・トレース・メトリクス統合（デコレーターで簡単実装）

---

## デプロイ

### CI/CD パイプライン

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
| メモリサイズ | AWS Lambda Power Tuning 活用 |
| 依存関係 | 不要な依存関係の削除 |
| アーキテクチャ | ARM64（Graviton2）検討 |
