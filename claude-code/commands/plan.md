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
  → draft design document
  → **Self-Review (必須、2 段階)** (→ `## Self-Review` section 参照)
  → output filtered design document
  → propose next actions (to `/dev`)
```

## Direct execution flow

1. Load guidelines (Step 0)
2. Analyze codebase w/ Serena MCP
3. Draft design document
4. **Apply Self-Review 2-stage gate** (→ `## Self-Review` section 参照)
5. Output filtered design document + propose implementation plan for `/dev`

## Self-Review (必須、2 段階)

`/plan` 出力前に **必ず** 2 段階のセルフレビューを通す。skip 不可、PO Agent 経由 / Direct execution / `--update` / `--scope` 全モードで一律実行。Stage 共通定義: `commands/review.md` `## Self-Review (必須、2 段階)` 参照。noise discard 方針: `rules/review-noise-discard.md` 参照。

### Stage A: plan 固有 filter

Investigation discard: speculative leads / hypothetical edge cases / findings unrelated to the change。
Plan discard: compat shims / future abstractions / impossible-case error handling / non-boundary validation / scope creep / premature optimization / half-finished phases。

### Stage B: plan 固有 集合観点

Phase 統合 (同一 root cause → 1 Phase) / 粒度整合 / convention 整合 / Zero-phase valid (padding 禁止)。判断 log は plan file に含めない。両 stage 通過した結果のみ Output Format に進む。

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
