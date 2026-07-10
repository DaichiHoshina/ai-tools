---
name: Writing Patterns (Supplement)
description: Common principles in guidelines/writing/PRINCIPLES.md. This file covers supplement patterns only (rewrite phases / 3-stage review / textlint / phase boundaries / skill integration).
type: reference
---

# Writing Patterns (Supplement)

Common principles and per-medium guides: see `guidelines/writing/`. This file covers detailed pattern supplement (long-doc rewrite flow / textlint conventions / phase boundaries).

- [`guidelines/writing/PRINCIPLES.md`](../guidelines/writing/PRINCIPLES.md) — common principles (4 questions / 7 guidelines / 3 transforms / medium-specific structure / self-check 6)
- [`guidelines/writing/design-doc-protocol.md`](../guidelines/writing/design-doc-protocol.md) — DD 4-step + 10 patterns + anti-patterns + self-check 18
- [`guidelines/writing/long-form-doc.md`](../guidelines/writing/long-form-doc.md) — long-form docs (DD/PRD/RCA) + ADR/PRD/EARS templates
- [`guidelines/writing/external-post.md`](../guidelines/writing/external-post.md) — short-form (PR comments/Slack/Issues) + 5-axis scoring

## Rewrite Phases 1-8 (typical phases for long-review DD/PRD)

| Phase | Content |
|-------|---------|
| 1 Policy / draft | Read PRD / past discussions / meeting notes fully before starting |
| 2 Full rewrite | Template-compliant; remove background narratives / coined terms / exhaustive coverage |
| 3 Self-review reinforcement | Add Security / API Design / Risks / Performance / Logging / Mermaid diagrams / numerical evidence |
| 4 Codebase reconciliation | Align migration numbers / column layout / types / API paths / assumptions with implementation |
| 5 Review incorporation / deletion | Delete non-template / redundant / paraphrase repetition / self-references / PR terms |
| 6 Restore over-deletion | Re-inject meaning where context broke; negotiate deletion vs preservation |
| 7 Style unification / lint | Nominal style / register / units (10k・100M・ms・MB) / textlint |
| 8 Major pivot | Migrate to new policy in one pass; purge change history and background sections too |

**Rewrite count estimates**: lightweight template-compliant draft 3-5 commits / full template 5-10 / free-form 20+ / full template before policy confirmed 50+. Template compliance at initial draft dramatically reduces back-and-forth.

### Review Response Table

| Finding | Response | Phase |
|---------|----------|-------|
| "Not needed" / "What is this?" | Delete immediately | 5 |
| "More detail" / "Unclear" | Add paragraph explanation | 3 |
| "Differs from implementation" | Re-check code | 4 |
| "Policy differs" | Trace past discussion, revert | 4 |
| "Not in template" | Delete that section | 5 |
| "Mixed style" / "Units inconsistent" | Bulk replace | 7 |

## Review in 3 Stages: Content → Text → Structure

3 段レビュー canonical: `guidelines/writing/design-doc-protocol.md` §3 段レビュー参照。

## Detect Style Drift with textlint

Use textlint (`@textlint-ja/ai-writing` + `textlint-rule-preset-ja-technical-writing`) to mechanically detect style drift that's easy to miss by eye. CI conclusion may be success even with annotations — run locally before creating PR.

### Common NG Patterns

| Violation | NG example | OK example |
|-----------|-----------|-----------|
| Missing `。` at end of sentence (ends as noun phrase) | `含むもの` | `本設計では以下を扱う。` |
| Absolute expression | `完全に保証する` / `絶対に〜` | `確実に届ける` / `〜される` |
| Duplicate particles (same particle 2+ times in one sentence) | `処理が決済を含むため整合性が壊れる` ("が" twice) | Split sentence or replace one with `は` |
| Register mixing (常体 base with `である` mixed in) | `〜は大きいからである。` | `〜は大きい。` / `〜のためだ。` |
| AI listing pattern (all list items in `**emphasis**: explanation` form) | `- **高**: 設計を確定する前に〜` | Convert to table or expand to prose |

**Factual absolute expressions are OK**: Mathematical fact declarations like "ultimately always maps 1-to-1". What's prohibited is groundless assertions like "will definitely be maintained".

### Local Run

```sh
npx textlint -f pretty-error <path>.md
npx markdownlint-cli2 <path>.md
```

### CI Annotation Check (GitHub)

```sh
gh api repos/{owner}/{repo}/commits/<SHA>/check-runs \
  --jq '.check_runs[] | {name, conclusion, count: .output.annotations_count}'
gh api repos/{owner}/{repo}/check-runs/<ID>/annotations
```

Annotations on `.github/workflows/` path are from CI infra — ignore if unrelated to content.

## Don't Cross Design / Plan / Execute Phase Boundaries

Typical failure points in document-driven development.

| Phase | Allowed | Prohibited | Common violations |
|-------|---------|-----------|------------------|
| Design (DD / ADR) | Requirements analysis / alternative comparison / design decisions | Implementation / test creation / task breakdown | Start coding during design |
| Planning (task breakdown / ProjectDocs) | Task definition / dependency mapping / risk assessment | Implementation / design changes / new features | Touch implementation while writing plan |
| Execution (implementation / testing) | Implementation / tests / file operations | Design changes / scope expansion / new specs | "While I'm at it" refactoring or scope additions |

**Boundary detection question**: "Is what I'm writing now the artifact of this phase?" "Should this be written in the next phase?" If you hesitate, you're crossing the boundary.

## Skill Integration for Technical Documentation

Use related skills when writing technical docs (API design / backend design) to reduce terminology and structural drift.

| Writing target | Paired skill |
|----------------|-------------|
| REST/gRPC API design, endpoint specs | `/api-design` |
| Service layer / data access layer / job design | `/backend-dev` |
| Microservice integration / monorepo structure | `/microservices-monorepo` |
| Architecture decisions / DDD | `/clean-architecture-ddd` |
