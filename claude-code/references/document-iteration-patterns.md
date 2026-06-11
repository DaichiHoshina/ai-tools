---
name: Document Rewrite Phase Progression Patterns
description: Typical phases and fix patterns extracted from DesignDoc/PRD rewrite history after long review cycles.
type: reference
---

# Document Rewrite Phase Progression Patterns

Typical rewrite phases and fix patterns extracted from DesignDoc/PRD commit history after extended review cycles. Complements the static guide `../guidelines/writing/design-doc-protocol.md` by covering the dynamic evolution of rewrites.

## Phase Progression (typical order)

| Phase | Name | Typical commit message examples |
|-------|------|---------------------------------|
| 1 | Policy decision / draft | "{feature} DesignDoc" / "Scope confirmed: ..." / "Add {approach}" |
| 2 | Full rewrite (template compliance) | "Full rewrite per template" / "Full rewrite: remove background narrative" |
| 3 | Self-review / reinforcement | "Add Security/API Design sections" / "Improve visibility with Mermaid diagrams" |
| 4 | Codebase reconciliation | "Align with implementation" / "Unify {path/number} with implementation" |
| 5 | Review incorporation / deletion | "Review: delete non-template sections" / "Reduce redundancy" |
| 6 | Restore over-deletion | "Restore over-deleted bullets to readable form" |
| 7 | Style unification / lint | "Unify nominal style" / "Fix textlint errors (duplicate particles / colon-terminated)" |
| 8 | Major pivot full rewrite | "Major pivot: abolish {old policy}, unify to {new policy}" |

Phases 1–7 are the basic flow. Phase 8 is a mid-cycle reset event that restarts from Phase 2.

## Fix Patterns by Phase

### Phase 2: Full Rewrite

- Remove early-draft background narratives, free-form text, coined terms like "Plan A / Plan B"
- Reorganize headings to match template
- Drop exhaustive coverage mindset; prioritize readability
- Unify nominal style and bullet hierarchy

### Phase 3: Self-Review Reinforcement

Commonly missing sections to add:

- Security Considerations
- API Design / System Integration
- Risks / Performance
- Logging / Monitoring (specific metrics)
- Mermaid diagrams (flow / sequence)
- Numerical evidence with sources (local bench / production specs / actual measurements)

### Phase 4: Codebase Reconciliation

| Target | Fix pattern |
|--------|-------------|
| Migration numbers | Re-check latest number on main and update |
| Column layout / types | Match implementation (e.g., id INT→BIGINT) |
| API paths | Align to implementation directory path |
| Existing logic assumptions | Reflect code investigation results |
| DB / infra versions | Verify against IaC / production config |

### Phase 5: Review Incorporation / Deletion

Deletion candidates reviewers typically flag:

- Non-template sections (preconditions / Why not / excessive L2/L3 nesting)
- Redundant decision rationale tables, duplicate descriptions
- "Should be simpler" / "not needed" comments → delete immediately
- Same-concept paraphrase repetition
- Self-references / PR terminology

### Phase 6: Restore Over-Deletion

- Re-inject meaning where context broke after Phase 5 cuts
- Negotiate balance between deletion and preservation
- Recovery: "delete but consolidate key points elsewhere"

### Phase 7: Style Unification / Lint

- Unify nominal/polite style, units (10k / 100M / ms / MB)
- Fix textlint errors (duplicate particles / colon-terminated / missing period / exaggeration / continuous kanji)
- Unify bullet trailing punctuation
- Fix term notation inconsistencies (fix concept name vs implementation identifier usage)

### Phase 8: Major Pivot

When policy changes:

- Migrate to new policy in one pass without leaving old descriptions
- Delete "change history" / "background" sections too
- Remove all provisional flags / backward-compat descriptions (if new policy is clean-cut migration)
- Rewrite all affected Goals / Non-Goals / Risks / Migration Strategy

## Rewrite Anti-Patterns

| Anti-pattern | Symptom | Fix |
|---|---|---|
| Cascading partial fixes | 1 comment per commit, 20+ rounds | Batch reviews, do full rewrite in Phase 2 |
| Over-deletion | Restructuring cuts make doc incomprehensible | Relocate key info when deleting |
| Old descriptions remaining after pivot | Old phrasing mixed in after policy change | Purge including "change history" section |
| Submit without self-review | Many basic findings from reviewer | Run Phases 3-4 yourself before submitting |
| Divergence from implementation | Doc update missed after code change | Reconcile in Phase 4 |
| Start full template before policy confirmed | Frequent Phase 8 resets | Write lightweight version until policy is firm |

## Review Response Table

| Finding type | Response | Phase |
|---|---|---|
| "Not needed" / "What is this?" | Delete immediately | 5 |
| "More detail" / "Unclear" | Add paragraph explanation | 3 |
| "Differs from implementation" | Re-check code | 4 |
| "Policy differs" / "Contradicts past discussion" | Trace past discussion, revert to agreed-on plan | 4 |
| "Not in template" | Delete that section | 5 |
| "Mixed style" / "Units inconsistent" | Bulk replace | 7 |

## Rewrite Count Estimates

| Initial draft state | Expected rewrite count |
|---|---|
| Lightweight template-compliant draft | 3–5 commits |
| Full template-compliant draft | 5–10 commits |
| Free-form with background narratives | 20+ commits (Phase 2 full rewrite required) |
| Full template started before policy confirmed | 50+ commits (multiple Phase 8 resets) |

**Template compliance at initial draft dramatically reduces back-and-forth.** Start lightweight if policy is unsettled; upgrade to full version after confirmation.

## Pre-work to Reduce Rewrite Count

Follow these at first draft to minimize iterations:

1. **Fix policy in Phase 1**: Read PRD / past discussions / meeting notes fully before writing
2. **Start template-compliant**: Free-form triggers Phase 2 full rewrite
3. **Run Phases 3-4 yourself first**: Self-review + code reconciliation before requesting review
4. **Write lightweight if pivot is anticipated**: Discarding a full draft has high psychological cost
5. **Keep deletion candidates in mind**: See `../guidelines/writing/design-doc-protocol.md` "Anti-patterns" / "Self-check 18"

## Related

- `../guidelines/writing/design-doc-protocol.md` — DD principles / anti-patterns / template selection / self-check (static guide)
- `../guidelines/writing/PRINCIPLES.md` — common writing principles (4 questions / medium-specific structure)
- `decision-quality-checklist.md` — 5-question decision quality check (apply in Phase 1)
- `review-patterns-universal.md` — universal review finding patterns
