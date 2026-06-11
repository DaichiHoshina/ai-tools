---
allowed-tools: Read, Glob, Grep, Edit, MultiEdit, Write, Bash, Task, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*, mcp__context7__*
description: Default = developer-agent 委譲 (Sonnet)。inline は 1 symbol 修正のみ。--inline で強制 inline、--quick で短文 prompt、Team は /flow
---

## /dev - Implementation mode

> When to use: `/dev` = impl phase only, no Agent Team / `/flow` = auto task-type + PO→Manager→Dev×N hierarchy. When uncertain → `/flow`.
> Agent Team **only via `/flow`**. Direct `/dev` has no Team hierarchy.

## Default delegation

`/dev` 起動時、デフォルトで `Task(developer-agent)` 自動委譲 (Sonnet 実行)。

| Flag | 動作 |
|---|---|
| (none) | `developer-agent` 委譲 (default) |
| `--inline` | parent inline 実行 (1 symbol 修正のみ許可) |
| `--quick` | sonnet 委譲、token 節約優先 (短文 prompt) |
| `--team` | `/flow` 推奨、本 command では非対応 |

## Options

```bash
/dev --quick <task>      # Fast mode (token 節約、1-2 files)
/dev --parallel <task>   # Worktree parallel (no PO/Manager, developer-agent ×N 並列)
/dev <task>              # Normal (developer-agent 委譲、sonnet)
# Team hierarchy + parallel needed? Use /flow --parallel
```

## --parallel spec

Launch Developer×N worktree parallel w/o PO/Manager. Formula detail: `references/PARALLEL-PATTERNS.md`.

| Item | Action |
|------|------|
| Parallelism degree eval | Forced |
| worktree proposal | Forced |
| worktree creation | User confirm required |

### `--parallel --auto` skip conditions

詳細: `references/PARALLEL-PATTERNS.md` `### /dev --parallel --auto skip-confirmation 4 conditions` 参照。概要: formula PASS + clean worktree + no branch/worktree collision + creation fail → downgrade。

### worktree cleanup

詳細: `references/PARALLEL-PATTERNS.md` `### Cleanup policy (common)` 参照。概要: Changes present → return branch + merge + delete / no changes → auto-delete / collision → sequential downgrade + leave in place。

## --quick (formerly /quick-fix)

Use: 1-2 files typo / small bug / few-line change. **token 節約優先 (短文 prompt)、no Agent Team, minimal confirm**.

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
| `--quick` unexpected error | fallback sonnet, continue minor fixes |
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
