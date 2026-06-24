---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Task, AskUserQuestion, Skill, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*
description: Orchestration-first workflow — parent-led parallel fan-out (orchestrate + parallel forced)
argument-hint: "[task description]"
---

## /flow - Orchestration-first workflow

**Core**: `/flow` is an orchestration-only command. Forces worktree parallel fan-out under parent direction; minimizing makespan is the top KPI. Tasks where parallelism cannot hold (file conflicts / single-symbol edits etc.) fall back via sequential downgrade.

> When to use: `/flow` (orchestrated parallel pipeline) / `/dev` (single-agent impl) / `/flow-auto` (`/flow --auto` alias, fully autonomous) / `/review-fix-push` (review-loop only)

## Task type detection

Match keywords top-down, **first hit wins**. If mixed, ask user. `*impl*` = expanded by PO decision.

- **Team**: `Task(po-agent)` → `Task(manager-agent)` → `Task(developer-agent)×N` → aggregate → `Task(reviewer-agent)` → P0 re-fix 1 loop
- **Direct**: `/dev` (review = `/review` = `comprehensive-review` skill). Sub-agents cannot spawn; parent launches each tier.

| # | Keywords | Task | Workflow |
|---|-----------|--------|------------|
| 0 | 相談, ブレスト, brainstorm | Design consultation | /brainstorm → /prd → /plan |
| 1 | 緊急, hotfix, 本番, critical | Urgent | /diagnose → *impl* → /lint-test → /git-push --pr |
| 1.5 | インシデント, 障害, エラーログ貼付 | Incident | Skill(incident-response) → /diagnose → *impl* → /lint-test → /git-push --pr |
| 2 | 根本原因, rca, 再発防止 | RCA | /diagnose → Skill(root-cause) → *impl* → /lint-test → /git-push --pr |
| 3 | 修正, fix, バグ, 不具合 | Bug fix | /diagnose → *impl* → /lint-test → /git-push --pr |
| 4 | リファクタ, refactor, 構造改善 | Refactor | /plan → *impl* → /lint-test → /test → /review → /git-push --pr |
| 5 | ドキュメント, docs, README | Docs | /docs → /review → /git-push --pr |
| 6 | テスト作成, test追加, spec | Testing | /test → /review → /lint-test → /git-push --pr |
| 7 | 追加, 実装, 新規, 機能, add | New feature | /prd → /plan → *impl* → /test → /review → /lint-test → /git-push --pr |
| 8 | データ分析, analysis, SQL | Analysis | *impl* → /docs → /git-push --pr |
| 9 | インフラ, terraform, k8s, IaC | Infrastructure | /plan → Skill(terraform) → /lint-test → /git-push --pr |
| 10 | 調査のみ, 診断, troubleshoot | Investigation (read-only) | /diagnose → /docs |
| 11 | その他 | New feature (default) | |

Boundary: "fix from error log"=1.5 / "bug root cause"=2 / "feature improvement"=7 (struct only=4) / "investigate & fix error"=3.

## Options

```text
--skip-prd / --skip-test / --skip-review / --auto
--sequential  (opt-out: only when parent judges parallelism physically impossible; PO/Manager always required)
--multi-review  (step 8 で 12 観点 split fan-out を強制。`--auto` は自動 ON)
--until-gate-green "<check-cmd>" [--max-iter <n>]  (step 9 P0 loop の停止条件を objective gate に切替。default max-iter=3。Ralph Wiggum guard、`references/loop-engineering.md` 参照)
```

**Default = orchestrate + parallel forced ON**. Plain `/flow` invocation fires parent pre-delegation (N calc / target echo / verify echo / DoD echo) + worktree parallel fan-out simultaneously. Add `--auto` for fully autonomous mode (skip confirmations + auto push). `--sequential` is an emergency fallback only when file conflicts make parallelism physically impossible.

## Orchestration (forced)

Always force parent-direction mode. Pre-delegation 4 steps (N calc / target / verify / DoD) are **internal**; user sees 2 lines only (formula trace + fan-out declaration). Detailed echo goes into subagent prompt literals — no chat output.

After completion, **fire N tool_use in 1 message** (repeating 1 message 1 Agent N times causes sequential chaining — forbidden). Spec details: `references/orchestrate-mode.md` / `references/PARALLEL-PATTERNS.md`.

Formula trace echo: `formula: N=<N_chosen> / sum_T_i=<sum>s / LPT+ovh=<expected_parallel>s / PASS|FAIL (basis=<T_i_basis>)` / `fan-out: N=<n>, targets=<file count>`. 詳細: `references/flow-orchestration.md`

## Parallel (forced)

Physically parallelizes via worktree isolation.

| Item | Action |
|------|------|
| Parallelism degree eval | Forced (Manager) |
| worktree proposal | Forced (PO) |
| worktree creation | `--auto`: auto under 4 skip conditions; otherwise user confirm |
| Sequential downgrade | On file conflict / physical conflict detected, or `--sequential` |

**`--auto` skip conditions**: Parallel formula PASS + clean worktree + no branch/worktree collision + Creation fail → sequential downgrade + notify. Details: `references/PARALLEL-PATTERNS.md` `### /flow --parallel --auto skip-confirmation 4 conditions`.

**worktree cleanup**: Changes present → return branch + merge + delete / no changes → auto-delete / Collision → sequential downgrade + leave in place. Details: `references/PARALLEL-PATTERNS.md` `### Cleanup policy (common)`.

Sweet spot / hard rules (concurrency limit, write partition, dependency chain): `references/PARALLEL-PATTERNS.md#fan-out-hard-rules`.

## --auto mode

`--auto`: skip AskUserQuestion + auto-adopt / `bypassPermissions` / always PR push / auto-fix lint 1× / `--multi-review` auto-ON. review-fix loop: post-impl `/review` → auto-fix repeat until Critical 0 + Warning 0 (max 3×). 詳細: `references/flow-orchestration.md`

## Execution logic

1. **git status check** → WIP confirm → step 2
2. **Pre-Manager downgrade check**: `--sequential` explicit → single `/dev` (skip PO/Manager). Otherwise → step 3
3. **PO Agent (required)**: design judgment / scope split. Cannot skip
4. **Manager Agent (required)**: task split / file dedup / N calc + `formula_trace`
5. **Post-Manager downgrade check**: `parallelism: 1` + `worktree_required: false` or file conflict → Dev×1 sequential
6. **Orchestration pre-delegation** (internal + echo 2 lines); `mkdir -p <impl_notes.dir>`
6.3. **PO Gate (Manager allocation oversight)** (required; single-shot per `/flow`). Parent re-spawns PO with Manager allocation + initial `manager_instruction` (contract §1.1). PO returns `verdict: pass | fail | modify`. `pass` → step 6.5. `modify` → Manager re-allocation with `fix_request` (1 loop max, then escalate). `fail` → stop `/flow` + user escalation. Cannot skip. Canonical: `agents/po-agent.md` § Manager allocation oversight
6.5. **Gate A: parallel-judgment self-review** (required; N≥2 only). Parent Opus re-evaluates across 6 criteria. FAIL → re-run Manager. PASS → step 7. Cannot skip. Canonical: `references/parallel-self-review.md`
7. **Parallel fan-out**: Fire `Task(developer-agent)×N` in 1 message (bundle required; N=1 sequential confirmed at step 5)
8. **Parallel integrate + review** (fire both in 1 message): Manager integrate + `Task(reviewer-agent, --codex)`×1 (or Gate C on `--auto`/`--multi-review`). Canonical: `references/parallel-self-review.md` §Gate C
8.5. **Gate B: parallel-implementation self-review** (required; N≥2 only). 4 criteria. FAIL → force step 9. Canonical: `references/parallel-self-review.md`
8.7. **Dev failure gate** (required; after step-8 aggregate). `status ∈ {failure, partial, dep_unresolved}` → Manager realloc (`reallocation_trigger: dev_failure` + `failed_devs[]`, contract §3.1) → re-fix (1 loop max). 2nd fail → stop + escalate (`--auto`: `stop: dev failure 2x` + skip push)
9. **P0 re-fix loop**: P0 → manager realloc → dev×M fix → reviewer re-verify (max 1 loop). P0 remains/P1 → report & continue. **`--until-gate-green "<cmd>"`**: 停止条件を reviewer P0=0 ではなく bash `<cmd>` exit 0 に切替 (max-iter default 3、token/timeout は `/goal` と同 default)。objective gate 強制 = Ralph Wiggum guard。Canonical: `references/loop-engineering.md`

詳細 step prose: `references/flow-orchestration.md`

## Self-Review (required, 3 gates)

Parent Opus gates mandatory. Canonical: `references/parallel-self-review.md`. Noise discard: `rules/review-noise-discard.md`. **Parent 責任**: PO/Manager に丸投げ禁止。PO Gate v2 は fan-out 前に parent が必ず実行 (skip 不可)。Canonical: `references/retrospectives/2026-06-19_agent-oversight.md`

A/B mandatory on orchestration path; `--sequential` exempts A/B. C: `--auto`/`--multi-review` only.

- **PO Gate v2** (step 6.3, post-Manager / pre-Gate A): 8 観点 — goal/constraints/priority/file_count/bundle_justification/scope/subagent_type/branch_cwd literal. `modify` → Manager re-allocation (max 1); `fail` → stop + user escalation
- **Gate A** (step 6.5, before fan-out): 6 criteria — N consistency / formula PASS / file conflict / worktree applicability / T_i basis / bundle fire format. FAIL → re-run Manager (max 1); 2nd → `--sequential` downgrade
- **Gate B** (step 8.5, after aggregate): 4 criteria — cross-diff conflict / duplicate import / naming collision / propagation incompleteness. FAIL → force step 9 P0 loop (max 1)
- **Dev failure gate** (step 8.7, after aggregate): 1 criterion — any Dev `status != success`. FAIL → Manager re-allocation (max 1); 2nd → stop + user escalation
- **Gate C** (`--auto` / `--multi-review` only): 12-lens stage split (stage 1=7 agent / stage 2=6 agent; 8 Dev + 9 session limit + 1 margin). Default `/flow` keeps `comprehensive-review` + codex 2-agent mode.

## Integration rules

Required: impl → /lint-test → /review → review-fix → /git-push. 2× fail with same approach → `/clear` → re-organize.

### Completion actions

- Save to auto-memory: `~/.claude/projects/<project>/memory/work-context-YYYYMMDD-{topic}.md` (Serena `write_memory` forbidden — 2026-06-10)
- `--auto`: secret check → /git-push --pr → notify `[flow-auto] {topic} complete → PR created` (fail: `fail: {reason}` / lint 2×: `stop: lint-test 2× fail`)
- Normal: AskUserQuestion "push?"
- **/clear 推奨 (cache_read 累積防止)**: /flow 完遂後は task 境界。次 task に進む前に `/clear` を chat 末尾に 1 行提案 (`--auto` は完了通知に `→ next task は /clear 後に開始推奨` を併記)

## Auto-apply features

| Feature | Condition | Action |
|------|------|------|
| worktree isolation | Default forced; skip on `--sequential` / downgrade | `isolation: "worktree"` auto-create / cleanup |
| Post-impl verify | `--auto` complete | `/lint-test` (verify-app explicit only) |
| `IMPL_NOTES` | Team path (Dev via Task()) | Dev writes `dev-<task-id>.md` → Manager merges → parent persists `MERGED.md` under `~/.claude/plans/impl-notes/<run-dir>/`. `/git-push --pr` consumes for PR draft (`--no-impl-notes` to skip) |

worktree apply decision: `references/PARALLEL-PATTERNS.md#worktree-applicability-flow`.

ARGUMENTS: $ARGUMENTS
