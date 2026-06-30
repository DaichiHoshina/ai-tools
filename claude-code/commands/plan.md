---
allowed-tools: Read, Glob, Grep, Bash, Task, AskUserQuestion, mcp__serena__*, mcp__context7__*
argument-hint: "<task-or-scope>"
description: Design & planning — strategy formulation via PO Agent (read-only)
---

## Boundary w/ `/design-doc`

| Aspect | `/design-doc` | `/plan` |
|--------|--------------|---------|
| Primary goal | communicate **design decisions** to team | decide impl **phase breakdown** |
| Output | 12-section md (Why/comparison/failure/migration) | Phase 1/2/... + worktree needed? |
| Input | PRD or natural language | Design Doc or settled design |
| Agent | none (direct Edit) | PO Agent (for complexity) |

Large feature: both (design-doc → plan). Small fix: plan only. Detail: `references/design-phase-flow.md`.

## Step 0: Auto-load guidelines (required)

Design + language (auto-detect) + project type guidelines. Detail: `references/command-resource-map.md`.

## Step 1: Scope intake (required)

**Question-suppression default** (`rules/minimize-questions.md` canonical). Prefer immediate decision; ask only on exception.

1. **File count**: Glob / wc -l to get file count and line counts
2. **Undecided points**: list edit scope / delete targets / decision forks
3. **Immediate decision (default)**: for each undecided point, pick 1 recommendation from context (CLAUDE.md / memory / repo convention) with 1-line basis, then proceed to Step 2
4. **Sub question (exception only)**: AskUserQuestion (**max 1**) only if:
   - scope input completely missing (no file / feature name / symptom)
   - 2 recommendations are tied and cannot be narrowed to 1
   - destructive operation / clear conflict with existing policy
5. **Skip condition (go directly to Step 2)**: clear requirement (typo / 1 symbol rename / 1-2 file edit / explicit instruction / 1 recommendation) → no question

## Step 2: Execution mode judgment (required)

Choose from 6 options: `inline` / `/dev` / `/workflow <template>` / `/flow N=<n>` / `/flow --auto` / `/goal "<stop>"`. `/goal` is orthogonal (iterative objective-gate tasks only; combinable as `/goal --inner /dev` etc.).

| Condition | Mode | Why |
|------|---------|------|
| 1 file / 1 symbol / few lines | **inline** (parent Edit direct) | no agent overhead |
| 1-2 files / single task / cross-file coupling | **`/dev`** (1 developer-agent) | delegate only, no parallel |
| structured fan-out (review N lens / migrate N files / research / judge-panel) | **`/workflow <template>`** | deterministic script, resumable, no Gate, ≤500 line diff |
| 3-5 files / high independence / ≥30 lines each / feature impl | **`/flow` N=3-5** | PO/Manager/Dev + 3 Gates, parallel benefit > overhead (60s+) |
| 6+ files / fully independent / feature impl | **`/flow` N=min(file count, 8)** | cap at 8 (session limit) |
| above /flow conditions + fully auto (through PR) | **`/flow --auto`** | AskUserQuestion auto-adopt, auto PR, auto lint-test fix 1× |
| 3+ files / strong cross-file coupling or order dependency | **`/dev` sequential** | parallelism causes conflict |
| 3+ files / only few lines each | **inline consecutive Edit** | overhead unrecoverable |
| iterative + objective gate (test / lint / build exit code) for done | **`/goal "<stop>"`** | maker-checker separation + iteration, Ralph Wiggum guard |

**`/goal` 4 conditions** (all required; canonical: `commands/goal.md`): iterative task / automated stop-condition (exit code) / token budget absorbs N iter waste / agent holds senior tools (Bash/Edit/Task)

**Anti-patterns (avoid past churn)**:
- **inline**: 3+ files / 30+ lines each → context pressure; Sonnet delegation is cost-efficient
- **/dev**: fully independent 3+ files → wastes parallel benefit; consider `/flow` or `/workflow migrate`
- **/workflow**: full PRD→Plan→impl→review→push → no Gate, progress collapses; use `/flow`
- **/flow**: ≤2 files / single task → 60s+ overhead unrecoverable; `/dev` is sufficient
- **/flow --auto**: design branch / large refactor → auto-adopt passes wrong judgment; use `/flow` (manual Gate)
- **/goal**: one-shot / subjective verifier / no hard stop / maker=checker same agent → Ralph Wiggum failure, infinite loop

### /workflow vs /flow

| Axis | /workflow | /flow |
|---|---|---|
| Use | structured fan-out (review / migrate / research / judge-panel) | feature impl PO/Manager/Dev orchestration |
| Gate | none (script self-manages) | 3 Gates required (PO/A/B; C on --auto) |
| Resume | yes (journal cache) | no (fresh fire) |
| Best fit | small–medium (≤500 lines), review / migration | medium–large, impl primary (PRD→Plan→impl→test→review→push) |

Decision examples: review **only** → `/workflow review` / review→fix→push auto → `/flow --auto` / migrate N files → `/workflow migrate` / new feature (PO needed) → `/flow` / design majority-vote → `/workflow judge-panel`

N formula (/flow): canonical = `references/PARALLEL-PATTERNS.md#critical-path-reduction-formula`。LPT_makespan + overhead(N) と T_i 見積 4 段優先順を canonical 参照する。旧 `max(T_i) + 60s` 簡略式は overhead(N) と桁が異なるため使わない。

## Self-Review (required, 2-stage)

Run before any `/plan` output. Cannot skip. Applies uniformly across PO Agent / Direct / `--update` / `--scope` modes. Stage common definition: `commands/review.md` `## Delegation & Self-Review`. Noise discard: `references/on-demand-rules/review-noise-discard.md`.

### Stage A: plan-specific filter

Investigation discard: speculative leads / hypothetical edge cases / unrelated findings.
Plan discard: compat shims / future abstractions / impossible-case error handling / scope creep / premature optimization.

**Step 2 judgment validity review**:
- inline when `/dev` delegation needed (1 file / few lines / ≤1 sub question)?
- `/dev` when `/flow` needed (file count < 3 / strong coupling / overhead unrecoverable)?
- `/flow` when `/workflow` is sufficient (structured fan-out / no PO needed / resume wanted / small scale)?
- `/workflow` when `/flow` is required (impl primary / PRD needed / Gate required)?
- `/goal` chosen but 4 conditions not met (one-shot / subjective verifier / no hard stop / maker=checker)?
- iterative + objective gate task but using single `/dev` without gate verification loop (→ switch to `/goal`)?
- N too high (N_candidate doesn't satisfy coupling=0 / wall_clock_parallel ≥ wall_clock_sequential)?
- `--auto` proposed but user confirmation branch points remain (large design branch / destructive op / external send)?
- carry-over / out-of-scope tasks mixed into this plan?

### Stage B: aggregate view

Phase consolidation (same root cause → 1 Phase) / detail-level alignment / convention alignment / Zero-phase valid (no padding). Do not include judgment log in plan file.

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

## Execution mode
- Mode: inline / `/dev` / `/workflow <template>` / `/flow N=<n>` / `/flow --auto` / `/goal "<stop>"`
- Basis: [file count / coupling / T_i / overhead comparison + /workflow vs /flow orthogonal judgment + (if /goal) 4 conditions and stop-condition cmd in 1 line]
- (if /goal only) Stop-condition: [`bats tests/foo` / `npm run lint` etc. exit code as verdict cmd], Hard stops: max-iter=5 / max-token=100000 / timeout=30m

## Worktree
- Needed: Yes/No
- Branch name: [propose]
```

## Plan storage

Save to `plansDirectory` (default `~/.claude/plans`) as `YYYY-MM-DD_[project]_[feature].md`. Loadable via `/reload`.

## Fail behavior

| Scenario | Action |
|------|------|
| PO Agent launch fail | Downgrade to direct, warn. Complex tasks propose requirement split |
| Guideline load fail | Continue w/ common only, design decision on maintainer |
| Serena MCP fail | Substitute w/ grep/Glob, warn precision drop |
| `plansDirectory` write fail | Chat output only, guide manual save |

**Read-only** - Implementation via `/dev`.
