---
name: comprehensive-review
description: Comprehensive code review (11 perspectives: design/quality/readability/security/docs/test/root-cause/logging). Called from /review, filter with --focus. Use when reviewing code.
context: fork
agent: reviewer-agent
requires-guidelines:
  - common
  - clean-architecture
  - domain-driven-design
parameters:
  focus:
    type: enum
    values: [all, architecture, quality, readability, security, docs, test-coverage, root-cause, logging, writing, silent-failure, type-design]
    default: all
    description: Review focus perspective
---

# comprehensive-review - Comprehensive Code Review

## 11 Perspectives

| Perspective | Description | Details |
|------|------|------|
| **architecture** | Clean arch, DDD, layer violations | `review-criteria.md` |
| **quality** | Code smell, performance, type safety | `review-criteria.md` |
| **readability** | Naming, cognitive complexity, consistency | `review-criteria.md` |
| **security** | OWASP Top 10, credential leaks | `review-criteria.md` |
| **docs** | Doc quality, test adequacy | `review-criteria.md` |
| **test-coverage** | Test case adequacy & quality | `review-criteria.md` |
| **root-cause** | Band-aid vs root fix, recurrence patterns | `review-criteria.md` |
| **logging** | Log level appropriateness, structured logs | `review-criteria.md` |
| **writing** | Human-facing doc quality | `writing-docs.md` |
| **silent-failure** | Error swallowing, empty catch | `silent-failure.md` |
| **type-design** | Type-encoded invariants, avoid enum abuse | `type-design.md` |

## Effort-Linked Mode (`${CLAUDE_EFFORT}`)

Confidence thresholds & coverage vary by effort level.

| Effort | Critical Threshold | History | Perspectives |
|--------|---------------|---------|---------|
| `low` | 90+ (minimize false positives) | Skip | Skip writing/type-design/docs |
| `medium` (default) | 80+ | Past 90 days | All 11 |
| `high` | 70+ (prefer over-detection) | Full history | + design tradeoff, dependencies |

If `${CLAUDE_EFFORT}` not set, treat as `medium`.

## Execution Flow

### Step -1: Noise Suppression & Task Control

- Basis: only read diff/code/docs. Mark guesses "hypothesis:". No style/preference/general theory nitpicks.
- Skip design debates outside scope, don't oppose existing patterns with general theory
- Only actionable findings
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

| Condition | Add Perspective |
|------|---------|
| Test file (`*_test.*`, `*.spec.*`) | `docs` |
| UI file (`components/*`, `*.tsx`) | `uiux-review` (separate skill) |
| Logic change (non-test) | `test-coverage` + `silent-failure` |
| Type def change (`*.d.ts`, `types/*`, struct/interface added) | `type-design` |

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

Review always continues regardless.

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

### Step 5-6: Aggregate & Record History

Append confirmed Critical/Warning (confidence ≥25) to `.claude/review-history.jsonl`.

```json
{"date":"2026-04-27","severity":"Critical","focus":"security","file":"src/api/user.ts","line":120,"finding":"SQLi","confidence":95,"branch":"feat/x","commit":"abc1234"}
```

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

- focus=all runs all 11 in parallel
- Large diffs: 1 file at a time, Critical first
- Provide concrete fixes, not just findings
- Comment tags: `must`=Critical / `imo`,`nits`=Warning / `q`=question
- Even in over-detection, forbid baseless task creation or out-of-scope operational TODOs
