---
allowed-tools: Read, Glob, Grep, Bash, Task, AskUserQuestion, mcp__serena__*, mcp__context7__*
argument-hint: "<task-or-scope>"
description: Design & planning — strategy formulation via PO Agent (read-only)
---

## Boundary w/ `/design-doc`

`/design-doc` = design decisions の team 共有 (12-section md / input: PRD or NL / 直 Edit) vs `/plan` = impl phase breakdown 決定 (Phase 1/2/... + worktree / input: Design Doc or settled design / PO Agent)。Large feature は両方 (design-doc → plan)、small fix は plan のみ。Detail: `references/design-phase-flow.md`.

## Step 0: Auto-load guidelines (required)

Design + language (auto-detect) + project type guidelines. Detail: `references/command-resource-map.md`.

## Step 1: Scope intake (required)

**Question-suppression default** (`rules/minimize-questions.md` canonical) — 推奨即決を優先し、exception 時のみ問う。

1. **File count**: Glob / wc -l で file 数と line 数を取得
2. **Undecided points**: edit scope / delete target / decision fork を列挙
3. **Immediate decision (default)**: 各 undecided point に対し context (CLAUDE.md / memory / repo convention) から推奨を 1 件選び、1-line basis を添えて Step 2 へ進める
4. **Sub question (exception only)**: AskUserQuestion (**max 1**) は scope input 完全欠落 / 2 推奨拮抗 / 破壊的操作・既存方針との明確衝突、のいずれかでのみ発火する
5. **Skip condition (→ Step 2 直行)**: typo / 1 symbol rename / 1-2 file edit / 明示指示 / 推奨 1 件確定 → no question

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

**Anti-patterns (avoid past churn)**: inline 3+ files / 30+ lines each (context pressure) ・ /dev fully independent 3+ files (parallel benefit を捨てる) ・ /workflow full PRD→Plan→impl→review→push (no Gate で progress 崩壊) ・ /flow ≤2 files (overhead unrecoverable) ・ /flow --auto design branch / large refactor (auto-adopt が誤判定通過) ・ /goal one-shot / subjective verifier / no hard stop / maker=checker (Ralph Wiggum infinite loop)

### /workflow vs /flow

Comparison table canonical: `commands/workflow.md` § /workflow vs /flow.

Decision examples: review **only** → `/workflow review` / review→fix→push auto → `/flow --auto` / migrate N files → `/workflow migrate` / new feature (PO needed) → `/flow` / design majority-vote → `/workflow judge-panel`

N formula (/flow): canonical = `references/PARALLEL-PATTERNS.md#critical-path-reduction-formula`。LPT_makespan + overhead(N) と T_i 見積 4 段優先順を canonical 参照する。旧 `max(T_i) + 60s` 簡略式は overhead(N) と桁が異なるため使わない。

## Self-Review (required, 2-stage)

Run before any `/plan` output. Cannot skip. Applies uniformly across PO Agent / Direct / `--update` / `--scope` modes. Stage common definition: `commands/review.md` `## Delegation & Self-Review`. Noise discard: `references/on-demand-rules/review-noise-discard.md`.

### Stage A: plan-specific filter

Anti-pattern filter (investigation / plan discard): `references/on-demand-rules/review-noise-discard.md`.

**Step 2 judgment validity review** (mode mismatch check):
- mode overshoot/undershoot: inline ↔ `/dev` ↔ `/flow` ↔ `/workflow` ↔ `/goal` の境界条件 (Step 2 table / Anti-patterns) を 1 件ずつ反証する
- `/goal` 4 conditions 不成立 / iterative + objective gate task で単一 `/dev` (no gate loop)
- N over-allocation (coupling=0 不成立 / wall_clock_parallel ≥ sequential)
- `--auto` 提案下に user confirm 分岐 (design branch / destructive op / external send) が残存
- carry-over / out-of-scope task の混入

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

PO Agent launch fail → direct downgrade + warn (complex 時は requirement split 提案) / Guideline load fail → common のみで継続、maintainer 判断 / Serena MCP fail → grep/Glob 代替 + 精度低下 warn / `plansDirectory` write fail → chat 出力のみ + manual save 誘導

**Read-only** - Implementation via `/dev`.
