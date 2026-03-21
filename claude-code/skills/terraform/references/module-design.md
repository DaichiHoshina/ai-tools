# Terraformモジュール設計

## ディレクトリ構成

```text
terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars
│   ├── staging/
│   └── production/
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── eks/
│   └── rds/
└── shared/
    └── iam/
```

## モジュールベストプラクティス

| 項目 | 推奨事項 |
|-----|---------|
| 命名 | リソースタイプを反映（vpc, eks, rds） |
| 変数 | description必須、type明示 |
| 出力 | 他モジュールで使う値をoutput |
| バージョン | メジャーバージョン固定 (version = "~> 5.0") |
