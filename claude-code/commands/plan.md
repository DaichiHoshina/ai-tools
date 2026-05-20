---
allowed-tools: Read, Glob, Grep, Bash, Task, AskUserQuestion, mcp__serena__*, mcp__context7__*
description: Design & planning — strategy formulation via PO Agent (read-only)
---

## /plan - Design & planning mode

## Boundary w/ `/design-doc`

| Aspect | `/design-doc` | `/plan` |
|--------|--------------|---------|
| Primary goal | communicate **design decisions** to team | decide impl **phase breakdown** |
| Output | 12-section md (Why/comparison/failure/migration) | Phase 1/2/... + worktree needed? |
| Input | PRD or natural language | Design Doc or settled design |
| Agent | none (direct Edit) | PO Agent (for complexity) |

Large feature: both (design-doc → plan). Small fix: plan only. Detail: `references/design-phase-flow.md`.

## Step 0: Auto-load guidelines (required)

### A. Design guidelines (required)

- `~/.claude/guidelines/design/clean-architecture.md`
- `~/.claude/guidelines/design/domain-driven-design.md`

### B. Language guidelines (auto-detect via `load-guidelines`)

TypeScript → `typescript.md`, `eslint.md` / Next.js → `nextjs-react.md`, `tailwind.md`, `shadcn.md` / Go → `golang.md`.

### C. Project type

Infrastructure → `infrastructure/terraform.md`, `infrastructure/aws-eks.md`.

### D. Skill coordination

`clean-architecture-ddd` / `api-design` / `microservices-monorepo` (on detect) auto-load guidelines. Detail: `references/command-resource-map.md`.

## Agent use judgment

| Type | Target |
|------|------|
| PO Agent use | New feature design / architecture decision / multi-component / worktree needed |
| Direct execution | Single file fix / small improvement |

## PO Agent flow

```
Launch Task(subagent_type: "po-agent")
  → requirement analysis → architecture design → worktree necessary? (confirm) → implementation approach
  → output design document
  → propose next actions (to `/dev`)
```

## Direct execution flow

1. Load guidelines (Step 0)
2. Analyze codebase w/ Serena MCP
3. Create design document
4. Propose implementation plan for `/dev`

## Self-Filter Gate (moderate strictness, required before finalizing)

Apply moderate strictness discard criteria to both investigation findings (Phase 1) and the draft plan (Phase 4) before output.

**Investigation filter** (discard from carry-forward):

- Speculative "could be relevant" leads not anchored to user request or observed code
- Hypothetical edge cases not in scope of the user's stated task
- Findings about existing code unrelated to the requested change

**Plan filter** (discard from draft):

- Backwards-compat shims / migration paths the user did not ask for
- Abstractions designed for hypothetical future use ("might need a strategy interface later")
- Error handling for cases that cannot happen given the system boundary
- Validation at non-boundary points (trust internal contracts)
- Scope creep beyond the stated request (cleanup, refactors, "while we're at it")
- Premature optimization without measured baseline
- Half-finished phases ("Phase 3: explore other approaches")

If the plan loses size after filter, that is healthy — ship the smaller version. Zero-step plans are valid when the request truly resolves to a single edit.

## Plan storage

Stored in `plansDirectory` (default `~/.claude/plans`).

```
~/.claude/plans/YYYY-MM-DD_[project]_[feature].md
```

Reference across sessions, load w/ `/reload`.

## Output format

```
# Design: [feature name]

## Requirements
- [ ] requirement 1

## Architecture
- Pattern: [selection reason]
- Structure: [directory structure]

## Implementation plan
Phase 1: [task]
Phase 2: [task]

## Worktree
- Needed: Yes/No
- Branch name: [propose]
```

## Priority

1. Requirement clarity
2. Architecture fit
3. Extensibility・maintainability
4. Testability

## Fail behavior

| Scenario | Action |
|------|------|
| PO Agent launch fail | Downgrade to direct, warn. Complex tasks propose requirement split |
| Guideline load fail | Continue w/ common only, design decision on maintainer |
| Serena MCP fail | Substitute w/ grep/Glob, warn precision drop |
| `plansDirectory` write fail | Chat output only, guide manual save |

**Read-only** - Implementation via `/dev`.
