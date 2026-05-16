---
allowed-tools: Read, Glob, Grep, Edit, MultiEdit, Write, Bash, Task, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*, mcp__context7__*
description: Direct implementation — no Agent use, runs inline. --quick for haiku speed. Use /flow if Agent Team needed.
---

## /dev - Implementation mode

> When to use: `/dev` = impl phase only, no Agent Team / `/flow` = auto task-type + PO→Manager→Dev×N hierarchy. When uncertain → `/flow`.
> Agent Team **only via `/flow`**. Direct `/dev` has no Team hierarchy.

## Options

```bash
/dev --quick <task>      # Fast mode (haiku, 1-2 files)
/dev --parallel <task>   # Direct execution worktree parallel (no PO/Manager)
/dev <task>              # Normal (sonnet, direct execution)
# Team hierarchy + parallel needed? Use /flow --parallel
```

## --parallel spec

Launch Developer×N worktree parallel w/o PO/Manager. Formula detail: `references/PARALLEL-PATTERNS.md`.

| Item | Action |
|------|------|
| Parallelism degree eval | Forced |
| worktree proposal | Forced |
| worktree creation | User confirm required |

### `--parallel --auto` 3 skip conditions

1. Direct-exec formula PASS (`LPT_makespan + 21N + 20 < sum × 0.7`, first candidate `N=4 + T_task>58s` + independent 2 + fully isolated)
2. clean worktree
3. branch/worktree name no collision

worktree creation fail → downgrade to sequential (`N=1`, current branch), notify even on `--auto` (`> [WARN] worktree creation fail → sequential downgrade`).

### worktree cleanup

Changes present → return branch・parent merge・delete / no changes → auto-delete / collision → sequential downgrade・leave in place.

## --quick (formerly /quick-fix)

Use: 1-2 files typo / small bug / few-line change. **haiku use, no Agent Team, minimal confirm**.

Flow: identify file → fix (Serena MCP) → verify (lint/type) → propose commit.

3+ files / design decision needed → normal `/dev` or `/flow`.

## Thinking mode

**Always ultrathink** — for complex impl, think deep before execute. Avoid quick fixes; understand design intent before coding.

## Step 0: Guideline loading (conditional)

| Scenario | Action |
|----------|--------|
| `--quick` | skip (save tokens) |
| 1-2 files, minor | skip OK (if pattern known) |
| new feature, design decision | `load-guidelines` (summary recommended) |
| UI dev | `ui-skills` recommended |
| Backend | `backend-dev` recommended |

```
/load-guidelines        # summary only (~2.5K tokens)
/load-guidelines full   # w/ detail (~5.5K tokens)
```

Detailed mapping: `references/command-resource-map.md`.

## Execution flow

1. Load guidelines
2. Analyze code w/ Serena MCP
3. Plan w/ TaskCreate
4. Confirm w/ user
5. Implement
6. Run lint/test

## Priority

1. Type-safety (any/as forbidden)
2. Guideline compliance
3. Architecture patterns
4. Testability

## Post-impl quality checks (required)

After completion: `/lint-test` auto-detects lang + runs all checks (lint/typecheck/test/build). 0 errors → report done, else → try auto-fix.

| Scenario | Action |
|----------|--------|
| 2 consecutive same-approach failures | suggest `/clear` & stop, request replan |
| `--quick` can't use haiku | fallback sonnet, continue minor fixes |
| Serena MCP fails | degrade to grep/Read, warn |

PushNotification: notify only if task > 3min (`[dev] {task} done`).

## Next actions

```
/dev done
  → /lint-test → /test → /review → /git-push
  → on error: /diagnose
```

## Related commands

| Command | Relation |
|---------|----------|
| `/refactor` | structure improvement w/o behavior change. Can run after `/dev` |
| `/tdd` | test-driven. Test-first variant of `/dev` |
| `/lint-test` | CI-equivalent checks. Recommended after `/dev` |

**Pre-impl user confirmation required. Use Serena MCP for code ops.**
