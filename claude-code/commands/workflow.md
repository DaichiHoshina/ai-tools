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

Each template passes script inline to `Workflow` tool. Arguments via `args`.

### 1. review (canonical example, official best practice)

dimensions → find → adversarially verify pipeline. pipeline default (no barrier); verify fires per finding.

```javascript
export const meta = {
  name: 'review-changes',
  description: 'Review changed files across dimensions, verify each finding',
  phases: [{ title: 'Review' }, { title: 'Verify' }],
}
const DIMS = [
  { key: 'bugs', prompt: '...' },
  { key: 'perf', prompt: '...' },
  { key: 'security', prompt: '...' },
]
const results = await pipeline(DIMS,
  d => agent(d.prompt, { phase: 'Review', schema: FINDINGS_SCHEMA }),
  rev => parallel(rev.findings.map(f => () =>
    agent(`Adversarially verify: ${f.title}`, { phase: 'Verify', schema: VERDICT_SCHEMA })
      .then(v => ({ ...f, verdict: v }))
  ))
)
return { confirmed: results.flat().filter(Boolean).filter(f => f.verdict?.isReal) }
```

### 2. migrate (worktree isolation required)

discover sites → transform each → verify. Parallel edits to same file require worktree isolation to prevent conflicts.

```javascript
phase('Discover')
const sites = await agent('Find all <pattern> usage sites', { schema: SITES_SCHEMA })
phase('Transform')
const fixed = await parallel(sites.items.map(s => () =>
  agent(`Migrate ${s.file}:${s.line} from X to Y`, { isolation: 'worktree' })
))
return { migrated: fixed.filter(Boolean).length }
```

### 3. research (multi-modal sweep)

Parallel fan-out across different search angles → deep-read → synthesize. Covers failure modes missed in a single sweep.

```javascript
const ANGLES = ['by-container', 'by-content', 'by-entity', 'by-time']
const hits = (await parallel(ANGLES.map(a => () =>
  agent(`Search ${args.topic} via ${a}`, { schema: HITS_SCHEMA })))).filter(Boolean)
const deep = await parallel(hits.flatMap(h => h.urls.slice(0, 3)).map(u => () =>
  agent(`Deep read: ${u}`, { schema: SUMMARY_SCHEMA })))
return await agent(`Synthesize cited report from: ${JSON.stringify(deep)}`, { schema: REPORT_SCHEMA })
```

### 4. understand (subsystem map)

Read multiple subsystems in parallel to get a structured map. Lighter codebase comprehension than `/flow`.

```javascript
const SUBSYS = ['auth', 'api', 'db', 'ui']
const maps = await parallel(SUBSYS.map(s => () =>
  agent(`Map ${s} subsystem: entry points / dependencies / data flow`, { schema: MAP_SCHEMA })))
return { systems: maps.filter(Boolean) }
```

### 5. judge-panel (N independent approaches + majority vote)

Generate 3-5 design approaches independently → judge agent scoring → adopt winner + graft best runner-up ideas.

```javascript
const ANGLES = ['MVP-first', 'risk-first', 'user-first']
const drafts = await parallel(ANGLES.map(a => () =>
  agent(`Design ${args.feature} from ${a} angle`, { schema: DESIGN_SCHEMA })))
const scored = await parallel(drafts.filter(Boolean).map(d => () =>
  agent(`Score this design: ${JSON.stringify(d)}`, { schema: SCORE_SCHEMA })))
const winner = scored.reduce((a, b) => a.score > b.score ? a : b)
return await agent(`Synthesize final from winner + graft top runner-up ideas: ${JSON.stringify(scored)}`,
  { schema: FINAL_SCHEMA })
```

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

Use worktree isolation (`isolation: 'worktree'`) **only for parallel edits to the same file**. Read-only or separate-file writes do not need it (Workflow tool setup overhead 200-500ms/agent + disk cost; `git worktree add` 単体は 90ms だが Workflow tool は env init を含むため重い。`/flow --parallel` 系の wt 費用とは別計上、canonical: `references/PARALLEL-PATTERNS.md` cost breakdown)。Default ON in `migrate` template only.

## Constraints

- Default subagent_type is Workflow native subagent. Use `agentType: 'explore-agent'` etc. to specify ai-tools agents
- Barrier vs pipeline decision inside `Workflow` tool: follow "DEFAULT TO pipeline()" in [Workflow tool description]
- 1-message bundle constraint (`[[parallel-fire-format-peak-concurrency]]`) applies to `/flow` only; Workflow tool internal fan-out is a separate system (peak governed by tool-side cap)
- `nested workflow()` allowed 1 level only

ARGUMENTS: $ARGUMENTS
