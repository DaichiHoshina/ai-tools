# Investigation Protocol

> **Purpose**: Maximize investigation accuracy and prevent oversights

---

## 3 Principles

| Principle | Detail |
|-----------|--------|
| Progressive deepening | Level 1 overview (1-2 min) → Level 2 detailed (5-10 min) → Level 3 thorough |
| Multiple source confirmation | ≥2 sources per finding; never conclude from a single source |
| Hypothesis-verification cycle | Build hypothesis → gather evidence → verify → conclude (rebuild on failure) |

---

## Serena MCP Priority

| Priority | Tool | Purpose |
|----------|------|---------|
| 1 | `get_symbols_overview` | Understand file structure |
| 2 | `find_symbol` | Find specific symbol |
| 3 | `find_referencing_symbols` | Locate usages |
| 4 | `search_for_pattern` | Pattern matching |
| 5 | Read/Grep/Glob | Only when Serena is insufficient |

---

## Investigation Phases

### Phase 1: Information Gathering

- Define purpose, scope, tools, and estimated time before starting
- If scope exceeds 50 files, prioritize narrowing first

### Phase 2: Analysis

- Pattern detection: report only findings with confidence ≥ 0.8
- Visualize dependency graph structure
- Detect and record contradictory findings

### Phase 3: Verification (required)

- Re-confirm all important findings by an independent method
- Check for counter-examples and edge cases
- Cross-check with multiple sources
- Completeness check: confirm all required items are covered

---

## Investigation Type Checklists

| Type | Key Steps | Verification Points |
|------|-----------|---------------------|
| **1 Code** | symbols_overview → find_symbol → referencing → dependency map → identify architecture | All components confirmed / dependencies accurate / edge cases |
| **2 Bug** | Clarify repro steps → locate relevant code → trace data flow → multiple hypotheses → root cause | Multiple hypotheses / repro confirmed / side effects considered |
| **3 Performance** | Measure metrics → profile analysis → check hotspots/N+1 → identify optimization | Measurement-based / impact estimated |
| **4 Security** | Check attack surface/input validation/auth-authz → data flow → OWASP Top 10 → CVSS eval | All input points / actual exploitability / impact scope |

---

## Quality Standards

| Metric | Threshold |
|--------|-----------|
| Confirmed sources | ≥3 |
| Verified finding rate | ≥90% |
| Contradictions | 0 |
| Completeness | ≥95% |
| Confidence | ≥85% |

---

## Red Flags (re-investigation triggers)

| State | Action |
|-------|--------|
| Contradictory information | Resolve with additional investigation |
| Confidence < 0.8 | Gather more evidence |
| Single source only | Confirm with another source |
| Completeness < 0.9 | Re-check for oversights |
| Hypothesis cannot be verified | Rebuild hypothesis |

---

## Investigation Report Template

```markdown
# Investigation Report: [Target]
## Summary — Purpose / Scope / Time taken
## Findings — Content / Source / Confidence XX% / Verified
## Dependencies / Contradictions / Unconfirmed items
## Conclusions and recommendations
## Quality metrics — Sources X / Verified X/Y / Completeness XX%
```

---

**Achieve high-accuracy investigation through progressive deepening, multiple source confirmation, and thorough verification.**
