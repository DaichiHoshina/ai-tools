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

`Concurrent sessions = parent + Developer × N <= 9`, so `N <= 8`. Cap raised from 4 to 8 on 2026-05-30 — notification は集約受信で flood 化せず、parent context は /compact で対処。時間 KPI 優先 (time-first 原則) により引き上げ。

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

1. Historical measurements (`references/performance-insights.md`, N >= 20 samples)
2. Manager task-breakdown (changed file count × unit time)
3. Simple rules (impl + tests + lint + self-check):
   - Simple edit (typo, import fix): 30s
   - Logic addition (modify function + unit test): 60s
   - New feature (new file + tests + lint): 120s
   - Complex feature (cross-file + integration test): 300s
4. Unknown: conservative maximum, or skip parallelism

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

### Team path (`/flow --parallel`, with worktree)

```text
overhead_team(N) = orchestration_cost + integration_cost + spawn_cost(N)
                 = 138 + 42 + 20N = 180 + 20N
Adopt if: LPT_makespan(T_i, N) + 180 + 20N < sum(T_i) × 0.95
```

**Equal-size, count = N simplified guide** (`LPT_makespan = T_task`):

| N | Required T_task | Assessment |
|---|---|---|
| 2 | > 3780s | Threshold (time-first: adopt unless forbidden) |
| 4 | > 1282s | Threshold (time-first: adopt unless forbidden) |
| 8 | > 720s | **First choice** |

### Direct execution (`/dev --parallel`, with worktree)

```text
overhead_direct(N) = spawn_cost(N) + integration_cost
                   = 20N + 20
Adopt if: LPT_makespan(T_i, N) + 20N + 20 < sum(T_i) × 0.95
```

**Equal-size simplified guide**:

| N | Required T_task | Assessment |
|---|---|---|
| 2 | > 420s | Viable |
| 4 | > 160s | Viable |
| 8 | > 100s | **First choice** |

Additional: 2+ independent tasks; edit targets fully isolated (no file-level overlap).

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

- `claude-code/agents/manager-agent.md` - Task assignment, Manager role
- `claude-code/agents/po-agent.md` - Strategy decisions, worktree confirmation responsibility
- `claude-code/agents/developer-agent.md` - Behavior during parallel execution
- `claude-code/commands/flow.md` - `/flow --parallel` spec
- `claude-code/commands/dev.md` - `/dev --parallel` spec
- `claude-code/references/performance-insights.md` - Agent real-time measurements
- `claude-code/references/session-management.md` - 9 concurrent session limit
