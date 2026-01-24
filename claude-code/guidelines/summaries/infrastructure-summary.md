# インフラガイドライン（サマリー版）

## 📚 詳細仕様一覧（infrastructure/）

| ファイル | 内容 |
|---------|------|
| `terraform.md` | モジュール化、State管理、コーディング規約 |
| `aws-ecs-fargate.md` | ECS/Fargate デプロイメント設計 |
| `aws-eks.md` | Kubernetes on AWS 設計 |
| `aws-lambda.md` | サーバーレス設計 |
| `aws-ec2.md` | EC2 インスタンス設計 |

---

## Terraform ベストプラクティス

| 項目 | 推奨 |
|------|------|
| **モジュール化** | 最初からモジュール構造（小規模でも） |
| **公式モジュール優先** | `terraform-aws-modules` 使用 |
| **バージョン固定** | Terraform & Provider バージョン固定 |

### 必須設定

| 項目 | 設定 |
|------|------|
| **State管理** | S3 + DynamoDB でリモートステート |
| **環境分離** | 環境ごとにステートファイル分離 |
| **暗号化** | State ファイル暗号化有効化 |

### ディレクトリ構成

```
terraform/
├── environments/     # 環境別設定（dev/staging/prod）
├── modules/          # 再利用可能なモジュール
└── shared/           # 共通リソース
```

---

## AWS デプロイメント比較

| サービス | 用途 | 特徴 |
|---------|------|------|
| **ECS Fargate** | コンテナ（サーバーレス） | 運用コスト最小、AWS統合 |
| **EKS** | Kubernetes | マルチクラウド、高度な制御 |
| **Lambda** | イベント駆動 | 自動スケール、従量課金 |
| **EC2** | 汎用 | 完全制御、既存アプリ移行 |

---

## セキュリティ基準

| 項目 | 要件 |
|------|------|
| **VPC** | プライベートサブネット必須 |
| **IAM** | 最小権限の原則 |
| **暗号化** | 転送時・保管時ともに有効化 |
| **ログ** | CloudWatch Logs 集約 |

---

## モニタリング

| 項目 | 推奨ツール |
|------|-----------|
| **メトリクス** | CloudWatch Metrics |
| **ログ** | CloudWatch Logs Insights |
| **トレース** | X-Ray |
| **アラート** | CloudWatch Alarms + SNS |

---

## コスト最適化

| 戦略 | 手法 |
|------|------|
| **リソース削減** | Auto Scaling, Spot Instance |
| **ストレージ** | S3 ライフサイクルポリシー |
| **リザーブ** | 長期稼働リソースはRI購入 |
| **モニタリング** | Cost Explorer で可視化 |
