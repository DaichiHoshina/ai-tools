---
name: ticket-to-pr-workflow
description: Execution stage workflow from ticket to PR completion (classification / worktree / WIP PR / PR split thresholds).
type: reference
---

# Ticket → PR Workflow

While `design-phase-flow.md` covers **command transitions** from idea to /docs, this file covers the **execution stages** from ticket origin. Covers 4 project-agnostic patterns.

## 1. Ticket classification flow

Immediately after reading a ticket (issue / Jira / Linear), classify into 3 types and decide next phase.

| Type | Criteria | Next phase |
|--------|---------|-----------|
| **New feature / spec change** | Adding or changing behavior | `/prd` → `/design-doc` → `/dev` |
| **Bug fix** | Existing behavior is broken | `/diagnose` → `/dev` |
| **Minor (typo / wording)** | No impact on code logic | `/dev --quick` direct impl |

Requirements items (new features only):

| Item | Content |
|------|------|
| Target users | Applicable roles |
| Desired behavior | Specific and concrete |
| Scope of impact | Existing features / screens / APIs |
| Edge cases | Not logged in, limits, flag OFF, etc. |
| Async side effects | Email / notifications / logs |

Mark unclear items as "unclear (needs confirmation)" and proceed (do not proceed on ambiguity).

## 2. Issue → worktree auto-setup pattern

For long-term issue work, separate worktree to avoid blocking main work. Naming convention and branching:

```bash
WT_REPO="${HOME}/ghq/github.com/{org}/{repo}"
WT_PATH="${TMPDIR:-/tmp}/wt-{issue-number}"

if [ -d "$WT_PATH" ]; then
  cd "$WT_PATH"   # move to existing worktree
else
  git -C "$WT_REPO" fetch origin main
  git -C "$WT_REPO" worktree add -b {issue-number}-{summary-english} "$WT_PATH" origin/main
  cd "$WT_PATH"
  # dependency setup (language/framework dependent)
fi
```

Branch naming: `{issue-number}-{summary-english}` (easy to grep by issue number).

## 3. WIP PR stages

Complete PR **incrementally** rather than immediately after implementation.

| Step | Content | Timing |
|------|------|-----------|
| A | Create WIP PR (draft, `[WIP]` prefix) **early** | Immediately after starting impl |
| B | Confirm CI pass | After commit |
| C | Output operation verification checklist | After CI pass |
| D | Attach evidence (screenshot/recording), remove WIP | After operation verification |

**Why early WIP PR**:
- Early sync to reviewers, early conflict detection
- Share PR URL before CI red is known → reduces blocking of other work
- Move spec discussion to PR code rather than Issue

Operation verification checklist template:

```markdown
### Local operation verification checklist

#### Required test data
- [ ] {auto-extracted from PRD/design doc}

#### Verification scenarios
- [ ] Normal flow
- [ ] Boundary values / edge cases
- [ ] Impact on existing features

#### Evidence
- [ ] Screenshot or screen recording
```

## 4. PR split numeric thresholds

Detailed thresholds for PR split strategy from `design-phase-flow.md`:

| Condition | Decision |
|------|------|
| 10+ changed files | Consider splitting |
| Includes migration / DB schema change | **Mandatory standalone PR** (do not mix with other changes) |
| 500+ line changes | Layer split (model/repo → usecase → handler → frontend) |

Why migration must be standalone PR: rolling back bundles application changes too, and deployment order accidents are common.

## Related

- `design-phase-flow.md` — upstream command transitions (/brainstorm → /prd → ...)
- `prd-review-checkpoints.md` — acceptance criteria / time boundary condition verification
- `multi-repo-workflow.md` — worktree parallel execution patterns
- `../guidelines/writing/design-doc-protocol.md` — Design Doc 4 steps + 12 sections / lightweight 5-section template
