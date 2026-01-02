# AWS ECS / Fargate ガイドライン

**目的**: コンテナワークロードの効率的な運用とセキュリティ確保

---

## terraform-aws-modules/ecs

| 項目 | 設定 |
|------|------|
| `cluster_name` | 環境プレフィックス付き |
| Execute Command | CloudWatch Logs 連携 |
| キャパシティプロバイダー | FARGATE + FARGATE_SPOT |

---

## サービス定義

### 主要設定

| 項目 | 設定 |
|------|------|
| `cpu` / `memory` | タスク全体のリソース |
| `desired_count` | 希望タスク数 |
| `container_definitions` | コンテナ設定 |

### コンテナ設定必須項目

| 項目 | 設定 |
|------|------|
| `essential` | `true`（主要コンテナ） |
| `portMappings` | ポート設定 |
| `healthCheck` | ヘルスチェック設定 |
| `logConfiguration` | ログ設定（awslogs） |
| `readonlyRootFilesystem` | `true`（セキュリティ強化） |

---

## キャパシティプロバイダー戦略

| タイプ | 価格 | 用途 |
|--------|------|------|
| FARGATE | 標準価格、高可用性 | 本番クリティカル |
| FARGATE_SPOT | 最大70%割引、中断可能 | バッチ、開発 |

### 推奨設定

| 環境 | 設定 |
|------|------|
| 本番 | FARGATE base=50%, FARGATE_SPOT weight=50% |
| 開発 | FARGATE_SPOT 100% |
| バッチ | FARGATE_SPOT 優先 |

---

## Service Connect

| 項目 | 内容 |
|------|------|
| namespace | サービスメッシュ構成 |
| DNS 名 | サービス間通信（`web-app:80`） |
| Cloud Map | 自動連携 |

---

## セキュリティ

| ❌ 禁止事項 | ✅ 必須設定 |
|------------|------------|
| 環境変数でシークレット直接設定 | `readonlyRootFilesystem = true` |
| パブリックサブネットでのタスク実行 | Secrets Manager からシークレット取得 |
| 過度に広い IAM ポリシー | タスクロールの最小権限 |
| - | プライベートサブネット配置 |

---

## ロギング

### 標準設定

| 項目 | 設定 |
|------|------|
| `logDriver` | `"awslogs"` |
| CloudWatch Logs グループ | `/ecs/${service-name}` |

### FireLens 統合

Fluent Bit サイドカーで高度なログルーティング → Firehose / Elasticsearch 連携

---

## Auto Scaling

### Target Tracking

| メトリクス | 設定 |
|-----------|------|
| `ECSServiceAverageCPUUtilization` | CPU 使用率 |
| `ECSServiceAverageMemoryUtilization` | メモリ使用率 |
| `target_value` | 70%推奨 |

### クールダウン

| 項目 | 設定 |
|------|------|
| `scale_out_cooldown` | 60秒 |
| `scale_in_cooldown` | 300秒 |

---

## デプロイ戦略

### ローリングアップデート

| 項目 | 設定 |
|------|------|
| `maximum_percent` | 200（新タスク先行起動） |
| `minimum_healthy_percent` | 100（既存タスク維持） |

### Blue/Green

- CodeDeploy 連携
- ALB リスナールール切り替え
- 自動ロールバック

---

## EBS ボリューム (Fargate)

| 項目 | 設定 |
|------|------|
| 用途 | ステートフルワークロード向け |
| `encrypted` | `true`（KMS 暗号化） |
| `volume_type` | `gp3` 推奨 |

---

## 監視

### 必須メトリクス

- CPU / メモリ使用率
- タスク数（Running, Pending, Stopped）
- サービスイベント
- ヘルスチェック失敗

### CloudWatch Alarms

- タスク停止アラート
- CPU/メモリ閾値超過
- ターゲットヘルス異常
