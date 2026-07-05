---
allowed-tools: Bash, Glob, Grep, Read, mcp__serena__*
name: comprehensive-review
description: "12-perspective code review (arch/quality/security/test). /review 呼び出し時に使用。"
context: fork
disallowed-tools:
  - Write
  - Edit
  - MultiEdit
agent: reviewer-agent
requires-guidelines:
  - common
  - clean-architecture
  - ddd
parameters:
  focus:
    type: enum
    values: [all, architecture, quality, readability, security, docs, test-coverage, root-cause, logging, writing, silent-failure, type-design, db-concurrency]
    default: all
    description: Review focus perspective
---

# comprehensive-review — 12-Perspective Code Review

## Perspectives

Details: `skills/comprehensive-review/references/` 配下 (`review-criteria.md` / `writing-docs.md` / `silent-failure.md` / `type-design.md` / `db-concurrency.md`) を後述 Conditional Reference Loading に従い読み込む。Noise discard / P2/P3 downgrade: `references/on-demand-rules/review-noise-discard.md`. Self-Review Gate C (`/flow`): `references/parallel-self-review.md` — fires via `reviewer-agent` 12-lens parallel.

| Perspective | Description |
|---|---|
| **architecture** | DDD boundaries, Clean Arch dependency direction, layer violations |
| **quality** | Language/FW best practice, local idioms, code smell, performance, type safety |
| **readability** | Naming, cognitive complexity, consistency |
| **security** | Authn/authz, injection, secrets, tenant/data isolation, unsafe logging |
| **docs / test-coverage** | Doc quality, test adequacy & quality |
| **root-cause** | Permanent fix vs workaround, recurrence patterns |
| **logging** | Log level appropriateness, structured logs |
| **writing** | Human-facing doc quality |
| **silent-failure** | Error swallowing, empty catch |
| **type-design** | Type-encoded invariants, avoid enum abuse |
| **db-concurrency** | InnoDB deadlock / gap lock / FOR UPDATE+INSERT / ODKU / external I/O in TX / missing retry |

## Effort-Linked Mode (`${CLAUDE_EFFORT}`)

| Effort | Critical Threshold | History | Perspectives |
|--------|---------------|---------|---------|
| `low` | 90+ | Skip | Skip writing/type-design/docs |
| `medium` (default) | 80+ | Past 90 days | All 12 |
| `high` | 70+ | Full history | + design tradeoff, dependencies |

## Execution Flow

> Steps 1-4: `reviewer-agent` (Sonnet). Step 4.5 output → parent Opus for Stage B aggregation.

**Step -1 (Noise)**: diff/code/docs only. Unverified → "hypothesis:". No nitpicks, no unsolicited TODO creation.

**Step 0 (History)**: Read `.claude/review-history.jsonl`. Same `file:line±3` + `focus` 3+ times → prefix `🔁 Repeated Finding (Nth time)`. Absent → `history: unavailable`.

### Step 1: Changed File Analysis

`git diff --name-only`. **Serena**: impact → `find_referencing_symbols` / impl → `find_implementations` / types → `get_diagnostics_for_file` / structure → `get_symbols_overview`. Default lenses: `quality` / `architecture` / `root-cause` / `security`.

| Condition | Add Perspective |
|------|---------|
| All files ∈ {`.md`, `.json`, `.yaml`, `.yml`, `.txt`, `.toml`, VERSION-like} | Limit to `docs` / `writing` / `readability` / `root-cause`; skip others ("docs-only mode") |
| Test file (`*_test.*`, `*.spec.*`) | `docs` |
| Logic change (non-test) | `test-coverage` + `silent-failure` |
| Type def change (`*.d.ts`, `types/*`, struct/interface added) | `type-design` |
| SQL/ORM change | `db-concurrency` |
| Mixed / uncertain | Full 12 perspectives |

### Step 2: Static Analysis

```bash
npm run lint && npx tsc --noEmit   # TypeScript
golangci-lint run && go vet ./...  # Go
```

exit 127 → `static-analysis: skipped`. exit 0/1 → incorporate. other non-zero → Warning.

### Step 3: Cleanup Enforcement

Unused imports/vars/functions, backward compat remnants, progress comments. Bash: `cmd || true` + `$? -ne 0`, duplicate `[[ -z "$x" ]]` after assign, `&&` chains under `set -e` with unreachable failure-path.

### Step 4 + 4.5: Scoring & Self-Filter

Score 0-100: **80+** (low 90+, high 70+) → Critical / **50-79** → Warning / **<25** → Discard. Validate each candidate:

| Check | Pass condition |
|---|---|
| Evidence | Anchored to diff/code/docs/tests/tool output |
| Scope | Tied to user request / code contract / changed behavior |
| Actionability | Author can fix in this change |
| Severity | Matches real impact and confidence; style backed by documented guideline |

Discard: "cleaner / more elegant" / "consider X" without defect. Zero findings valid — never invent.

**Step 5-6**: Append confirmed Critical/Warning (confidence ≥25) to `.claude/review-history.jsonl`.

## Output Format

```
## Review Results
### Perspectives Checked: architecture / quality / ...
### Critical (Confidence 80+)
- [security] SQL injection (src/api/user.ts:120) confidence 95
- 🔁 Repeated Finding (4th): [architecture] Domain→Infra ref (src/domain/user.ts:45) confidence 85
### Warning (Confidence 25-79)
- [quality] sort.Slice → slices.Sort (pkg/sort.go:15) confidence 65
Total: Critical N / Warning N / Discarded M / 🔁 Repeated K
```

Zero findings → `### Critical: 0`. Tags: `must`=Critical / `imo`,`nits`=Warning / `q`=question.

## Writing Enforcement (writing/docs/comment/prompt diff only)

Additional Step 4.5 checks via `guidelines/writing/PRINCIPLES.md` / `code-comment.md` / `prompt-engineering.md` / `long-form-doc.md`. confidence-80 filter applies. comment 品質の詳細規範は `code-comment` skill に委譲する (trigger 重複を避ける)。

## Conditional Reference Loading

`--type` absent or `all` → `references/` 配下 5 file 全部読む。単一 focus 時は該当 file + `review-criteria.md` のみ (`db-concurrency` → + `silent-failure.md`)。Step 1 前に load する。

## Multi-lens panel (`/review --panel` only)

`--panel` passes `reviewer-agent` × 3 (style / security / test-coverage) verdicts as pre-Step-1 input. Lens count canonical: `commands/review.md` §Multi-lens panel. Each verdict passes Stage A 7-point filter. Duplicates (same file:line, different lens, same root cause) → merge to 1. Merged list flows through Step 4.5 → Stage A → Stage B.
