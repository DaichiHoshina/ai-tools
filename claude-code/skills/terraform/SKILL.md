---
allowed-tools: Bash, Read, Glob, Grep
name: terraform
description: Terraform IaC: module design, state, security BP. Use for plan/apply & IaC.
requires-guidelines:
  - terraform
  - common
---

# terraform - Terraform IaC Design

## Checklist

check 項目 canonical: `guidelines/infrastructure/terraform.md` 参照。

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
