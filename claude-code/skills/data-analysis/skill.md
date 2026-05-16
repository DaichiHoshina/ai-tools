---
name: data-analysis
description: Data analysis (BigQuery/PostgreSQL/MySQL/SQLite/CSV). SQL-free querying for data exploration.
requires-guidelines:
  - common
hooks:
  - event: PreSkillUse
    command: "~/.claude/hooks/pre-skill-use.sh"
---

# data-analysis

**Goal**: "6 months without writing a single SQL line"

## Supported Data Sources

| Source | CLI/Connection | Auth |
|--------|----------------|------|
| BigQuery | `bq` CLI | gcloud auth |
| PostgreSQL | `psql` | connection string / env var |
| MySQL | `mysql` CLI | connection string / my.cnf |
| SQLite | `sqlite3` | file path |
| CSV/JSON | `python pandas` | local file |

## Workflow

```
Natural language → Data source detection → SQL generation → pre-exec confirm → query run → result format → viz suggestion
```

### Example flow

1. **Input**: "Show top 10 products by revenue for past 30 days"
2. **Auto SQL**: Infer table → build SELECT/GROUP BY/ORDER BY/LIMIT
3. **Confirm**: Data source, ETA, scan size, read-only check → `[Y/n]`
4. **Output**: Formatted table + viz suggestions (bar/pie/trend)

## Security

### Critical (Forbidden)

| Violation | Action |
|-----------|--------|
| Write queries (UPDATE/DELETE/DROP) | Reject, enforce `SET TRANSACTION READ ONLY` |
| Sensitive data in plaintext (password/card) | Mask with `'***masked***'`, `RIGHT(card, 4)` |
| Password in env var | Use 1Password CLI / Secrets Manager |

### Warning (Confirm)

| Case | Action |
|------|--------|
| Full table scan | Use indices (`WHERE created_at >= '2024-01-01'`) |
| Large BigQuery scan | Partition: `WHERE _PARTITIONTIME >= TIMESTAMP(...)` |

## Output Format

Normal case:

```
Data source: {DB type} ({connection})
Scan estimate: {size / rows}
Cost estimate: {BigQuery if applicable}

Generated SQL:
{formatted SQL}

Execute? [Y/n]

---

Result:
{table format}

Viz suggestions:
  - {graph type 1}: {use case}
  - {graph type 2}: {use case}
```

Zero rows:

```
Data source: {DB type}
SQL: ...
Result: 0 rows

> [WARN] No data matched
Possible cause: date range / filter / table name mismatch
Next steps: relax WHERE clause / check table list (`\dt` / `bq ls`)
```

Connection/exec error:

```
> [ERROR] Connection failed / Query error
Data source: {DB type}
Error type: {auth / network / syntax / permission}
Details: {reason}
Next steps:
  - Auth: gcloud auth login / verify connection string
  - Permission: request read access
  - Syntax: provide corrected SQL
```

## Reference

For latest SQL syntax and function checks, use context7:
- BigQuery official docs
- PostgreSQL official docs
- pandas API reference

## Related skills

- **context7**: latest docs reference
- **security-error-review**: query security review
- **docs-test-review**: data analysis script documentation
