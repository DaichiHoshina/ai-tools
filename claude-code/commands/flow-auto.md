---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Task, Skill, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*
description: Fully autonomous workflow — shortcut for /flow --auto. No questions, skip approvals, auto-push.
argument-hint: "[task description]"
---

## /flow-auto - `/flow --auto` shortcut

Run `/flow --auto`. See `/flow` `--auto` section for behavior details.

**Self-Review 3 gates are mandatory** (A: parallel-judgment / B: parallel-implementation / C: 12-perspective split review). Canonical: `references/parallel-self-review.md` (the `/flow` `## Self-Review` section is a summary). Gate C (`--multi-review` 12-perspective parallel) is auto-ON in `--auto` mode.

**`--auto` skips confirmations / approvals / push prompts ONLY. It does NOT skip the hierarchy.** The `Task(po-agent)` → `Task(manager-agent)` → `Task(developer-agent)×N` chain is mandatory and cannot be skipped — autonomous means "no questions asked", not "no PO/Manager". Going straight to `developer-agent` (or inline implementation) without PO design judgment + Manager allocation is a spec violation. Only `--sequential` downgrades to single `/dev` (PO/Manager still run per `/flow` L41).

ARGUMENTS: $ARGUMENTS
