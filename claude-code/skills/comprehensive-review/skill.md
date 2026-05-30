---
name: comprehensive-review
description: "Comprehensive code review across 12 perspectives (architecture/quality/readability/security/test/DB etc). Called from /review, narrow with --focus. Use when reviewing code."
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

Details: `references/review-criteria.md` (architecture/quality/readability/security/docs/test-coverage/root-cause/logging) / `writing-docs.md` / `silent-failure.md` / `type-design.md` / `db-concurrency.md`.

| Perspective | Description |
|---|---|
| **architecture** | DDD boundaries, Clean Arch dependency direction, modular monolith boundaries, layer violations |
| **quality** | Language/FW best practice, local idioms, code smell, performance, type safety |
| **readability** | Naming, cognitive complexity, consistency |
| **security** | Authn/authz, injection, secrets, tenant/data isolation, unsafe logging, dependency/config exposure |
| **docs / test-coverage** | Doc quality, test adequacy & quality |
| **root-cause** | Permanent fix vs workaround, recurrence patterns |
| **logging** | Log level appropriateness, structured logs |
| **writing** | Human-facing doc quality |
| **silent-failure** | Error swallowing, empty catch |
| **type-design** | Type-encoded invariants, avoid enum abuse |
| **db-concurrency** | InnoDB implicit deadlock / gap lock / FOR UPDATE+INSERT / ODKU escalation / external I/O in TX / missing retry |

## Effort-Linked Mode (`${CLAUDE_EFFORT}`)

Confidence thresholds & coverage vary by effort level.

| Effort | Critical Threshold | History | Perspectives |
|--------|---------------|---------|---------|
| `low` | 90+ (minimize false positives) | Skip | Skip writing/type-design/docs |
| `medium` (default) | 80+ | Past 90 days | All 12 |
| `high` | 70+ (evidence-backed safety/design issues only) | Full history | + design tradeoff, dependencies |

## Execution Flow

> **Execution model**: This skill runs inside `reviewer-agent` (Sonnet). Steps 1-4 are Sonnet-executed. Step 4.5 (Self-Filter Gate) output is returned to parent Opus for Stage B aggregation and final filter.

### Step -1: Noise Suppression

- Read diff/code/docs only. Guess → prefix "hypothesis:". No style/preference/theory nitpicks.
- Findings must be anchored to an observed violation/regression/concrete risk in scope.
- "could be better" / "might be useful" / "best to check" → note/question only, never Critical/Warning.
- Create issue/task only on explicit user request. No "just in case" / "confirm" TODOs — today's blockers only. Don't re-add work the user explicitly marked unnecessary.

### Step 0: Load History (Detect Repeats)

Read `.claude/review-history.jsonl`. If same `file:line±3` + same `focus` appears 3+ times → prefix `🔁 Repeated Finding (Nth time)`. History absent (not created/empty/jq missing) → skip, mark output end with `history: unavailable`.

### Step 1: Changed File Analysis

`git diff --name-only` to determine language/file type/scope and auto-decide extra perspectives.

**Serena priority** (code files, prevent missed refs): impact → `find_referencing_symbols` / interface↔impl → `find_implementations` / decl → `find_declaration` / type check → `get_diagnostics_for_file` (direct LSP, no external typecheck) / structure → `get_symbols_overview` + `find_symbol`. Non-code (md/yaml/json/toml/lockfile/.env) → Grep/Read.

Default lenses: `quality` (language/FW/project-local conventions) / `architecture` (DDD / Clean Arch / modular monolith boundaries only where the diff crosses them) / `root-cause` (root cause over symptom) / `security` (security surfaces touched by diff).

| Condition | Add Perspective |
|------|---------|
| All files extension ∈ {`.md`, `.json`, `.yaml`, `.yml`, `.txt`, `.toml`, VERSION-like} (docs-only) | Limit to `docs` / `writing` / `readability` / `root-cause`; skip `security` / `silent-failure` / `type-design` / `db-concurrency` / `test-coverage` / `logging` (note in output: "Perspectives Checked: 4/11 (docs-only mode; security/silent-failure/type-design/db-concurrency/test-coverage/logging skipped)") |
| Test file (`*_test.*`, `*.spec.*`) | `docs` |
| UI file (`components/*`, `*.tsx`) | `uiux-review` (separate skill) |
| Logic change (non-test) | `test-coverage` + `silent-failure` |
| Type def change (`*.d.ts`, `types/*`, struct/interface added) | `type-design` |
| SQL/ORM change (`*.sql`, `*Repository*`, `tx.Exec`, `SELECT.*FOR UPDATE`, `ON DUPLICATE KEY`) | `db-concurrency` |
| Mixed code + docs / judgment uncertain | Full 11 perspectives (defensive default) |

### Step 2: Run Static Analysis Tools

```bash
# TypeScript
npm run lint && npx tsc --noEmit

# Go
golangci-lint run && go vet ./...
```

**Tool presence**: judge by execution result (no PATH lookup). `npx tsc` / `npm run` resolve via `node_modules/.bin/`.

**Evaluation order** (top-to-bottom, first match wins; message match before exit code):

| # | Condition | Action |
|---|---|---|
| 1 | stderr has `command not found` / `npm ERR! Missing script` / `could not determine executable` | skip → `static-analysis: skipped (<cmd>: not installed/missing)` |
| 2 | exit 127 | skip → `static-analysis: skipped (<cmd>: not found)` |
| 3 | exit 0/1 + analyzer output present (lint violation / type error / `error TS` etc) | incorporate results, continue |
| 4 | other non-zero | include as Warning, continue |

### Step 3: cleanup-enforcement

Verify unused imports/vars/functions, backward compat remnants, progress comments. For bash/shell: detect dead code patterns — `cmd || true` followed by `$? -ne 0` check (always 0), duplicate `[[ -z "$x" ]]` after `x="default"` assignment, and `&&` chains under `set -e` where failure-path is unreachable.

### Step 4: Confidence Scoring (medium default)

Assign 0-100 score to each finding: **80+** (low 90+, high 70+) → Critical / **50-79** → downgrade to Warning / **25-49** → Warning / **<25** → Discard.

### Step 4.5: Self-Filter Gate (moderate strictness)

Validate each candidate (Fail → discard; severity mismatch → downgrade):

- **Evidence**: anchored directly to diff/code/docs/tests/tool output
- **Scope**: tied to user request / issue / design doc / code contract / changed behavior
- **Overreach**: no invented problem statement or requirement
- **Actionability**: author can fix in this change
- **Severity**: Critical/Warning matches real impact and confidence
- **Style/preference**: backed by documented guideline/contract (not aesthetic taste)
- **Overprescription**: a reasonable engineer would call it a defect (not just an alternative)

**Pre-emission sanity check**: discard findings matching "cleaner / more elegant / better naming" (no rule violation) / "verbose / shorter" (prose preference) / "same concept in multiple places" (no drift risk) / restating existing TODO / intentional design choice flagged as deviation / "consider X" without a concrete defect. Publish only findings passing both gate and sanity check; zero findings is the correct outcome (never invent); show the checklist itself only when explaining why no findings remain.

### Step 5-6: Aggregate & Record History

Append confirmed Critical/Warning (confidence ≥25) to `.claude/review-history.jsonl` (fields: date/severity/focus/file/line/finding/confidence/branch/commit).

## Output Format

```markdown
## Comprehensive Review Results

### Perspectives Checked
- architecture / quality / readability / security / docs / test-coverage / root-cause / logging / writing / silent-failure / type-design

### Critical (Confidence 80+)
- [security] SQL injection (src/api/user.ts:120) confidence 95
- 🔁 Repeated Finding (4th time): [architecture] Domain→Infra ref (src/domain/user.ts:45) confidence 85

### Warning (Confidence 25-79)
- [quality] sort.Slice → slices.Sort (pkg/sort.go:15) confidence 65

Total: Critical N / Warning N / Discarded M / 🔁 Repeated K
```

**Zero findings rule**: never omit sections; 0 cases → `### Critical: 0`. Skipped perspectives are removed from the executed list and added as `### skipped: <perspective> (<reason>)`.

## Notes

focus=all → 12 in parallel; large diffs → 1 file at a time, Critical first. Provide concrete fixes; tags: `must`=Critical / `imo`,`nits`=Warning / `q`=question. Forbid baseless task creation, invented problem framing, or out-of-scope operational TODOs.
