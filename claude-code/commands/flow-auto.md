---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Task, Skill, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*
description: Fully autonomous workflow — shortcut for /flow --auto. No questions, skip approvals, auto-push.
---

## /flow-auto - `/flow --auto` shortcut

Run `/flow --auto`. See `/flow` `--auto` section for behavior details.

**`--auto` skips confirmations / approvals / push prompts ONLY. It does NOT skip the hierarchy.** The `Task(po-agent)` → `Task(manager-agent)` → `Task(developer-agent)×N` chain (`/flow` Execution logic steps 3-4) is mandatory and cannot be skipped — autonomous mode means "no questions asked", not "no PO/Manager". Going straight to `developer-agent` (or inline implementation) without PO design judgment + Manager allocation is a spec violation. Only `--sequential` downgrades to single `/dev` (and even then PO/Manager run per `/flow` L41).

ARGUMENTS: $ARGUMENTS
