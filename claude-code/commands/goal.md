---
allowed-tools: Task, Bash, Read, Edit, Write, AskUserQuestion, TaskCreate, TaskUpdate, TaskList
argument-hint: "[--check <cmd>] [--max-iter N] [--timeout DUR] \"<stop-condition>\" <task>"
description: Run agent until objective stop-condition holds, with maker-checker separation (Ralph Wiggum loop guard).
---

## /goal - Objective stop-condition loop

**Core**: Shifts focus from prompt quality to loop design — the agent iterates until an objective gate (test/lint/build exit code) passes, not until it *thinks* it's done. Maker and checker run as separate agents to prevent the Ralph Wiggum failure mode (self-evaluation on partial output declares done, burning tokens on a quiet fail; documented by Geoffrey Huntley). Orthogonal to `/workflow` (deterministic fan-out) and `/flow` (PO/Manager/Dev hierarchy).

## Syntax

```
/goal "<stop-condition>" <task>
/goal --check "<cmd>" <task>
/goal --max-iter <n> --timeout <duration> "<stop-condition>" <task>
```

**Examples**:
```
/goal "all tests in tests/auth pass and lint clean" Fix auth failures in src/auth/middleware.ts
/goal "build succeeds with zero TS errors" Resolve type errors in apps/web/
/goal "bats tests/integration/ pass" Fix the failing hook tests
/goal --check "bats tests/ && npm run lint" "exit 0" Harden hook edge cases
```

## 4-condition pre-check (required)

Evaluate all 4 before starting. Any `✗` → abort with reason.

| # | Condition | Pass |
|---|-----------|------|
| 1 | Task is repetitive / iterative (not one-shot) | ✓ / ✗ |
| 2 | Stop-condition is fully automated (exit code, not human judgment) | ✓ / ✗ |
| 3 | Token budget absorbs N iterations of waste | ✓ / ✗ |
| 4 | Agent has senior tools (Bash, Edit, Task, file access) | ✓ / ✗ |

## Execution flow

1. **Parse stop-condition** — extract test/build/lint command from natural language, or use `--check <cmd>` directly.

2. **Maker iteration** — `Task(developer-agent)` executes one implementation pass (Sonnet). Scoped to `task.files`; no scope creep.

3. **Checker iteration** — Separate `Task` runs the **objective gate via Bash** (exit code is the sole verdict). Default checker: `reviewer-agent`. Override with `--checker silent-failure-hunter` or any registered agent. **Checker must not see maker's reasoning** (prevents self-preferential bias).

4. **Gate result**:
   - Exit 0 → done; write state file; report.
   - Exit non-0 → update state file with failure diff; increment iteration; go to step 2.

## Hard stops (required)

All three limits are enforced independently. First hit wins.

| Limit | Flag | Default |
|-------|------|---------|
| Max iterations | `--max-iter <n>` | 5 |
| Max tokens | `--max-token <n>` | 100000 |
| Wall-clock timeout | `--timeout <duration>` | 30m |

Rate limits and user interrupts are **not** hard stops — they are external signals requiring explicit restart.

## State file

Path: `~/.claude/loops/<name>-state.md` (override with `--state <path>`).

Written after every iteration:

```
## <task-name> loop state
Last run: <ISO datetime>
In progress: iteration <n> / <max>
Stop condition: <verbatim condition string>
Stop conditions met since last review: <list or none>
Lessons learned: <diff summary from last checker>
Escalated: <yes/no + reason>
Completed: <yes/no>
```

## Forbidden patterns

| Pattern | Why forbidden |
|---------|---------------|
| Subjective verifier ("does this look correct?") | No exit code → loop never terminates on objective evidence |
| Maker and checker are the same agent type | Self-preferential bias; Ralph Wiggum failure mode |
| No hard stop configured | Loop exits only on rate limit or user interrupt |

## Cadence (out of scope)

Single-invocation only. Recurring / scheduled execution is user-managed via cron (see `scripts/install-hook-bench-cron.sh` as pattern reference). Cadence integration is planned in `commands/loop.md` (`/loop`) — see `references/boris-style-mapping.md` "未取り込み" list.

## Related

- `references/loop-engineering.md` — 14-step canonical; why-and-test / building-blocks / failure-modes
- `commands/workflow.md` — `/workflow` deterministic fan-out (orthogonal)
- `commands/flow.md` — `/flow` PO/Manager/Dev hierarchy. `/flow --until-gate-green "<cmd>"` switches step 9 P0 loop to the same objective-gate semantics as `/goal`
- `references/boris-style-mapping.md` — Boris Cherny best-practice mapping table
