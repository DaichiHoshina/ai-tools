# Design Phase Transitions and Command Roles

Position and transitions of 6 commands from requirements clarification through implementation and knowledge retention.

## Transition diagram

```
[Idea]
   │
   ├─(1) Design unclear ──→ /brainstorm (Superpowers, interactive refinement)
   │                          │
   │                          ▼
   │                (1.5) Proposal verify ──→ /verify-proposal (実物突き合わせ + 改善 + reviewer-agent review)
   │                          │
   ▼                          ▼
[Requirements visible] ←──────┘
   │
   └─(2) Requirements clarification ──→ /prd (11-persona review, Q1-Q5 decisions)
                         │
                         ▼
                  [PRD confirmed (chat or md)]
                         │
   ┌─────────────────────┤
   │                     ▼
   │  (3) Design doc ──→ /design-doc (12-section md for team sharing)
   │                     │
   │                     ▼
   │              [Design Doc (docs/design/*.md)]
   │                     │
   ▼                     │
(4) Impl plan ──→ /plan (PO Agent, phase split, ~/.claude/plans/)
                         │
                         ▼
                  (5) Implementation ──→ /dev or /flow
                                    │
                                    ▼
                            [Validation / PR]
                                    │
                                    ▼
                  (6) Knowledge retention ──→ /docs (Notion post)
```

## Command responsibilities

| # | Command | Input | Output | Phase |
|---|---------|------|------|---------|
| 1 | `/brainstorm` | Vague problem | chat (refined requirements) | Diverge / dialogue |
| 1.5 | `/verify-proposal` | Proposal / candidate list | chat (verdict table + review) | Reality check |
| 2 | `/prd` | Requirements | chat or `--out` md | Requirements definition |
| 3 | `/design-doc` | PRD (`--prd`) or natural language | `docs/design/<slug>.md` | Design |
| 4 | `/plan` | Design Doc or pre-designed premise | chat or `~/.claude/plans/*.md` | Impl planning |
| 5 | `/dev` `/flow` | Plan or task | Code changes | Implementation |
| 6 | `/docs` | git diff or `--from <md>` | Notion page | Post-completion retention |

## Decision axis for command selection

| Situation | Recommended starting point |
|------|---------------|
| Requirements and design both unclear | `/brainstorm` |
| Requirements exist but not organized | `/prd` |
| PRD done, need to create design | `/design-doc --prd <path>` |
| Design done, need phase breakdown | `/plan` |
| Design and plan done, implement now | `/dev` or `/flow` |
| Implementation done, retain knowledge | `/docs` |

## Skip judgment

- **PRD not needed**: 1-file / dozens-of-lines edits, bug fixes → skip `/prd`, go to `/dev`
- **Design Doc not needed**: Feature addition within a single service → go directly to `/plan`
- **Plan not needed**: Design is simple enough to implement with `/dev` in one pass

## Q1-Q5 inheritance

"1.5 decision rationale (Q1-Q5)" confirmed in `/prd` is **transcribed without re-evaluation** in `/design-doc --prd <path>`. Append only Qs whose premise changes due to design.

## /plan vs /design-doc boundary

| Aspect | `/design-doc` | `/plan` |
|------|--------------|---------|
| Primary purpose | Communicate **design decisions** to the team | Determine **phase breakdown** for implementation |
| Output | 12-section md (Why / comparison / failure cases / migration strategy) | Phase 1/2/... and worktree requirement |
| Input | PRD or natural language | Design Doc or pre-designed premise |
| Audience | Reviewers / PM / future self | Implementers (self or developer-agent) |
| Related agent | None (direct Edit) | PO Agent (for complex cases) |

Both needed for large features. Small changes: `/plan` alone is usually sufficient.

## Related

- `../guidelines/writing/design-doc-protocol.md` — DesignDoc 4 steps + 10 patterns + anti-patterns + template selection + self-check 18
- `design-doc-template.md` — Full 12-section template
- `document-iteration-patterns.md` — Phase progression and revision patterns for rewrites (dynamic supplement)
- `_archive/prd-review-checkpoints.md` — Review checkpoints for human focus in PRD review (archived)
- `decision-quality-checklist.md` — 5-question decision quality check
- `performance-issue-template.md` — Performance improvement issue: measure → analyze → staged improvement → load test
- `review-patterns-universal.md` — Common review findings for design decisions and SQL dialects
