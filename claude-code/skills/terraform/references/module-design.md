# Terraform Module Design

## Directory Structure

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

## Module Best Practices

| Item | Recommendation |
|------|-----------------|
| Naming | Reflect resource type (vpc, eks, rds) |
| Variables | Require description, explicit type |
| Outputs | Output values needed by other modules |
| Versioning | Pin major version (version = "~> 5.0") |
