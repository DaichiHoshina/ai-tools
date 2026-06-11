---
name: PRD Review Checkpoints
description: Review focus areas for human reviewers of PRDs (areas not covered by AI tools).
type: reference
---

# PRD Review Checkpoints (for Human Reviewers)

AI tools (automated review bots, etc.) auto-cover notation inconsistencies, template compliance, and typos. Human reviewers should focus on specification validity.

## 1. Specification Definition Clarity

| Aspect | Check |
|--------|-------|
| **Timestamps / boundary conditions** | Are timestamp field names, timezones (JST/UTC, etc.), and boundaries (`>=` vs `>`) explicit? |
| **Term alignment** | Do ubiquitous language, DB field names, and code naming match? |
| **Judgment logic source of truth** | When multiple judgment sources exist, is the authoritative one specified? |

## 2. Acceptance Condition Verifiability

- Does each user story have **acceptance conditions that determine implementation completion**?
- Are boundary values and exception cases (out of stock, not logged in, restriction flag set, etc.) included in acceptance conditions?

## 3. Implementation / Operational Consistency

| Aspect | Check |
|--------|-------|
| **Implementation alignment** | Does the spec not contradict actual system behavior and constraints (API, DB structure, existing logic)? |
| **Release procedure** | Are feature flag ON timing / phase order / deployment sequence consistent? |
| **Impact on existing features** | Is backward compatibility maintained for in-progress / processing data? |

## 4. Coverage Gaps

- Is behavior for **unauthenticated users** defined where needed?
- Is **admin screen** operation spec included for features that require it?
- Are **error messages** defined (especially when multiple failure patterns exist)?
- Are async side effects like **notifications / email** covered?

## 5. Reviewer Focus Areas Convention

When boundary conditions are likely to be ambiguous, include the following in the PR body for easier review:

```markdown
## Review focus areas

- Whether the definition of XX (which system field to use) aligns with implementation
- Whether the timing definition of XX is consistent with the release schedule
```

## Related

- `decision-quality-checklist.md` — 5-question decision quality check shared across PRD/DesignDoc
- `../guidelines/writing/design-doc-protocol.md` — DesignDoc writing guide (4 steps + 10 patterns + template selection)
