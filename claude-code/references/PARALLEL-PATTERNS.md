# Parallel Execution Patterns

> **Purpose**: Decide agent / worktree parallelism with critical-path reduction first. Single source of truth for all parallel-execution judgments.

**Canonical reference** for parallel execution decisions, responsibility separation, and worktree applicability. manager-agent, po-agent, developer-agent, agents/README, session-management must not re-describe details — hold only a reference link to this file.

## Terminology

| Term | Definition |
|---|---|
| **N** | Number of Developer agents launched in parallel (= parallel worktrees), `N = min(independent task count, 8)` |
| Concurrent sessions | Parent + parallel Developers, max 9 |
| Team path | `/flow --parallel`, PO → Manager → Developer×N |
| Direct execution | `/dev --parallel`, no PO/Manager, Developer×N only |
| **T_i** | Estimated duration of task i (includes implementation + tests + lint + self-check) |
| **LPT_makespan(T_i, N)** | Slowest lane total time when tasks are assigned to N lanes via LPT (Longest Processing Time) |

### Why the 8-Developer limit

`Concurrent sessions = parent + Developer × N <= 9`, so `N <= 8`. Cap raised from 4 to 8 on 2026-05-30 — notification flood handled by aggregate receipt; parent context handled by /compact. Time-first principle applied.

## Critical-path reduction formula

### Common form

```text
expected_serial   = sum(T_i)
expected_parallel = LPT_makespan(T_i, N) + overhead(N)
Adopt if: expected_parallel < expected_serial × 0.95
```

### LPT scheduling

```text
1. Sort T_i descending
2. Assign each task to the lane with the smallest current total
3. makespan = max(total time per lane)
```

Simplified: count = N → `LPT_makespan = max(T_i)` / count > N → apply above.

### N selection rule

```text
N_initial = min(independent task count, 8)
If formula FAILS → reduce N by 1 and re-evaluate (N >= 2)
N = 1 → sequential execution
```

### T_i estimation priority

T_i は以下の優先順位で見積もる。上位 source が使える場合はその source を優先する。

| 優先 | Source | 内容 |
|---|---|---|
| 1 | Historical measurements | `references/performance-insights.md` の実測値 (N >= 20 samples) |
| 2 | Manager task-breakdown | 変更 file 数 × 単位時間 |
| 3 | Simple rules | 下表 (impl + tests + lint + self-check 込み) |
| 4 | Unknown | 保守的最大値、または並列化を見送る |

Simple rules の単位時間:

| Task 種別 | 見積 |
|---|---|
| Simple edit (typo / import fix) | 30s |
| Logic addition (function 修正 + unit test) | 60s |
| New feature (new file + tests + lint) | 120s |
| Complex feature (cross-file + integration test) | 300s |

### Cost breakdown

| Cost | Value | Nature |
|---|---|---|
| `orchestration_cost` (Team) | 138s | PO 96s + Manager 42s (measured in performance-insights.md) |
| `integration_cost` (Team) | 42s | Manager restart |
| `integration_cost` (Direct) | 20s | Conflict check |
| `spawn_cost(N)` | 20N | Developer launch 17s + notification → rounded to 20s/Dev |
| `worktree_setup_cost(N)` | **negligible** (measured 90ms/wt) | git worktree add avg 90ms, excluded from formula |
| `failure_retry` | Excluded from formula | Risk note: Developer 30-min timeout × 2 retries = worst-case +60 min |

> **Measurement correction**: Initial placeholder `worktree_setup_cost = 20N` corrected to negligible after Phase 1 measurement (5-sample average 90ms). Excluded from formula.

> **2026-05-31 30d calibration (n=18 invocations)**:
> - `180s` (orchestration+integration): derived from performance-insights.md measurements, cannot be separated from this data directly → **literal maintained**
> - `20N` (spawn_cost): developer-agent launch 17s measured → round 20s → **literal maintained**
> - `0.95` (parallel threshold): only 4 N=1 (sequential) cases, no statistical significance → **insufficient data (N=1 cases few), provisional**
> - `avg_task_sec` p50=129s, p90=212s (n=18): consistent with midpoint between `Logic addition=60s / Complex=300s` T_i estimates
> - `total_wall_sec` median=1086s, p90=8448s (p90 driven by large N=11/14/15 runs)
> - n_dev_agents distribution: 1–15, median≈5 (large N runs push median up)
> - raw data: `~/.claude/logs/flow-baseline-20260531.tsv`

### Team path (`/flow --parallel`, with worktree)

```text
overhead_team(N) = orchestration_cost + integration_cost + spawn_cost(N)
                 = 138 + 42 + 20N = 180 + 20N
Adopt if: LPT_makespan(T_i, N) + 180 + 20N < sum(T_i) × 0.95
```

**Equal-size, count = N threshold formula** (`LPT_makespan = T_task`, `sum(T_i) = N × T_task`):

```text
T_task_threshold = overhead_team(N) / (0.95N − 1)
```

Adopt parallel if `T_task > T_task_threshold`. Representative derivations (do not maintain a static table — recalculate by substituting N into the formula above; if the `0.95` threshold is recalibrated, values shift accordingly):

- N=2: `220 / (1.9 − 1) = 244.4s`
- N=4: `260 / (3.8 − 1) =  92.9s`
- N=8: `340 / (7.6 − 1) =  51.5s`

### Direct execution (`/dev --parallel`, with worktree)

```text
overhead_direct(N) = spawn_cost(N) + integration_cost
                   = 20N + 20
Adopt if: LPT_makespan(T_i, N) + 20N + 20 < sum(T_i) × 0.95
```

**Equal-size, count = N threshold formula** (`LPT_makespan = T_task`, `sum(T_i) = N × T_task`):

```text
T_task_threshold = overhead_direct(N) / (0.95N − 1)
```

Adopt parallel if `T_task > T_task_threshold`. Representative derivations (do not maintain a static table — recalculate by substituting N into the formula above; if the `0.95` threshold is recalibrated, values shift accordingly):

- N=2: ` 60 / (1.9 − 1) = 66.7s`
- N=4: `100 / (3.8 − 1) = 35.7s`
- N=8: `180 / (7.6 − 1) = 27.3s`

Additional: 2+ independent tasks; edit targets fully isolated (no file-level overlap).

> Same-file note: the no-file-overlap rule blocks *parallel writes* (worktree / concurrent apply). The read-only patch-generation phase is exempt — multiple subagents may draft patches for distinct regions of one file in parallel, then the parent applies them sequentially. See `references/auto-delegation-detailed.md` for that pattern.

## Fan-out hard rules

> Sources: [Tembo — Claude Code Subagents](https://www.tembo.io/blog/claude-code-subagents) / [Nimbalyst — Subagents Guide](https://nimbalyst.com/blog/claude-code-subagents-guide/) / [Claudify — Parallel Agents](https://claudify.tech/blog/claude-code-parallel-agents)

### Concurrency sweet spot

| Range | Guidance |
|---|---|
| **3–5 concurrent** | Sweet spot. Merge overhead stays low; critical-path reduction is maximized |
| **6–8 concurrent** | Acceptable when task count warrants it; merge/integration cost rises |
| **> 8 concurrent** | Forbidden (session limit: parent + N ≤ 9). Exception: Dynamic Workflows (`Workflow` tool) allow tens–hundreds |

### Parallelizability pre-check (required before any fan-out)

Before firing N ≥ 2 agents, verify all three conditions:

1. **No shared write targets** — two agents must never write the same file concurrently (race condition; data loss risk)
2. **No dependency chain** — if subtask B needs the output of subtask A, run them sequentially
3. **Read-only tasks** — unlimited parallelism allowed (no write conflict possible)

If any condition fails → downgrade to sequential or split into sequential phases.

### Write partition rule

Each Developer owns a **disjoint file set**. Files needed by multiple Developers must be reserved for the parent (Manager) to handle after fan-out completes. Partition assignment is Manager's responsibility; PO Gate v2 enforces `file_count` + `bundle_justification` checks.

## Worktree applicability flow

```text
Formula PASS and 2+ independent tasks
  ├─ Yes → No shared file edits?
  │         ├─ Yes → Worktree parallel candidate (PO confirm or --auto 4 conditions)
  │         └─ No  → Sequential execution
  └─ No  → Sequential execution
```

### `/flow --parallel --auto` skip-confirmation 4 conditions

1. Team formula PASS
2. Clean worktree (no git status changes, no stash)
3. No branch / worktree name conflict
4. Auto-fallback on creation failure (downgrade to sequential + notify)

### `/dev --parallel --auto` skip-confirmation 4 conditions

1. Direct formula PASS (+ 2+ independent + fully isolated)
2. Clean worktree
3. No branch / worktree name conflict
4. Auto-fallback on creation failure

### Cleanup policy (common)

- Worktree with changes: return branch, parent merges, delete worktree
- Worktree no changes: auto-delete
- Merge conflict: downgrade to sequential, leave worktree for user

### Agent tool `isolation: "worktree"` の実挙動

- subagent が commit を作ると cleanup phase で parent branch (main) に**自動 merge される** (Anthropic 標準の想定動作)。不要 commit も乗るため、委譲は commit-worthy な task に限り、試験的編集は inline で行う。失敗 commit は `git revert` で戻す
- 非 commit 完了は 2 分岐する: 単発なら working tree 変更が main に uncommitted 残留 / 並列 + untracked file なら worktree path 自体が残存する
- 検知: 完了報告後に `git log --oneline -3` で申告 commit を確認し、見えなければ `git status`。並列発火時は `git worktree list` で agent-* 残存も確認し、残っていれば `git worktree remove --force <path>` + branch 削除で手動 cleanup する
- 予防: 委譲 prompt に「commit 必須 (commit message 含めて完了)」を明記する

## Responsibility separation

| Role | Owner |
|---|---|
| Decide whether to create worktree | PO Agent (user confirmation required; --auto 4 conditions as alternative) |
| Launch parallel execution | flow / dev / parent (Claude Code) |
| Task assignment and parallelism degree | Manager Agent (Team path only) |
| Work inside worktree | Developer Agent |

## Forbidden phrase definitions (bats validation targets)

### Validation target files

target_files:
- agents/manager-agent.md
- agents/po-agent.md
- agents/developer-agent.md
- agents/README.md
- references/session-management.md

Note: This file (PARALLEL-PATTERNS.md) is the definition source; excluded from validation.

### Forbidden phrases

forbidden_phrases:
- "パターン1: 完全並列実行"
- "パターン2: 段階的実行"
- "パターン3: 順次実行"
- "同一ファイル変更? → Yes → 順次"

### Allowed summary phrases

allowed_summaries:
- "並列実行パターン詳細: references/PARALLEL-PATTERNS.md 参照"
- "worktree applicability: references/PARALLEL-PATTERNS.md#worktree-applicability-flow"

### Update marker regex (bats per-boundary skip judgment)

```regex
references/PARALLEL-PATTERNS\.md(#[a-zA-Z0-9_-]+)?
```

## Related documents

| File | 役割 |
|---|---|
| `claude-code/agents/manager-agent.md` | Task assignment, Manager role |
| `claude-code/agents/po-agent.md` | Strategy decisions, worktree confirmation responsibility |
| `claude-code/agents/developer-agent.md` | Behavior during parallel execution |
| `claude-code/commands/flow.md` | `/flow --parallel` spec |
| `claude-code/commands/dev.md` | `/dev --parallel` spec |
| `claude-code/references/performance-insights.md` | Agent real-time measurements |
| `claude-code/references/session-management.md` | simultaneous sessions upper limit (3–5) |
| `claude-code/references/orchestrate-mode.md` | `/flow --orchestrate` operation spec (parent pre-delegation steps + firing protocol) |
