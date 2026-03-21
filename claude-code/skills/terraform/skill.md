---
name: terraform
description: Terraform IaC設計 - モジュール設計、状態管理、セキュリティベストプラクティス。terraform plan/apply、IaCコードレビュー、モジュール設計、状態管理の見直し時に使用。
requires-guidelines:
  - terraform
  - common
---

# terraform - Terraform IaC設計

## 使用タイミング

- インフラ構築・変更時
- IaCコードレビュー時
- モジュール設計時
- 状態管理の見直し時

## チェック項目サマリー

### Critical（修正必須）

| # | チェック | 概要 |
|---|---------|------|
| 1 | バージョン固定 | required_version + required_providers にバージョン指定 |
| 2 | シークレット管理 | ハードコード禁止、Secrets Manager / SSM連携 |
| 3 | リモートステート | S3 + DynamoDB、暗号化・バージョニング有効 |
| 4 | IAM最小権限 | Action: "*" 禁止、必要な操作のみ許可 |

### Warning（要改善）

| # | チェック | 概要 |
|---|---------|------|
| 1 | モジュール化 | main.tf肥大化 → modules/ に分離 |
| 2 | タグ付け | 共通タグをlocalsで定義、全リソースに適用 |
| 3 | 公式モジュール | terraform-aws-modules活用 |

コード例が必要な場合: [references/design-patterns.md](references/design-patterns.md)
モジュール設計詳細: [references/module-design.md](references/module-design.md)

## チェックリスト

| カテゴリ | 項目 |
|---------|------|
| セキュリティ | シークレットハードコード禁止、IAM最小権限、S3暗号化、パブリックアクセス禁止、VPCエンドポイント |
| 状態管理 | S3+DynamoDBリモートステート、環境ごとに分離、暗号化・バージョニング有効 |
| コード品質 | terraform fmt/validate、変数にdescription+type、必須タグ設定 |
| ワークフロー | terraform plan事前確認、PR計画結果共有、apply前レビュー |

## 出力形式

```text
Critical: `ファイル:行` - セキュリティリスク/バージョン未固定 - 修正案
Warning: `ファイル:行` - 設計改善推奨 - 改善案
Summary: Critical X件 / Warning Y件
```

## Troubleshooting

### エラー: State lock取得失敗
原因: 前回のterraform apply/planが異常終了しロックが残存
対処: `terraform force-unlock <LOCK_ID>` で解放（他作業者がいないことを確認）

### エラー: Provider version conflict
原因: .terraform.lock.hcl と required_providers のバージョン不一致
対処: `terraform init -upgrade` でプロバイダ更新

## 関連

- ガイドライン: `~/.claude/guidelines/infrastructure/terraform.md`
- 最新ドキュメント確認: context7を活用
