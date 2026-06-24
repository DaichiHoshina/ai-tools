---
allowed-tools: Read, Glob, Grep, Bash, WebFetch, WebSearch, AskUserQuestion, Task, mcp__serena__*, mcp__context7__*, mcp__confluence__*, mcp__jira__*
description: Create PRD - interactive requirements gathering, optional mathematical formalization, strict expert review from 11 angles
---

# /prd - Requirements Definition & PRD Creation

Organize complex requirements and detect gaps from multiple expert perspectives.

> Full flow (brainstorm → prd → design-doc → plan → dev → docs): `references/design-phase-flow.md`

## Input Parsing (auto-branch from ARGUMENTS)

Infer mode from natural language beyond explicit options (`--update <path>` `--scope Q1,Q3`).

| Detection | Condition | Effect |
|-----------|-----------|--------|
| update mode | fix/update/rewrite keywords + `.md` path | `--update <path>` equivalent |
| scope limit | search keyword dict in ARGUMENTS | re-evaluate only target Q in Phase 1.7 |
| new mode | none of above | start from Phase 1 interview |

**Scope keyword dictionary**:

| Q | Keywords |
|---|----------|
| Q1 | purpose / true purpose / why / Why / XY problem |
| Q2 | don't build / build nothing / Null / opportunity cost |
| Q3 | alternatives / other options / OSS / SaaS / comparison / selection |
| Q4 | failure / premortem / risks / failure scenarios |
| Q5 | assumptions / break / assumption / if / vulnerability |

**When ambiguous**:
- fix keyword present, path absent → `Glob "**/*prd*.md"` show candidates, AskUserQuestion
- path present, fix keyword absent → AskUserQuestion confirm "new reference / existing update"

Update mode Phase 1.7: **Read existing 1.5 section → patch only gaps/stale content** (diff edit). With `--scope`, run only target Q.

## Execution Flow

### Phase 1: Information Gathering (interactive, required)

**Cannot skip even in auto mode. Always use AskUserQuestion.**

| Step | AskUserQuestion | Example choices |
|------|----------------|----------|
| 1 | What do you want to realize? | new feature / existing improvement / bug fix |
| 2 | Which services involved? | (auto-detect from codebase) |
| 3 | External APIs / dependencies? | yes / no / unclear |
| 4 | Primary users? | end user / admin / developer |
| 5 | Walk through main flow | (free text) |

### Phase 1.5: Mathematical Formalization (complex requirements)

AskUserQuestion → if "yes": glossary, entities, state transition table (state→event→next→guard→pre/post→invariants), operation composition, exceptions/boundary conditions, DDD mapping.

### Phase 1.7: Decision Quality Check (required, no skip)

Apply 5 questions from `references/decision-quality-checklist.md`. Ensure **goal-means consistency** before Phase 2 draft.

| Q | Question | Complement if missing |
|---|----------|------------|
| Q1 | True goal? (dig 2 levels) | AskUserQuestion confirm parent goal |
| Q2 | Include "build nothing" in comparison? | AI draft: do nothing / manual / existing alternative → user confirm |
| Q3 | Explored 3+ alternatives? | AI draft: 3 options from build/OSS/SaaS/redesign/ops workaround |
| Q4 | Three premortems written? | AI draft: 1 each from tech/ops/unexpected usage |
| Q5 | Conditions where assumptions break? | AI candidate: user count / auth / external API / compliance |

Each output baked into Phase 2 PRD **"1.5 Decision Rationale"** section (see template). If any pattern matches NG list, escalate Critical + re-ask.

### Phase 2: Auto-generate PRD

Overview, user stories, service dependencies (Mermaid), external API spec, state transitions, acceptance criteria. Reference `guidelines/writing/long-form-doc.md` 4-question principle for prose quality.

### Phase 3: Multi-angle Review (11 personas)

| ID | Check | ID | Check |
|----|---------|-----|---------|
| SEC | auth, encryption, injection | UX | error messages, wait UI |
| PERF | N+1, bottlenecks, caching | DATA | history, audit log, consistency |
| SRE | SPOF, failure detection, rollback | BIZ | ROI, priority, MVP |
| QA | edge cases, boundary values | LEGAL | PII, retention |
| ARCH | dependencies, extensibility | EXT | fallback, retry |
| CUST | customer value, WTP, journey, vs alternatives | — | — |

CUST = bridge between UX (usability) and BIZ (business ROI). "Will users really pay for this / switch from Excel/competitor/self-build?"

Review technique: MECE, state completeness, branch coverage, contradiction detection, counter-questions.

### Phase 4: Issue List

Critical (must fix) / Warning (recommended) / Info (consider)

### Phase 4.5: Self-review on writing (pre-output)

`/prd` is chat output, not persisted, so not in `/review` diff scope. AI self-checks draft before output against:

- `skills/comprehensive-review/SKILL.md` writing NG table (conclusion-first, unsupported praise, vague words, undefined jargon, omitted subject, missing 5W1H, repetitive bullets, AI boilerplate, unclear call-to-action)
- `guidelines/writing/long-form-doc.md` NG dictionary

1+ Critical or 4+ Warning hit → fix before Phase 5 (max 2 loop). Fix by embedding answers to 4 questions (reader, call-to-action, numbers, why) in prose.

**Exceed 2 loops**: report remaining violations as "Phase 5 user confirm items", stop auto-fix. Declare loop limit reason (info gap / decision pending) + ask user.

If PRD persisted via `--out <path>`, use `Read` + `Edit` rewrite loop like `/design-doc` Step 8.5.

## Failure Handling

| Situation | Behavior |
|-----------|----------|
| AskUserQuestion answer "unclear" / "pending" | defer to draft Open Questions, revisit later |
| external API spec fetch fail (WebFetch) | log "external API spec not retrieved" Critical, ask user for spec URL |
| Serena fail (service auto-detect) | ask user for explicit service, ban guessing |

### Phase 5: Fix & Approve

AskUserQuestion → fix or approve → `/design-doc` (team-shared design) or `/plan` or `/dev`

## Output Template

```markdown
# PRD: [Feature]
## 1. Overview (purpose/background/scope)
## 1.5 Decision Rationale (Q1-Q5: true goal / don't-build comparison / 3 alternatives / 3 premortems / assumption break conditions)
## 2. Users (target/stories/roles)
## 3. System (dependencies/data flow/external APIs)
## 4. Functional Req (state transitions/business rules)
## 4.5 Formalization (complex cases only)
## 5. Non-functional Req
## 6. Acceptance Criteria
## 7. Review Result
## 8. Next Steps
```

**Read-only**: no implementation. Fetch external APIs. Repeatable.

ARGUMENTS: $ARGUMENTS
