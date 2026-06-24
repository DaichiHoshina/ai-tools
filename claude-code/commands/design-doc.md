---
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, AskUserQuestion, mcp__serena__*
description: Team-shared design doc — PRD → design spec, md format, local storage
---

# /design-doc - Team-shared design doc

Transform requirements from `/prd` into shared technical design doc (md) for implementers, reviewers, PMs.

**Position**: `/prd` (requirements) → `/design-doc` (design) → `/dev` (implementation) → `/docs` (Notion archive post-completion)

> Full flow detail: `references/design-phase-flow.md`

## Design philosophy

> Good Design Doc makes **decision-making transparent**, not "clever design."

Detailed principles, template, type-specific apply: see `references/design-doc-template.md`. Key points:

- **Why required**: explicit PRD connection
- **Comparison & tradeoffs**: design = choice, not answer. Compare 2+ options
- **Changeability**: ask "how easy to modify" not "works now"
- **Responsibility boundaries**: clarify roles across service/module
- **Failure modes**: list prod-breaking points, not just happy path
- **Migration strategy**: DB changes need Expand → Migrate → Contract 3-phase

Write with substance: numbers (O(n)→O(1)), diagrams (Mermaid), constraints (MySQL 8.0 etc).

## Input interpretation (auto-branch from ARGUMENTS)

Beyond explicit options (`--prd` `--update` `--out` `--type` `--dry` `--scope`), infer mode from natural language.

| Detection | Condition | Effect |
|------|------|------|
| update mode | "fix/correct/update/upgrade/rewrite/revision/change" + `.md` path | `--update <path>` equivalent |
| scope limit | Search Q keyword dict (table below) in ARGUMENTS | Re-evaluate only target Q at Step 4・6 |
| derive mode | "from PRD ~" / "based on ~" + PRD `.md` path | `--prd <path>` equivalent |
| new mode | None above | Normal flow (from Step 1) |

**Q keyword dict** (shared w/ `/prd`): Q1=goal/Why, Q2=out-of-scope/Null, Q3=tradeoff/comparison, Q4=failure/premortem, Q5=assumption/break/if

**Ambiguous**:
- fix keyword present, path absent → `Glob "**/design/*.md"` `**/docs/design/*.md"` propose candidates + AskUserQuestion
- path present, fix keyword absent → AskUserQuestion "reference as PRD (`--prd`) / update Design Doc (`--update`) / new"

Step 4 on update mode: **Read existing Q1-Q5 sections → Edit diffs only**. With `--scope` specified, rewrite loop for target Q only.

## Q1-Q5 inheritance rules (avoid `/prd` duplication)

If Q1-Q5 already settled in `/prd`, Design Doc **inherits without re-evaluation**.

| Launch pattern | Q1-Q5 handling |
|----------------|---|
| `/design-doc --prd <path>` | Read PRD "1.5 decision rationale" → **transcribe, skip re-eval**. Append only if design changes premises |
| `/design-doc` (no PRD, new) | conduct Q1-Q5 at Step 4 (mandatory section) |
| `/design-doc --update <path>` | Read existing doc Q1-Q5 → edit diffs only |
| explicit `--scope Q1,Q3` | override inheritance, re-eval only specified Q |

**Inheritance note**: Mark "1.5 decision rationale" section `Source: <PRD path>`, inline-append only Q needing re-eval. Step 6 quality gate trusts inherited source, confirms transcription only.

## Flow

| Step | Action |
|------|------|
| 1. Input identify | Priority: `--prd <path>` / if arg → topic / else → `git log/diff` + AskUserQuestion |
| 2. Load guidelines | `guidelines/design/clean-architecture.md`, `domain-driven-design.md`, `references/design-doc-template.md`, `references/decision-quality-checklist.md`, `guidelines/writing/long-form-doc.md` |
| 3. Analyze code | `mcp__serena__*` identify existing symbols & dependencies |
| 4. Generate draft | 12-section template (type-adjusted, per `references/design-doc-template.md`). Weave in **4 questions & 5 principles from `guidelines/writing/long-form-doc.md` at generation time**. **For Q1-Q5 handling, see "Q1-Q5 inheritance rules" below** |
| 5. Confirm design decisions | AskUserQuestion on option adoption / migration boundary / open items (3-5 questions) |
| 6. Quality gate | Type-specific required items, **Q1-Q5 sufficiency check** (on inherit, verify transcription; on re-eval, Critical on NG pattern), supplement w/ questions or `Edit` rewrite (max 2 loops) |
| 7. Interactive rewrite | Per `guidelines/writing/long-form-doc.md` (≤9 items total, Layer 2 answers weave as-is) |
| 8. Write file | `--out` > `docs/design/` > `design/` > current, `YYYY-MM-DD_<slug>.md`. On `--dry`, don't write; treat as stdin downstream |
| 8.5. **writing check (file target)** | `Read` output md to extract content. Count violations vs NG dict from `guidelines/writing/long-form-doc.md` + writing axis NG table from `skills/comprehensive-review/SKILL.md`. Critical ≥1 or Warning ≥4 → rewrite w/ `Edit`, max 2 loops. Output final result to user |
| 9. Notion intake notice | After completion, guide `/docs --from <path>` if needed |

## Design types

| Type | Keywords | Emphasis |
|--------|-----------|------|
| feature (default) | feature, add | all 12 sections |
| refactor | refactor, improve | thick on 3/5/6/7/9 |
| arch | arch, structure, foundation | thick on 4/6/7/11 |
| adr | adr, decision | center on 3/6/7, skip 5/9/11 optional |
| db-migration | migration, DB change | thick on 5.1/9/10 |
| requirements | requirements, why, goal | center on 1/2/3/12, skip 5-11 |
| basic | basic design, architecture | center on 4/6/7/11, skip 5/8/9 |
| detailed | detailed design, data model, sequence | center on 5/8/9, skip 2/3/4/6/7 |

Type-specific section detail & quality gate apply conditions: `references/design-doc-template.md`.

## Options

| Option | Description |
|-----------|------|
| `--prd <path>` | Derive design from existing PRD md |
| `--out <path>` | Output directory |
| `--type <feature\|refactor\|arch\|adr\|db-migration\|requirements\|basic\|detailed>` | Template scope adjust (phase split: requirements→basic→detailed) |
| `--update <path>` | Update existing md (Read existing Q1-Q5 → Edit diffs only) |
| `--scope Q1,Q3` | Re-evaluate specified Q only from Q1-Q5 (partial fix, auto-infer from natural language) |
| `--dry` | Preview only, no file write |

## Writing quality assurance (guideline ref + post-write review)

At draft generation, reference principles from `guidelines/writing/long-form-doc.md` (4 questions・conclusion-first・evidence-cited・hard-word-defined・abstract-word-free・prose-bridge).

**Post-write review (Step 8.5)**: After file write, `Read` content and count hits vs NG table from `skills/comprehensive-review/SKILL.md` writing axis (unjustified evaluative words・abstract-word-left-hanging・hard-word-undefined etc.) + NG dict from `guidelines/writing/long-form-doc.md`. Since `/review --focus=writing` is git-diff based, for stable checking of newly-written files, **use Read + AI self-judgment**.

- Critical ≥1, or Warning ≥4 → rewrite w/ `Edit`, re-check (max 2 loops)
- On `--dry` mode, don't write; check generated draft text directly w/ same checks

Writing Context comment block at top is optional (not forced).

## Common guards

- Secret-free (per `~/.claude/rules/enterprise-security.md`)
- Code examples ≤5 lines
- 1 H1 per file (`~/.claude/rules/markdown.md`)
- Mermaid in ``` mermaid code block

## Bad Design Doc

Looks clever but unclear intent / no Why / no comparison / no migration / no failure mode → unreviewable, all bad.

ARGUMENTS: $ARGUMENTS
