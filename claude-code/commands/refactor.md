---
allowed-tools: Read, Glob, Grep, Edit, MultiEdit, Write, Bash, Task, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*, mcp__context7__*
description: Refactoring mode (auto-load language guidelines)
---

## /refactor - Refactoring Mode

## protection-mode

Auto-apply via `/flow`. Single run: recommend `Skill("protection-mode")` if changing files.

## Think Mode (critical)

**always ultrathink** - deep reflection before refactoring. Understand existing intent, preserve behavior while improving.

## Step 0: Auto-load Guidelines (required)

Load required guidelines before refactoring:

### A. Language Guidelines
Auto-detect via `load-guidelines` skill:
- TypeScript → `typescript.md`, `eslint.md`
- Next.js → `nextjs-react.md`, `tailwind.md`, `shadcn.md`
- Go → `golang.md`

### B. Design Guidelines (required)
```
requires-guidelines:
  - clean-architecture
  - ddd
```

**Load from:**
- `~/.claude/guidelines/design/clean-architecture.md`
- `~/.claude/guidelines/design/domain-driven-design.md`

### C. Skill Coordination
Auto-load guidelines:
- `clean-architecture-ddd` - clean arch + DDD principles
- `comprehensive-review --focus=quality` - design/quality/type safety integrated check (Phase 2-5 built-in, legacy names also work)

## Flow

1. **Load guidelines** - execute Step 0 above
2. **Analyze** - Serena MCP identify quality issues, analyze impact scope
3. **Plan** - create refactoring plan via TaskCreate
4. **User confirm** (required)
5. **Execute** - refactor incrementally
6. **Test** - confirm behavior unchanged
7. **Report** - Before/After comparison

## Priority

1. **Type safety improvement** - eliminate any/as (highest)
2. **Guideline compliance**
3. **Architecture patterns** - Clean Architecture, DDD
4. **Eliminate duplication** - DRY principle
5. **Readability improvement**

## Output Format

```
# Refactoring: [target]

## Changes
- Files: X / +Y -Z lines

## Improvements
- ✅ removed X any types
- ✅ complexity Y → Z

## Test: [PASS/FAIL]
```

## Next Steps

```
/refactor complete
  → /lint-test (quality check, required)
  → /test (test execution, required. verify behavior unchanged)
  → /review (code review)
  → /git-push (git operations)
  → test fail: /diagnose
```

## Related Commands

| Command | Relation |
|---------|------|
| `/dev` | new feature implementation, different goal |
| `/tdd` | test-driven. equal to refactor Refactor phase |
| `/lint-test` | CI equivalent check, required after refactoring |

## Failure Handling

| Situation | Behavior |
|-----------|----------|
| Serena MCP fail | use grep/Glob for quality detection, reduce precision warning |
| guideline load fail | continue with common only, warning. be conservative on design decisions |
| no refactoring needed (zero quality issues) | report "no improvements, maintain status quo" → done |
| test fail (behavior change detected) | git stash changes, report cause → stop |

**Require user confirm before refactoring. Don't change behavior (test guarantees it).**
