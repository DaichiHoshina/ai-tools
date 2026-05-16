---
paths:
  - "**/*.sql"
  - "**/*migration*"
  - "**/*repository*"
  - "**/*repo*"
---
# Database Operation Rules

## Safety Principles

- **All environments (dev/test/prd) read-only** by default. No write without approval
- Confirm with user before writing
- Migrations in separate PR (no mixed changes)
- Do not directly reference DB tables from other services/contexts

## Production DB Access (Claude Code operations)

| Item | Rule |
|------|--------|
| Connection | reader-only (`reader.db.prod.*.internal` etc), writer prohibited |
| Auth | User's own AWS SSO + jump command (e.g. `make aws-start-session-prod`) |
| Query | SELECT only, `LIMIT` required (~100 rows), no full scans |
| Write | UPDATE/DELETE/INSERT/DDL strictly forbidden |
| Secrets | No email/phone/address/payment info in chat. Mask with `id, created_at` |
| Log | All sessions logged (audited) |

**Flow**: User states intent → Claude proposes SELECT → User executes via jump → Share result summary only (no raw dump)

**Anti-patterns**: User runs jump session for Claude / Paste tables with PII / Repeated exploratory `SELECT *`
