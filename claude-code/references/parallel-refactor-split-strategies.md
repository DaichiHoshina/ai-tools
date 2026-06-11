# Parallel Refactor Split Strategies

> **Purpose**: Strategy library for splitting large-scale file refactors across N parallel developer-agents. Specializes the CLAUDE.md "bundle prohibition" rule to the refactor domain.

Parallelism formula and overhead calculation: canonical in `references/PARALLEL-PATTERNS.md`. This file covers **refactor-specific split strategies** only.

## Applicability

Apply parallel split when **all** of the following are true:

- 5+ target files
- Low inter-file dependencies (same symbol not referenced across multiple files)
- Tight deadline or makespan reduction is priority

## 3 Strategies

### A. Directory-unit split

**Divide file groups by dir tree; assign one dev per dir.**

Effective when changes concentrate inside individual dirs with no shared imports / common symbols across dirs.

Example (commit `fdd03c6`, 28 files):

| dev | target dir |
|-----|-----------|
| dev1 | `guidelines/backend/*` |
| dev2 | `guidelines/common/*` |
| dev3 | `guidelines/languages/*` |
| dev4 | `guidelines/writing/*` + `guidelines/operations/*` |

4-parallel → makespan ≈ max(T_dev); ~75% reduction vs sequential.

**Prohibition**: when changing cross-dir cross-reference anchors → put both files in same dev, or extract anchor change to a separate phase.

### B. Layer-unit split

**Assign different devs to independent layers (frontmatter / body / footer) within files.**

Effective when file count is small and each layer is independent. However, physical constraint takes priority: **1 file = 1 dev only** (parallel edits to same file cause git conflicts).

Practical use: update all-file frontmatter in bulk + separate dev handles body refactoring (phase split).

```text
Phase 1: dev1-N update frontmatter (all files)
Phase 2: dev1-N body refactoring (after Phase 1 completes)
```

Phase dependency: confirm Phase 1 complete before firing Phase 2.

### C. Rule-unit split

**Assign one dev per rule from PRINCIPLES.md etc.; each dev touches only their assigned rule across all files.**

Effective when rules are independent and no single file is edited by 2+ devs simultaneously.

Example:

| dev | rule | changes |
|-----|----------|--------------------|
| dev1 | preamble compression | compress opening preamble to 1 sentence per file |
| dev2 | code block shortening | convert 5-line+ code blocks to tables |
| dev3 | surplus example reduction | reduce example sections to 2-3 blocks |

**Prohibition**: rule assignment where 2+ devs touch the same file simultaneously → guaranteed conflict; switch to strategy A.

## Strategy decision tree

```text
5+ target files?
  No → sequential (parallel overhead not worth it)
  Yes
    ↓
  Cross-dir shared symbol / anchor changes?
    Yes → extract dependencies to separate phase → remainder via strategy A
    No
      ↓
    Does any rule require multiple devs on same file simultaneously?
      Yes → strategy A (dir-unit)
      No
        ↓
        Rules independent? → strategy C
        Layers independent? → strategy B (phase split)
        Otherwise → strategy A
```

## N (parallelism) estimate

```text
N = min(8, ceil(total_files / 5))
```

Detailed formula (with overhead): canonical in `references/PARALLEL-PATTERNS.md#critical-path-reduction-formula`. This file is estimate-only.

## Pre-launch conflict detection

Run the following before launching parallel devs to detect overlap between edit targets and modified files.

```bash
# Check overlap between modified files and target files
git ls-files -m | grep -Fx -f <(echo "$TARGET_FILES")
```

Overlap found → wait for prior session to complete, or reassign targets.

## NG patterns (bundle prohibition)

**Throwing all 28 files to 1 dev is equivalent to sequential processing.**

| Pattern | Problem | Alternative |
|---------|------|------|
| List all files in 1 prompt | Sequential processing inside dev, makespan = sum(T_i) | Split by dir / layer / rule (strategies A/B/C) |
| Bundle 2+ domains (different dir groups) in 1 dev | Violates CLAUDE.md "bundle prohibition", makespan accumulates | Fire per-domain in parallel |
| Distribute cross-file anchor changes across parallel devs | Cross-reference desync, bats breakage risk | Do anchor changes first in a sequential phase |

Makespan estimate example (from commit `fdd03c6` actuals):

```text
Sequential (1 dev, 28 files): sum(T_i) ≈ 28 × 60s = 1680s
Parallel (4 dev, strategy A): LPT_makespan ≈ 420s + overhead_direct(4) = 420 + 100 = 520s
Reduction: (1680 - 520) / 1680 ≈ 69%
```

## Related

- `references/PARALLEL-PATTERNS.md` — parallelism formula, N selection rule, worktree flow (canonical)
- `CLAUDE.md` "bundle prohibition" — basis for split obligation
- `rules/markdown-anchor-sync.md` — bats / cross-ref sync on anchor changes
