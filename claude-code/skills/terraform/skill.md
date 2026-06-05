---
name: terraform
description: Terraform IaC: module design, state, security BP. Use for plan/apply & IaC.
requires-guidelines:
  - terraform
  - common
---

# terraform - Terraform IaC Design

## Checklist Summary

### Critical (Fix Required)

| # | Check | Summary |
|---|---------|------|
| 1 | Version pinning | Set versions in required_version + required_providers |
| 2 | Secret management | No hardcoding, use Secrets Manager / SSM |
| 3 | Remote state | S3 + DynamoDB, encryption & versioning enabled |
| 4 | IAM least privilege | No Action: "*", allow only necessary operations |

### Warning (Improve)

| # | Check | Summary |
|---|---------|------|
| 1 | Modularize | Split bloated main.tf → modules/ |
| 2 | Tagging | Define common tags in locals, apply to all resources |
| 3 | Official modules | Use terraform-aws-modules |

## Checklist

| Category | Items |
|---------|------|
| Security | No secret hardcoding, IAM least privilege, S3 encryption, no public access, VPC endpoints |
| State | S3+DynamoDB remote state, separate per env, encryption & versioning enabled |
| Code Quality | terraform fmt/validate, variables have description+type, required tags set |
| Workflow | terraform plan before apply, share plan in PR, review before apply |

## Output Format

Normal case:

```text
Critical: `file:line` - security risk/version not pinned - fix
Warning: `file:line` - design improvement - suggestion
Summary: Critical X / Warning Y
```

Zero findings:

```text
✅ Terraform findings: 0 (N files)
Summary: Critical 0 / Warning 0
Recommend: Continue checking environment diff with terraform plan
```

No review target (Terraform files not found):

```text
> [WARN] *.tf / *.tfvars not found
> Search: . / terraform/ / infrastructure/
> Skipped
```

## Troubleshooting

### Error: State lock acquisition failed
Cause: Previous terraform apply/plan crashed, lock remains
Fix: `terraform force-unlock <LOCK_ID>` (confirm no other users)

### Error: Provider version conflict
Cause: .terraform.lock.hcl vs required_providers version mismatch
Fix: `terraform init -upgrade` to update providers

## References

- Guidelines: `~/.claude/guidelines/infrastructure/terraform.md`
- Latest docs: Use context7
