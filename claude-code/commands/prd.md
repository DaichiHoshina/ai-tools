---
allowed-tools: Read, Glob, Grep, Bash, WebFetch, WebSearch, AskUserQuestion, Task, mcp__serena__*, mcp__context7__*, mcp__confluence__*, mcp__jira__*
description: Create PRD - interactive requirements gathering, optional mathematical formalization, strict expert review from 11 angles
argument-hint: "[topic]"
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

**Scope keyword dictionary**: Q1=purpose/why/XY problem, Q2=don't build/Null/opportunity cost, Q3=alternatives/OSS/SaaS/comparison, Q4=failure/premortem/risks, Q5=assumptions/break/vulnerability.

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

Q1-Q5 詳細と complement rule は `references/decision-quality-checklist.md` を canonical として参照する。goal-means consistency を Phase 2 draft 前に確認する。各 Q の output は Phase 2 PRD の **1.5 節** (template 参照) に書き込む。NG pattern にあたる場合は Critical を上げ、再度問い直す。

### Phase 2: Auto-generate PRD

Overview, user stories, service dependencies (Mermaid), external API spec, state transitions, acceptance criteria. Reference `guidelines/writing/long-form-doc.md` 冒頭 Writing Context 節 (4-question principle) のみ Read (全文 load 不要)。

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

writing check: `references/writing-check-protocol.md` 参照 (対象: PRD draft、`--out <path>` 時は書き出し file)。`/prd` は chat 出力で persist しない経路が default のため `/review` diff scope 外、canonical の loop を必ず走らせる。Loop 超過時の残存違反は "Phase 5 user confirm items" として停止し、loop limit reason (info gap / decision pending) と共に user に問う。

## Failure Handling

AskUserQuestion 回答が "unclear"/"pending" → draft Open Questions に退避し後で再検証 / external API spec fetch fail (WebFetch) → "external API spec not retrieved" を Critical で記録し spec URL を user に問う / Serena fail (service auto-detect) → service 名を明示で user に問い、推測は禁止する

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
