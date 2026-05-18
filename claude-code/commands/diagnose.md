---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*, mcp__context7__*
description: Debug support — error log analysis, root-cause identification, fix suggestions
---

## /diagnose - Debug support

## Flow

1. **Info collection** — error logs, stack traces, repro steps
2. **Serena analysis** — pinpoint error, trace dependencies, analyze data flow
3. **Root cause** — identify underlying cause, not just symptom
4. **Fix suggestions** — multiple options w/ priority
5. **Implement** (post-approval) — apply fix, confirm tests

## Error type approaches

| Type | Check |
|------|-------|
| Type error | type defs, any/as usage, type guards |
| Runtime | null/undefined, boundary values, data validation |
| Logic | conditionals, data flow, expected vs actual |
| Performance | bottlenecks, N+1, memory leaks |
| Docker | apply `docker-troubleshoot` + `dockerfile-best-practices` |

## Docker error detection

For Docker-related errors, apply:

1. **docker-troubleshoot** — lima/Docker Desktop connection, daemon status diagnosis & recovery
2. **dockerfile-best-practices** — Dockerfile improvements (multi-stage, cache optimization, security hardening)

## Output format

Normal case:

```
🐛 Error: [error summary]
📍 Location: [file:line]
🔍 Root Cause: [root cause]
🔧 Solution: [recommended fix]
```

Root cause unidentified (insufficient info):

```
🐛 Error: [error summary]
📍 Location: unknown (missing stack trace / logs unavailable)
🔍 Root Cause: unidentified (candidates A / B / C)
🔧 Next Action:
  - request info: full stack trace / repro steps / env details
  - isolate: A → check log X / B → check config Y
```

## Fallback behavior

| Scenario | Action |
|----------|--------|
| repro steps unavailable | request specific steps from user & stop (no guessing) |
| Serena fails | degrade to grep/Read, warn on dependency tracking |
| multiple fix candidates, unclear priority | sort by risk low→high, ask user to choose |

## Long-form report writing (for Notion/md)

Apply `guidelines/writing/long-form-doc.md` principles:

- open w/ 1-3 sentence conclusion ("X is the cause. Fixed by Y / proposed solution Z")
- "required"/"recommended"/"critical" → add 1-line rationale
- replace vague terms ("significantly improved", "optimized") w/ numbers ("5xx: 120/day → 8/day")
- close w/ explicit next action for reviewer/on-call

## Next actions

- root cause identified → `/dev` to fix
- fix complete → `/test` to verify
- more investigation needed → list research items

Use Serena MCP for code analysis. User approval required before fix.
