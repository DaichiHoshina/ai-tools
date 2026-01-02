# Terraform ガイドライン

**目的**: Infrastructure as Code のベストプラクティスと一貫性のある設定管理

---

## 基本原則

| 原則 | 内容 |
|------|------|
| モジュール化 | 最初からモジュール化（小規模でもモジュール構造で開始） |
| 公式モジュール | `terraform-aws-modules` などの検証済みモジュールを優先 |
| バージョン固定 | Terraform と Provider のバージョンを固定 |

---

## ディレクトリ構成

| ディレクトリ | 用途 |
|-------------|------|
| `environments/` | 環境別設定（dev, staging, production） |
| `modules/` | 再利用可能なモジュール |
| `shared/` | 共通リソース |

---

## 必須設定

### Provider

| 項目 | 設定 |
|------|------|
| `required_version` | Terraform バージョン固定 |
| `required_providers` | プロバイダーバージョン固定 |
| リージョン | 変数化 |

### State 管理

| 項目 | 設定 |
|------|------|
| バックエンド | S3 + DynamoDB でリモートステート |
| 環境分離 | 環境ごとにステートファイル分離 |
| 暗号化 | 暗号化有効化 |

---

## コーディング規約

### 命名規則

| 項目 | 規則 |
|------|------|
| リソース名 | `snake_case`（例: `web_server`） |
| 環境識別子 | プレフィックス（例: `dev-`, `prod-`） |

### 変数定義

| 項目 | ルール |
|------|--------|
| `description` | 必須 |
| `type` | 明示的に指定 |
| センシティブ情報 | `sensitive = true` |

### タグ付け（必須）

| タグ | 用途 |
|------|------|
| `Environment` | 環境名 |
| `Project` | プロジェクト名 |
| `Terraform` | `"true"` |
| `ManagedBy` | 管理チーム |

---

## セキュリティ

| ❌ 禁止事項 | ✅ 推奨事項 |
|------------|------------|
| ハードコードされたシークレット | Secrets Manager / SSM Parameter Store 連携 |
| 過度に permissive な IAM ポリシー（`*` 乱用） | KMS による暗号化 |
| パブリックアクセス可能な S3 | 最小権限の原則 |
| 暗号化なしのストレージ | VPC エンドポイント活用 |

---

## terraform-aws-modules 主要モジュール

| モジュール | 用途 |
|-----------|------|
| `terraform-aws-modules/vpc/aws` | ネットワーク基盤 |
| `terraform-aws-modules/ec2-instance/aws` | インスタンス管理 |
| `terraform-aws-modules/ecs/aws` | コンテナオーケストレーション |
| `terraform-aws-modules/eks/aws` | Kubernetes クラスター |
| `terraform-aws-modules/lambda/aws` | サーバーレス関数 |

**バージョン固定**: モジュールバージョンはメジャーを固定（`version = "~> 6.0"`）

---

## ワークフロー

### 変更適用フロー

| ステップ | コマンド |
|---------|---------|
| 1. フォーマット | `terraform fmt -recursive` |
| 2. 構文検証 | `terraform validate` |
| 3. 実行計画 | `terraform plan -out=tfplan` |
| 4. 適用 | レビュー後 `terraform apply tfplan` |

### CI/CD 統合

| タイミング | 実行内容 |
|-----------|---------|
| PR | `terraform plan` 自動実行 |
| main マージ | `terraform apply` |
| 推奨ツール | Atlantis / Terraform Cloud |

---

## リファレンス

- Terraform AWS Provider: registry.terraform.io/providers/hashicorp/aws/latest/docs
- Best Practices: terraform-best-practices.com
- terraform-aws-modules: github.com/terraform-aws-modules
