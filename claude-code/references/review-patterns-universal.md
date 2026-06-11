---
name: Universal Review Finding Patterns
description: Project/language-agnostic finding patterns extracted from past PR reviews — design decisions and SQL dialects.
type: reference
---

# Universal Review Finding Patterns

Project/language-agnostic finding patterns extracted from past PR reviews.

## SQL

### SQL-1. Match DB dialect to the adopted DB

Do not write syntax that does not work on the adopted DB. On review, confirm syntax is valid for that DB.

| Syntax | MySQL 8.0+ | PostgreSQL |
|---|---|---|
| `FOR UPDATE SKIP LOCKED` | OK | OK |
| `FOR UPDATE OF table_name SKIP LOCKED` | NG (`OF` not supported) | OK |
| `RETURNING` clause | NG | OK |
| `INSERT ... ON CONFLICT` | NG (use `ON DUPLICATE KEY`) | OK |

Write DesignDoc and assumed SQL using adopted DB syntax. AI-generated output tends to mix other DB dialects.

## Design decisions

### 1. Consider API split vs. merge

Before creating a new API, evaluate whether adding functionality to an existing API is more natural. Discuss at DesignDoc stage.

### 2. Consider clients when deleting APIs

When deleting or breaking-change an endpoint, policy differs by client type:

| Client | Deletion condition |
|---|---|
| Web only | OK to delete once web references are gone |
| Native app | Delete after forced update eliminates that version |

- **Forced update**: mechanism preventing use below a certain version
- For native app APIs: confirm "which versions use it" and "current forced update threshold" before deletion

### 3. Verify consistency with prior discussions

For topics where policy was already decided in standup / chat / past PR, check recent discussion logs before writing. If proposing an alternative, present prior proposals as alternatives with adoption rationale.

- Reviewers remember prior discussions. Inconsistency triggers "not reflecting prior discussion"
- If prior discussions are reflected, add one line in body or Appendix: "agreed in {date} {venue}"

### 4. Review concepts made obsolete by new approach

When switching to a new approach, verify that concepts premised on the old approach (retry limits / fallbacks / compatibility flags etc.) are no longer needed. Leaving them creates over-engineering.

| Example | Old approach role | Reason obsolete in new approach |
|---|---|---|
| Retry limit | Retry on collision | Exclusive lock means cannot acquire = out of stock, retry produces same result |
| Compatibility flag | Old/new algorithm coexistence | No coexistence needed if switching all at once during maintenance window |
| Fallback branch | Old approach call on new approach failure | Unnecessary if new approach is simple |

### 5. Do not over-engineer with conservative estimates

Before introducing compatibility flags / phased migration / split design for "just in case" or "future extensibility", confirm production data scale and access patterns. If actual data is smaller than assumed, simple one-shot migration usually suffices.

- Verification: production DB read-only connection, metrics, past release history
- Building conservative design before estimates solidify leads to "should verify scale" pushback in review

## Related

- `../guidelines/writing/design-doc-protocol.md` — DesignDoc 4 steps + anti-patterns + self-check 18
- `decision-quality-checklist.md` — 5-question decision quality check
- `~/ai-tools/claude-code/guidelines/common/technical-pitfalls.md` — technical pitfalls
