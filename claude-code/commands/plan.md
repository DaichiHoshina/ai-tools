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
  → **Self-Review (必須、2 段階)** — Stage A: per-item Filter Gate / Stage B: Result-wide Pass
  → output filtered design document
  → propose next actions (to `/dev`)
```

## Direct execution flow

1. Load guidelines (Step 0)
2. Analyze codebase w/ Serena MCP
3. Draft design document
4. **Apply Self-Review 2-stage gate** to investigation findings and draft plan — Stage A (per-item discard) + Stage B (集合観点) を出力前に必ず通す
5. Output filtered design document + propose implementation plan for `/dev`

## Self-Review (必須、2 段階)

`/plan` 出力前に **必ず** 以下 2 段階のセルフレビューを実行する。skip 不可、PO Agent 経由 / Direct execution / `--update` / `--scope` 全モードで一律実行。Stage A 通過後に Stage B を通し、両 stage 通過した item のみが Output Format に進む。

### Stage A: Per-item Filter Gate (moderate strictness)

investigation findings (Phase 1) と draft plan (Phase 4) の各 item を個別に評価し discard 判定する。

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

### Stage B: Result-wide Pass (集合観点)

Stage A 通過後の plan 全体を **集合として** もう一度見直す。以下 4 観点:

1. **Phase 統合 / 重複削除**: 同一 file / 同一 layer / 同一 root cause を複数 Phase が別 item として持っていないか? 統合して 1 Phase に。
2. **粒度整合**: Phase 間で粒度がバラついていないか? (例: Phase 1 = 1 symbol 修正 vs Phase 2 = module 全体 refactor の混在) → 粒度を揃えるか、説明で正当化。
3. **Project convention 整合**: CLAUDE.md / guidelines / 既存コード規約・既存パターンと矛盾しないか? 規約外の独自設計は破棄 or 規約準拠に修正。
4. **Zero-phase 判定**: 結果として 0 Phase plan は valid 出力 (Stage A で全 item discard された場合)。padding (無理に何か出す) 禁止、その旨を明示して終わる。

Stage B の判断 log は plan file に含めない (verdict が変わった場合のみ反映)。zero-phase 含め、両 stage を通過した結果のみが Output Format に進む。

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
