---
allowed-tools: Workflow, Read, Glob, Grep, Bash, AskUserQuestion, TaskCreate, TaskUpdate, TaskList
description: Workflow tool で deterministic な fan-out / pipeline / 多数決を 1 発火する軽量 orchestrator
argument-hint: "[task description]"
---

## /workflow - Workflow-tool deterministic orchestration

**Core**: Lightweight command that directly invokes Claude Code native `Workflow` tool. Orthogonal to `/flow` (heavy orchestration with PO/Manager/Dev hierarchy + 3 Gates) — use for **deterministic fan-out / pipeline / majority-vote / loop-until-dry** in a single script.

> When to use: `/workflow` (short~medium, deterministic, resumable) / `/flow` (heavy orchestration with PO Gate / Manager) / `/dev` (single impl)

### /workflow vs /flow

| Axis | /workflow | /flow |
|------|-----------|-------|
| Use case | Structured fan-out (review / research / migrate) | PO→Manager→Dev hierarchy for feature impl |
| Gate | None (self-verify via script) | 3 Gates required (A/B/C) |
| Resume | Yes, via journal + prompt cache hit | No (each Agent fresh fire) |
| Token budget | Dynamic scale via `budget.remaining()` | Formula-based N_chosen |
| Best fit diff size | Small~medium (≤500 lines) | Medium~large, impl-primary |

Decision guidance:
- Review **only** in parallel → `/workflow review`
- Review **then auto-create PR** → `/flow --auto`
- Migrate N files via fan-out → `/workflow migrate`
- New feature (needs PO) → `/flow`

## Templates (5 types)

Each template passes script inline to `Workflow` tool. Arguments via `args`. Code examples: `references/workflow-templates.md`.

| # | Name | One-line algorithm |
|---|------|--------------------|
| 1 | review | dimensions → find → adversarially verify pipeline (per-finding fan-out) |
| 2 | migrate | discover sites → parallel transform (worktree isolation) → verify |
| 3 | research | parallel fan-out across angles → deep-read top hits → synthesize cited report |
| 4 | understand | parallel map N subsystems (entry / deps / data flow) → return structured |
| 5 | judge-panel | parallel N design drafts → judge-score → winner + graft runner-up ideas |

## Invocation spec

User input examples:
- `/workflow review` (target diff = git diff HEAD~1..HEAD, dimensions = default 3)
- `/workflow research <topic>` (args.topic = remaining args)
- `/workflow migrate <pattern> <replacement>` (args.pattern / args.replacement)

Parent (Opus) responsibilities:
1. Select template (match from 5 above)
2. Build `args` (pass user input as JSON value; no stringified arrays)
3. Fire `Workflow({ script: ..., args: ... })` once
4. On `<task-notification>`, summarize result to user in 1-3 prose lines

### Token budget

If user specifies `+500k` etc., use `budget.remaining()` for dynamic scale (e.g., loop termination condition). No spec → `budget.total = null`; static N in template (e.g., `SUBSYS.length`) acts as cap.

### Isolation decision

Use worktree isolation (`isolation: 'worktree'`) **only for parallel edits to the same file**. Read-only or separate-file writes do not need it (Workflow tool setup overhead 200-500ms/agent + disk cost)。`git worktree add` 単体は 90ms だが、Workflow tool は env init を含むため重い。`/flow --parallel` 系の wt 費用とは別計上する (canonical: `references/PARALLEL-PATTERNS.md` cost breakdown)。Default ON in `migrate` template only.

### Null-guard (silent-fail detection)

`agent()` は rate limit / user skip / terminal error で **null を返して黙って落ちる** (2026-07-10 の gate loop silent 停止で実害が出た)。script には次の 3 点を必須で入れる:

1. `.filter(Boolean)` で捨てる前に null 数を数え、`log()` で warn する (`WARN: <stage> dropped N/M agents`)
2. return に `dropped: <N>` を含める (parent が summary で user に報告する)
3. checker / verifier / gate 判定の null は **fail-closed**: accept と見なさず loop を abort して `aborted: true` を return する

Helper 実装と適用例: `references/workflow-templates.md` § 0 Null-guard helper。

## Constraints

- Default subagent_type is Workflow native subagent. Use `agentType: 'explore-agent'` etc. to specify ai-tools agents
- Barrier vs pipeline decision inside `Workflow` tool: follow "DEFAULT TO pipeline()" in [Workflow tool description]
- 1-message bundle constraint (`[[parallel-fire-format-peak-concurrency]]`) applies to `/flow` only; Workflow tool internal fan-out is a separate system (peak governed by tool-side cap)
- `nested workflow()` allowed 1 level only

ARGUMENTS: $ARGUMENTS
