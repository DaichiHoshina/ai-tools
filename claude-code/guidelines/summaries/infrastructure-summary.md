# インフラガイドライン（サマリー版）

## 詳細仕様（infrastructure/）

| ファイル | 内容 |
|---------|------|
| `terraform.md` | モジュール化、State管理、コーディング規約 |
| `aws-ecs-fargate.md` | ECS/Fargate デプロイメント設計 |
| `aws-eks.md` | Kubernetes on AWS 設計 |
| `aws-lambda.md` | サーバーレス設計 |
| `aws-ec2.md` | EC2 インスタンス設計 |

## Terraform

| 項目 | 推奨 |
|------|------|
| モジュール化 | 最初からモジュール構造 |
| 公式モジュール | `terraform-aws-modules` 優先 |
| バージョン | Terraform & Provider 固定 |
| State管理 | S3 + DynamoDB リモートステート |
| 環境分離 | 環境ごとにステートファイル分離 |

## AWS デプロイメント比較

| サービス | 用途 | 特徴 |
|---------|------|------|
| **ECS Fargate** | コンテナ（サーバーレス） | 運用コスト最小 |
| **EKS** | Kubernetes | マルチクラウド、高度な制御 |
| **Lambda** | イベント駆動 | 自動スケール、従量課金 |
| **EC2** | 汎用 | 完全制御 |

## セキュリティ: VPCプライベートサブネット必須、IAM最小権限、転送時・保管時暗号化
