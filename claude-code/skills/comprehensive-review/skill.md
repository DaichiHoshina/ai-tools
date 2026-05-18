---
name: comprehensive-review
description: "Comprehensive code review (12 perspectives - design/quality/readability/security/docs/test/root-cause/logging/db-concurrency). Called from /review, filter with --focus. Use when reviewing code."
context: fork
agent: reviewer-agent
requires-guidelines:
  - common
  - clean-architecture
  - domain-driven-design
parameters:
  focus:
    type: enum
    values: [all, architecture, quality, readability, security, docs, test-coverage, root-cause, logging, writing, silent-failure, type-design, db-concurrency]
    default: all
    description: Review focus perspective
---

# comprehensive-review - Comprehensive Code Review

## 12 Perspectives

| Perspective | Description | Details |
|------|------|------|
| **architecture** | DDD boundaries, Clean Architecture dependency direction, modular monolith module boundaries, layer violations | `review-criteria.md` |
| **quality** | Language/FW best practices, local idioms, code smell, performance, type safety | `review-criteria.md` |
| **readability** | Naming, cognitive complexity, consistency | `review-criteria.md` |
| **security** | Authn/authz, injection, secrets, tenant/data isolation, unsafe logging, dependency/config exposure | `review-criteria.md` |
| **docs** | Doc quality, test adequacy | `review-criteria.md` |
| **test-coverage** | Test case adequacy & quality | `review-criteria.md` |
| **root-cause** | Permanent fix vs workaround, root cause coverage, recurrence patterns | `review-criteria.md` |
| **logging** | Log level appropriateness, structured logs | `review-criteria.md` |
| **writing** | Human-facing doc quality | `writing-docs.md` |
| **silent-failure** | Error swallowing, empty catch | `silent-failure.md` |
| **type-design** | Type-encoded invariants, avoid enum abuse | `type-design.md` |
| **db-concurrency** | InnoDB暗黙deadlock / gap lock / FOR UPDATE+INSERT / ODKU昇格 / TX内外部I/O / retry不在 | `db-concurrency.md` |

## Effort-Linked Mode (`${CLAUDE_EFFORT}`)

Confidence thresholds & coverage vary by effort level.

| Effort | Critical Threshold | History | Perspectives |
|--------|---------------|---------|---------|
| `low` | 90+ (minimize false positives) | Skip | Skip writing/type-design/docs |
| `medium` (default) | 80+ | Past 90 days | All 12 |
| `high` | 70+ (evidence-backed safety/design issues only) | Full history | + design tradeoff, dependencies |

## Execution Flow

### Step -1: Noise Suppression & Task Control

- Basis: only read diff/code/docs. Mark guesses "hypothesis:". No style/preference/general theory nitpicks.
- Skip design debates outside scope, don't oppose existing patterns with general theory
- Only actionable findings backed by an observed violation, regression, or concrete risk in the requested scope.
- Don't invent a problem statement and then point out that the diff fails it. If the requirement is not in the user request, issue/design docs, tests, code contract, or actual runtime/tool evidence, don't promote it to a finding.
- "Could be better", "might be useful", and "best to check" are notes/questions at most, not Critical/Warning.
- Create new issue/ticket/task only on explicit user request. Don't elevate past examples to required tasks.
- Don't TODO "just in case" or "confirm" items. TODO only today's blockers.
- Don't re-add work user explicitly marked unnecessary.

### Step 0: Load History (Detect Repeats)

Read `.claude/review-history.jsonl`. If same `file:line±3 lines` + same `focus` appears **3+ times in history**, prefix with `🔁 Repeated Finding (Nth time)` (signals team-level issue).

**If history absent** (`.claude/review-history.jsonl` not created/empty/jq missing): Skip repeat detection, continue from Step 1. Mark output end with `history: unavailable`.

### Step 1: Changed File Analysis

Use `git diff --name-only` to determine language, file type, change scope & auto-decide extra perspectives.

**Serena priority for code files** (more accurate, prevent missed refs):
- Impact scope → `find_referencing_symbols`
- interface ↔ impl → `find_implementations`
- Declaration → `find_declaration`
- Type check → `get_diagnostics_for_file` (no external typecheck, direct LSP)
- Structure → `get_symbols_overview`, symbol search → `find_symbol`

Non-code files (md/yaml/json/toml/lockfile/.env) → use Grep/Read (Serena N/A).

Default code review lenses:

- `quality`: verify language/FW best practices against actual language, framework, and project-local conventions.
- `architecture`: verify DDD, Clean Architecture, and modular monolith boundaries only where the changed code crosses those boundaries.
- `root-cause`: verify the change addresses the observed root cause, not just the visible symptom.
- `security`: verify concrete security surfaces touched by the diff.

| Condition | Add Perspective |
|------|---------|
| Test file (`*_test.*`, `*.spec.*`) | `docs` |
| UI file (`components/*`, `*.tsx`) | `uiux-review` (separate skill) |
| Logic change (non-test) | `test-coverage` + `silent-failure` |
| Type def change (`*.d.ts`, `types/*`, struct/interface added) | `type-design` |
| SQL/ORM変更 (`*.sql`、`*Repository*`、`tx.Exec`、`SELECT.*FOR UPDATE`、`ON DUPLICATE KEY`) | `db-concurrency` |

### Step 2: Run Static Analysis Tools

```bash
# TypeScript
npm run lint && npx tsc --noEmit

# Go
golangci-lint run && go vet ./...
```

**Tool presence**: Judge by command execution result (not PATH lookup). `npx tsc` / `npm run <script>` resolve via `node_modules/.bin/`, runnable even if not in global PATH.

**Priority order**: Evaluate top-to-bottom, confirm at first match (message match first, exit code last).

| # | Condition | Action | Skip Reason |
|---|-----------|------|-----------------|
| 1 | stderr contains `command not found` / `npm ERR! Missing script` / `could not determine executable` | skip | `static-analysis: skipped (<cmd or pkg>: not installed/script missing/not in node_modules)` |
| 2 | exit 127 (shell "command not found" fixed value) | skip | `static-analysis: skipped (<cmd>: not found)` |
| 3 | exit 0/1 AND stdout/stderr has analyzer output (lint violation / type error / `error TS` etc) | incorporate results & continue | — |
| 4 | other non-zero exit (none of #1-#3) | include as Warning, continue review | — |

### Step 3: Check cleanup-enforcement

Verify unused imports/vars/functions, backward compat remnants, progress comments.

### Step 4: Confidence Scoring (Noise Reduction)

Assign 0-100 confidence score to each finding, downgrade/discard low scores.

**Filter rules (medium default)**:

| Score Range | Action |
|---------|------|
| 80+ (low 90+, high 70+) | Output as Critical |
| 50-79 | Downgrade to Warning |
| 25-49 | Output as Warning |
| <25 | Discard (no output) |

### Step 4.5: Finding Self-Review Gate

Before output, validate each remaining candidate finding:

| Check | Pass condition | Fail action |
|---|---|---|
| Evidence | Directly anchored to observed diff/code/docs/tests/tool output | Discard |
| Scope | Tied to user request, issue/design doc, code contract, or changed behavior | Discard or move to question |
| Overreach | Does not invent a new problem statement or requirement | Discard |
| Actionability | Author can fix code/docs/tests in this change | Discard or note only |
| Severity | Critical/Warning matches real impact and confidence | Downgrade or discard |

Only publish findings that pass this gate. Do not show the gate checklist in the final output unless explaining why no findings remain.

### Step 5-6: Aggregate & Record History

Append confirmed Critical/Warning (confidence ≥25) to `.claude/review-history.jsonl` (fields: date/severity/focus/file/line/finding/confidence/branch/commit).

## Output Format

```markdown
## Comprehensive Review Results

### Perspectives Checked
- architecture / quality / readability / security / docs / test-coverage / root-cause / logging / writing / silent-failure / type-design

### Critical (Fix Required, Confidence 80+)
- [security] SQL injection (src/api/user.ts:120) confidence 95
- 🔁 Repeated Finding (4th time): [architecture] Domain→Infrastructure ref (src/domain/user.ts:45) confidence 85

### Warning (Improve, Confidence 25-79)
- [quality] Old pattern: sort.Slice → slices.Sort (pkg/sort.go:15) confidence 65

Total: Critical N / Warning N / Discarded M / 🔁 Repeated K
```

**Zero findings rule**: Never omit sections (Critical/Warning). If 0, write `### Critical: 0`. Skip skipped perspectives from executed list, add `### skipped: <perspective> (<reason>)` section.

## Notes

- focus=all → all 12 in parallel; large diffs → 1 file at a time, Critical first
- Provide concrete fixes; comment tags: `must`=Critical / `imo`,`nits`=Warning / `q`=question
- Forbid baseless task creation, invented problem framing, or out-of-scope operational TODOs.
