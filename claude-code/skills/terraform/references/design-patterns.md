# Terraform Design Patterns

## Critical (Must fix)

### 1. No version pinning

```hcl
# Bad: unpinned
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Good: pinned
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

### 2. Hardcoded secrets

```hcl
# Bad: hardcoded
resource "aws_db_instance" "main" {
  username = "admin"
  password = "hardcoded_password"
}

# Good: from Secrets Manager
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "db-password"
}

resource "aws_db_instance" "main" {
  username = "admin"
  password = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)["password"]
}
```

### 3. No remote state

```hcl
# Good: S3 + DynamoDB remote state
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

### 4. Overly permissive IAM

```hcl
# Bad: full access
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

# Good: least privilege
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

## Warning (Improve)

### 1. Not modularized

```hcl
# Bad: all resources in main.tf

# Good: modularized
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

### 2. No tagging

```hcl
# Good: common tags as locals
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

### 3. Not using official modules

```hcl
# Good: leverage official modules
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
