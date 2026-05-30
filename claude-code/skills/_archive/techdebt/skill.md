---
name: techdebt
description: Technical debt detection. Detect duplicate code, DRY violations, propose refactoring. Use when resolving tech debt.
requires-guidelines:
  - common
  - clean-architecture
---

# techdebt - Technical Debt Detection

> **Source**: Boris hint #4 "Skill Creation" - Tasks run 2+ times/day → skill candidate

## Execution Flow

### Phase 1: Collect Scan Targets

**Tool**: `mcp__serena__list_dir(recursive: true)`

**Limits**: `max_files: 10,000` (warn if exceeded), timeout 30s

**Tool failure fallback**:

| Failure | Action |
|------|------|
| Serena unreachable / timeout | Fallback to `find . -type f`, warning log |
| max_files exceeded | Stop, request target dir narrowing |

### Phase 2: Exclusion Filter

| Category | Pattern |
|---------|---------|
| Secrets | `.env*`, `credentials*.json`, `secrets/**`, `*.key`, `*.pem` |
| Deps/Build | `node_modules/**`, `.git/**`, `dist/**`, `build/**`, `.next/**` |
| Generated | `*.min.{js,css}`, `*generated*`, `*_pb.ts`, `*.pb.go`, `__snapshots__/**` |

### Phase 3: Duplicate Code Detection

**Tool**: `mcp__serena__search_for_pattern` (fail → fallback to `grep -rn`, warn precision drop)

#### 3.1 Exact Match

- Condition: 5+ consecutive lines identical
- Algorithm: Split by 5 lines → SHA-256 hash → record matches by file:line

#### 3.2 Similar Code

- Condition: 80%+ similarity
- Method: Levenshtein distance, normalize vars/strings, compare

#### 3.3 DRY Violation Detection

| Violation Type | Detection | Example |
|-----------|----------|-----|
| Magic numbers | Same number 3+ places | `if (age > 18)` × 3 |
| Repeated logic | Same if/loop 3+ places | `if (user.role === 'admin')` × 3 |
| Duplicate validation | Same validation logic | Email check × 5 |

### Phase 4: Refactoring Proposal

For each finding:
- Duplicate code: Extract function target (file path) & import method
- DRY violation: Constantize (`src/constants/`) or common function
- Similar code: Common function with parameterized diffs

## Output Format

Normal case:

```markdown
# Technical Debt Detection Results
**Scan scope**: {project_path}

## Summary
| Item | Count |
|------|------|
| Scanned files | N |
| Duplicate code found | N locations |
| DRY violations | N locations |
| Reducible lines | ~N |

## Critical / Warning
Each item: file:line - violation - fix

## Recommended Actions
Immediate: Critical / Next sprint: Warning / Weekly: Scheduled runs
```

Zero findings:

```markdown
# Technical Debt Detection Results
**Scan scope**: {project_path}

## Summary
Scanned N files, zero findings.

## Critical / Warning
- Critical: 0
- Warning: 0

## Recommended Actions
Continue monitoring (weekly scan recommended)
```

Partial results (timeout / serena fallback):

```markdown
# Technical Debt Detection Results (Partial)
> [WARN] Timeout at 30s or serena → grep fallback
> Completion: X% / Precision: reduced

## Summary
(As above, N = confirmed only)

## Unscanned Areas
- {dir1}, {dir2} ...
- Full scan recommended with narrower targets
```

## Edge Cases

| Case | Action |
|--------|------|
| 0 files | "No tech debt detected" |
| max_files exceeded | "File count exceeds limit (10,000). Narrow target dirs." |
| Exclusion pattern miss | Never scan secrets (Critical error) |
| Timeout | 30s timeout, return partial |

## Limits

| Item | Limit | Reason |
|------|--------|------|
| Max files | 10,000 | Performance |
| Min duplicate lines | 5 | Noise reduction |
| Similarity threshold | 80% | Prevent false positives |
| Timeout | 30s | UX |

## Usage Examples

```
/techdebt               # Full project scan
/techdebt src/auth      # Specific dir only (fast)
/techdebt --verbose     # Show exclusions, similarity details
```

**Rule**: Tech debt visibility first step. Regular scans prevent debt growth.
