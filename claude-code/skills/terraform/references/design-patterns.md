# Terraform設計パターン詳細

## Critical（修正必須）

### 1. バージョン固定なし

```hcl
# Bad: バージョン未固定
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Good: バージョン固定
terraform {
  required_version = "~> 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### 2. ハードコードされたシークレット

```hcl
# Bad: シークレットをハードコード
resource "aws_db_instance" "main" {
  username = "admin"
  password = "hardcoded_password"
}

# Good: Secrets Managerから取得
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "db-password"
}

resource "aws_db_instance" "main" {
  username = "admin"
  password = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)["password"]
}
```

### 3. リモートステート未使用

```hcl
# Good: S3 + DynamoDBでリモートステート
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket"
    key            = "environments/dev/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### 4. 過度にpermissiveなIAMポリシー

```hcl
# Bad: 全権限付与
resource "aws_iam_role_policy" "bad" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
    }]
  })
}

# Good: 最小権限の原則
resource "aws_iam_role_policy" "good" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      Resource = "arn:aws:s3:::my-bucket/*"
    }]
  })
}
```

## Warning（要改善）

### 1. モジュール化されていない

```hcl
# Bad: すべてのリソースをmain.tfに記述

# Good: モジュール化
# modules/vpc/main.tf
resource "aws_vpc" "main" { ... }
resource "aws_subnet" "public" {
  for_each = var.public_subnets
  ...
}

# environments/dev/main.tf
module "vpc" {
  source = "../../modules/vpc"

  public_subnets = {
    "public-1" = { cidr = "10.0.1.0/24", az = "ap-northeast-1a" }
    "public-2" = { cidr = "10.0.2.0/24", az = "ap-northeast-1c" }
  }
}
```

### 2. タグ付けなし

```hcl
# Good: 共通タグをローカル変数で定義
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    Terraform   = "true"
    ManagedBy   = "platform-team"
  }
}

resource "aws_instance" "app" {
  ami           = "ami-xxxxx"
  instance_type = "t3.micro"
  tags          = merge(local.common_tags, { Name = "app-server" })
}
```

### 3. 公式モジュール未使用

```hcl
# Good: 公式モジュールを活用
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-northeast-1a", "ap-northeast-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = false

  tags = local.common_tags
}
```
