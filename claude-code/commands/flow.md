---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Task, AskUserQuestion, Skill, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*
description: Orchestration-first workflow — parent-led parallel fan-out (orchestrate + parallel forced)
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
```

**Default = orchestrate + parallel forced ON**. Plain `/flow` invocation fires parent pre-delegation (N calc / target echo / verify echo / DoD echo) + worktree parallel fan-out simultaneously. Add `--auto` for fully autonomous mode (skip confirmations + auto push). `--sequential` is an emergency fallback only when file conflicts make parallelism physically impossible.

## Orchestration (forced)

Always force parent-direction mode. Pre-delegation 4 steps (N calc / target / verify / DoD) are **internal**; user sees 2 lines only (formula trace + fan-out declaration, see step 6). Detailed echo goes into subagent prompt literals — no chat output.

After completion, **fire N tool_use in 1 message** (repeating 1 message 1 Agent N times causes sequential chaining — forbidden). Spec details: `references/orchestrate-mode.md` / `references/PARALLEL-PATTERNS.md`.

### Formula trace echo (mandatory)

Parent must echo Manager-returned `formula_trace` to chat (makes decision basis visible to user). Echo format:

```text
formula: N=<N_chosen> / sum_T_i=<sum>s / LPT+ovh=<expected_parallel>s / <PASS|FAIL> (basis=<T_i_basis>)
fan-out: N=<n>, targets=<file count>
```

`formula_trace` field missing / `formula_result=FAIL` with `N>=2` → parent stops fan-out, re-runs Manager (discards allocation). `N_chosen=1` → sequential downgrade proceeds (via Manager / consistent with step 5).

Schema details: see `agents/manager-agent.md` Allocation plan format `formula_trace` field definition.

## Parallel (forced)

Physically parallelizes via worktree isolation.

| Item | Action |
|------|------|
| Parallelism degree eval | Forced (Manager) |
| worktree proposal | Forced (PO) |
| worktree creation | `--auto`: auto under 4 skip conditions; otherwise user confirm |
| Sequential downgrade | On file conflict / physical conflict detected, or `--sequential` |

### `--auto` skip conditions

Details: `references/PARALLEL-PATTERNS.md` `` ### `/flow --parallel --auto` skip-confirmation 4 conditions ``. Summary: Parallel formula PASS + clean worktree + no branch/worktree collision + Creation fail → sequential downgrade + notify.

### worktree cleanup

Details: `references/PARALLEL-PATTERNS.md` `### Cleanup policy (common)`. Summary: Changes present → return branch + merge + delete / no changes → auto-delete / Collision → sequential downgrade + leave in place.

## --auto fully autonomous mode (opt-in)

| Decision | Action |
|------|------|
| AskUserQuestion | Don't call, auto-adopt recommendation |
| Agent launch | `mode: "bypassPermissions"` |
| Push target | Always PR (no main direct push) |
| Design decision | Recommend, priority simple |
| lint-test fail | Auto-fix 1×, 2nd fail stop + report |
| Multi-review | `--multi-review` auto-ON (Gate C 12-lens parallel) |

review-fix loop: post-impl `/review` → auto-fix repeat **until Critical 0 + Warning 0** (max 3×, excess → report & continue).

## Execution logic

1. **git status check**: changes found → confirm WIP then step 2 (continue orchestration, do not redirect to `/dev`)
2. **Pre-Manager downgrade check** (static): immediate downgrade only when `--sequential` explicit — delegate single `/dev` + skip PO/Manager. Otherwise → step 3
3. **PO Agent (required)**: design judgment / scope split. Cannot skip (legacy `--no-po` removed)
4. **Manager Agent (required)**: task split / file dedup / N calc + formula_trace computation
5. **Post-Manager downgrade check** (dynamic): Manager allocation `parallelism: 1` *and* `worktree_required: false` *or* physical file conflict (same file concurrent edit) → Dev×1 sequential (skip worktree isolation = downgrade in `Auto-apply features`; Manager integrate skips aggregation for 1 dev; Team review still runs)
6. **Orchestration pre-delegation** (internal + judgment trace echo): embed target / verify / DoD in subagent prompt; user sees **2 lines**:
   - line 1 (formula trace): `formula: N=<N_chosen> / sum_T_i=<sum>s / LPT+ovh=<expected_parallel>s / PASS|FAIL (basis=<T_i_basis>)`
   - line 2 (fan-out declaration): `fan-out: N=<n>, targets=<file count>`
   If any required echo field from Manager's `formula_trace` (12 sub-fields) is missing → stop fan-out, re-request from Manager (discard allocation). Include worktree apply/skip judgment (downgrade_reason presence) in echo line 1. Run `mkdir -p <impl_notes.dir>`
6.3. **PO Gate (Manager allocation oversight)** (required; single-shot per `/flow`). Parent re-spawns PO with Manager allocation + initial `manager_instruction` (contract §1.1). PO returns `verdict: pass | fail | modify`. `pass` → step 6.5. `modify` → Manager re-allocation with `fix_request` (1 loop max, then escalate). `fail` → stop `/flow` + user escalation. Cannot skip. Canonical: `agents/po-agent.md` § Manager allocation oversight
6.5. **Gate A: parallel-judgment self-review** (required; N≥2 only after step 5 downgrade check; N=1 sequential path is exempt). Parent Opus re-evaluates Manager's `N_chosen` / `formula_trace` / file conflict detection across 6 criteria. FAIL → re-run Manager (discard allocation, return to step 4). PASS → step 7. Cannot skip. Canonical: `references/parallel-self-review.md`
7. **Parallel fan-out**: skip pre-fan-out progress narration; prioritize parallel Task firing. Fire `Task(developer-agent)×N` in 1 message (worktree isolated; N=1 sequential path confirmed at step 5). **Bundle required** (operational spec of L50): bundle all N Tasks in the message immediately after fan-out declaration (N≥2). Splitting into 1-per-message creates sequential chain firing (parentUuid serial) — violates "repeating 1 message 1 Agent N times is sequential" (L50). N declaration : tool_use firing message = 1:1 strict
8. **Parallel integrate + review** (fire both in 1 message): `Task(manager-agent)` integrate **and** reviewer fan-out simultaneously.
   - default: `Task(reviewer-agent, --codex)` × 1 (`comprehensive-review` 12-criteria + codex parallel)
   - `--auto` / `--multi-review`: Gate C (12-lens stage split). Details: `references/parallel-self-review.md` §Gate C
   Reviewer reads `diff_target` directly (MERGED.md skip) → removes `integration_cost` (~42s) from critical path. Bundle both in 1 message.
8.5. **Gate B: parallel-implementation self-review** (required; N≥2 only). Parent Opus re-evaluates N diffs across 4 criteria (cross-diff conflict / duplicate import / naming collision / propagation incompleteness). FAIL → force into step 9 P0 loop (even with 0 P0 findings). PASS → step 9 normal flow. Cannot skip. Canonical: `references/parallel-self-review.md`
8.7. **Dev failure gate** (required; runs immediately on step-8 Manager aggregate, before Reviewer is consumed). Any Dev report with `status ∈ {failure, partial, dep_unresolved}` → parent calls Manager back with `reallocation_trigger: dev_failure` + `failed_devs[]` (contract §3.1) → fan-out re-fix Devs from step 7 (1 loop max). 2nd failure → stop, escalate to user (`--auto`: notify `stop: dev failure 2x` + skip push). Reviewer output from step 8 is discarded on re-fix path (re-run after re-fix succeeds)
9. **P0 re-fix loop** (after both step-8 agents return):
   - P0: manager realloc → developer×M fix → reviewer re-verify (**max 1 loop**)
   - P0 remains / P1: report & continue (stop when `--auto`)
   - codex not configured: `comprehensive-review` single fallback
10. Post-*impl* sequential steps from Task table (review + Gate B done at step 8/8.5, skip)

## Self-Review (required, 3 gates)

Parent Opus gates are mandatory: Manager allocation (A) / parallel diffs (B) / review criteria (C). Canonical: `references/parallel-self-review.md`. Noise discard: `rules/review-noise-discard.md`. **Parent 責任**: PO/Manager に丸投げ禁止。PO Gate v2 は fan-out 前に parent が必ず実行する (skip 不可)。Canonical: `references/retrospectives/2026-06-19_agent-oversight.md`
A/B mandatory on orchestration path (PO→Manager→Dev×N); `--sequential` exempts A/B. C: `--auto` / `--multi-review` only.

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
- **/clear 推奨 (cache_read 累積防止)**: /flow 完遂後は task 境界。次 task に進む前に `/clear` 提案を chat 末尾に 1 行出す (実測 2026-06-19: /flow 連発 session が cache_read 60M+ で $40+/session)。`--auto` は完了通知に `→ next task は /clear 後に開始推奨` を併記

## Auto-apply features

| Feature | Condition | Action |
|------|------|------|
| worktree isolation | Default forced; skip on `--sequential` / downgrade | `isolation: "worktree"` auto-create / cleanup |
| Post-impl verify | `--auto` complete | `/lint-test` (verify-app explicit only) |
| `IMPL_NOTES` | Team path (Dev via Task()) | Dev writes `dev-<task-id>.md` → Manager merges → parent persists `MERGED.md` under `~/.claude/plans/impl-notes/<run-dir>/`. `/git-push --pr` consumes for PR draft (`--no-impl-notes` to skip) |

worktree apply decision: `references/PARALLEL-PATTERNS.md#worktree-applicability-flow`.

ARGUMENTS: $ARGUMENTS
