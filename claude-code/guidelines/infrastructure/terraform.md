# Terraform Guidelines

**Purpose**: Infrastructure as Code best practices and consistent configuration management

---

## Core Principles

| Principle | Detail |
|-----------|--------|
| Modularize | Start modular from the beginning (even small projects use module structure) |
| Official modules | Prefer validated modules such as `terraform-aws-modules` |
| Pin versions | Pin Terraform and Provider versions |

---

## Directory Structure

| Directory | Purpose |
|-----------|---------|
| `environments/` | Per-environment config (dev, staging, production) |
| `modules/` | Reusable modules |
| `shared/` | Common resources |

---

## Required Configuration

### Provider

| Item | Setting |
|------|---------|
| `required_version` | Pin Terraform version |
| `required_providers` | Pin provider versions |
| Region | Parameterize with variable |

### State Management

| Item | Setting |
|------|---------|
| Backend | Remote state with S3 + DynamoDB |
| Environment isolation | Separate state files per environment |
| Encryption | Enable encryption |

---

## Coding Conventions

### Naming

| Item | Rule |
|------|------|
| Resource names | `snake_case` (e.g. `web_server`) |
| Environment identifier | Prefix (e.g. `dev-`, `prod-`) |

### Variable Definition

| Item | Rule |
|------|------|
| `description` | Required |
| `type` | Explicitly specified |
| Sensitive info | `sensitive = true` |

### Tagging (Required)

| Tag | Purpose |
|-----|---------|
| `Environment` | Environment name |
| `Project` | Project name |
| `Terraform` | `"true"` |
| `ManagedBy` | Managing team |

---

## Security

| Forbidden | Recommended |
|-----------|-------------|
| Hardcoded secrets | Integrate with Secrets Manager / SSM Parameter Store |
| Overly permissive IAM policies (`*` overuse) | KMS encryption |
| Publicly accessible S3 | Principle of least privilege |
| Unencrypted storage | Use VPC endpoints |

---

## terraform-aws-modules Key Modules

| Module | Purpose |
|--------|---------|
| `terraform-aws-modules/vpc/aws` | Network foundation |
| `terraform-aws-modules/ec2-instance/aws` | Instance management |
| `terraform-aws-modules/ecs/aws` | Container orchestration |
| `terraform-aws-modules/eks/aws` | Kubernetes cluster |
| `terraform-aws-modules/lambda/aws` | Serverless functions |

**Pin versions**: Fix major version for module versions (`version = "~> 6.0"`)

---

## Workflow

### Change Application Flow

| Step | Command |
|------|---------|
| 1. Format | `terraform fmt -recursive` |
| 2. Validate | `terraform validate` |
| 3. Plan | `terraform plan -out=tfplan` |
| 4. Apply | `terraform apply tfplan` after review |

### CI/CD Integration

| Timing | Action |
|--------|--------|
| PR | Auto-run `terraform plan` |
| main merge | `terraform apply` |
| Recommended tools | Atlantis / Terraform Cloud |

---

## References

- Terraform AWS Provider: registry.terraform.io/providers/hashicorp/aws/latest/docs
- Best Practices: terraform-best-practices.com
- terraform-aws-modules: github.com/terraform-aws-modules
