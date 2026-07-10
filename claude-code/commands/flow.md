---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Task, AskUserQuestion, Skill, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*
description: Orchestration-first workflow — parent-led parallel fan-out (orchestrate + parallel forced)
argument-hint: "[task description]"
---

## /flow - Orchestration-first workflow

**Core**: Orchestration-only command. Forces worktree parallel fan-out under parent direction; minimizing makespan is the top KPI. File-conflict tasks fall back via sequential downgrade.

> Use: `/flow` (orchestrated parallel) / `/flow --auto` (fully autonomous) / `/dev` (single-agent) / `/review-fix-push` (review-loop only)

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
--multi-review  (step 8: 12-lens split fan-out forced. `--auto` auto-ON)
--until-gate-green "<check-cmd>" [--max-iter <n>]  (step 9 P0 loop: switch stop-condition to objective gate. default max-iter=3. Ralph Wiggum guard; see `references/loop-engineering.md`)
```

**Default = orchestrate + parallel forced ON**. Plain `/flow` fires pre-delegation (N calc / target / verify / DoD) + worktree parallel fan-out. Add `--auto` for fully autonomous mode (skip confirms + auto push). `--sequential` emergency fallback only when file conflicts make parallelism physically impossible.

## Orchestration (forced)

Always force parent-direction mode. Pre-delegation 4 steps are **internal**; user sees 2 lines only (formula trace + fan-out declaration). Detailed echo goes into subagent prompt literals — no chat output.

After completion, **fire N tool_use in 1 message** (1 message per Agent N times = sequential chaining — forbidden). Spec: `references/orchestrate-mode.md` / `references/PARALLEL-PATTERNS.md`.

Formula trace echo: `formula: N=<N_chosen> / sum_T_i=<sum>s / LPT+ovh=<expected_parallel>s / PASS|FAIL (basis=<T_i_basis>)` / `fan-out: N=<n>, targets=<file count>`. Detail: `references/flow-orchestration.md`

## Parallel (forced)

Physically parallelizes via worktree isolation. Parallelism eval = Manager forced / worktree proposal = PO forced / worktree creation = `--auto` は 4 skip conditions で auto、それ以外は user confirm / file conflict or `--sequential` → sequential downgrade。`--auto` skip 4 conditions / cleanup policy / sweet spot / hard rules は `references/PARALLEL-PATTERNS.md` canonical を参照する。

## --auto mode

`--auto`: skip AskUserQuestion + auto-adopt / `bypassPermissions` / always PR push / auto-fix lint 1× / `--multi-review` auto-ON. review-fix loop: post-impl `/review` → auto-fix until Critical 0 + Warning 0 (max 3×). Detail: `references/flow-orchestration.md`

**`--auto` skips confirmations / approvals / push prompts ONLY. It does NOT skip the hierarchy.** The `Task(po-agent)` → `Task(manager-agent)` → `Task(developer-agent)×N` chain is mandatory — autonomous means "no questions asked", not "no PO/Manager". Going straight to `developer-agent` (or inline implementation) without PO design judgment + Manager allocation is a spec violation. Only `--sequential` downgrades to single `/dev` (PO/Manager still run per step 2). Self-Review 3 gates (A/B/C) stay mandatory; canonical: `references/parallel-self-review.md`.

Natural language triggers: "全自動で" / "autoで" / "おまかせ" → `/flow --auto` (旧 `/flow-auto` は本 command に統合済)。

## Execution logic

1. **git status check** → WIP confirm → step 2
2. **Pre-Manager downgrade**: `--sequential` explicit → single `/dev` (skip PO/Manager). Otherwise → step 3
3. **PO Agent (required)**: design judgment / scope split. Cannot skip
4. **Manager Agent (required)**: task split / file dedup / N calc + `formula_trace`
5. **Post-Manager downgrade**: `parallelism: 1` + `worktree_required: false` or file conflict → Dev×1 sequential
6. **Orchestration pre-delegation** (internal + echo 2 lines); `mkdir -p <impl_notes.dir>`
6.3. **PO Gate** (required). Parent re-spawns PO with Manager allocation → `verdict: pass | fail | modify`。`pass` → 6.5 / `modify` → Manager re-allocation (1 loop max, then escalate) / `fail` → stop + user escalation。criteria / `fix_request` schema / literal 検証は §Self-Review 参照。Canonical: `agents/po-agent.md`
6.5. **Gate A** (required; N≥2 only). FAIL → re-run Manager. PASS → step 7. criteria は §Self-Review 参照
7. **Parallel fan-out**: Fire `Task(developer-agent)×N` in 1 message (bundle required)
8. **Parallel integrate + review** (1 message): Manager integrate + `Task(reviewer-agent, --codex)`×1 (or Gate C on `--auto`/`--multi-review`). Canonical: `references/parallel-self-review.md` §Gate C
8.5. **Gate B** (required; N≥2). FAIL → force step 9. criteria は §Self-Review 参照
8.7. **Dev failure gate** (required; after step-8 aggregate). criteria は §Self-Review 参照
9. **P0 re-fix loop**: P0 → manager realloc → dev×M fix → reviewer re-verify (max 1 loop). **`--until-gate-green "<cmd>"`**: switches stop-condition to bash `<cmd>` exit 0 (max-iter default 3). Canonical: `references/loop-engineering.md`

Detail step prose: `references/flow-orchestration.md`

## Self-Review (required, 3 gates)

Parent gates mandatory. Canonical: `references/parallel-self-review.md`. Noise discard: `references/on-demand-rules/review-noise-discard.md`. **Parent responsibility**: no outsourcing to PO/Manager. PO Gate v2 fires pre-fan-out (cannot skip). Canonical: `references/retrospectives/2026-06-19_agent-oversight.md`

A/B mandatory on orchestration path; `--sequential` exempts A/B. `/dev --parallel` also exempts A/B (no PO/Manager orchestration). C: `--auto`/`--multi-review` only.

- **PO Gate v2** (step 6.3): 8 criteria — goal/constraints/priority/file_count/bundle_justification/scope/subagent_type/branch_cwd literal. `modify` → Manager re-allocation (max 1) with `fix_request` 3+1 field (modify_target / unchanged / reason / concrete_change); parent post-validation: `grep -F task.files[]` vs PO instruction literal; `fail` → stop + user escalation
- **Gate A** (step 6.5): 6 criteria — N consistency / formula PASS / file conflict / worktree applicability / T_i basis / bundle fire format. FAIL → re-run Manager (max 1); 2nd → `--sequential` downgrade
- **Gate B** (step 8.5): 4 criteria — cross-diff conflict / duplicate import / naming collision / propagation incompleteness. FAIL → force step 9 P0 loop (max 1)
- **Dev failure gate** (step 8.7): 1 criterion — any Dev `status != success`. FAIL → Manager re-allocation (max 1); 2nd → stop + user escalation
- **Gate C** (`--auto`/`--multi-review` only): 12-lens stage split (stage 1=7 agent / stage 2=6 agent). Default `/flow` uses `comprehensive-review` + codex 2-agent mode.

## Integration rules

Required: impl → /lint-test → /review → review-fix → /git-push. 2× fail same approach → `/clear` → re-organize.

**Code comment enforcement (always-on)**: 各 developer-agent の delegation prompt に canonical `guidelines/writing/code-comment.md` 準拠 (Read 必須) を明示する。Self-Review Gate 5 (developer-agent.md) で comment 混入を目視確認する。

### Completion actions

- Save to auto-memory: `~/.claude/projects/<project>/memory/work-context-YYYYMMDD-{topic}.md`
- `--auto`: secret check → /git-push --pr → notify `[flow --auto] {topic} complete → PR created` (fail: `fail: {reason}` / lint 2×: `stop: lint-test 2× fail`)
- Normal: AskUserQuestion "push?"
- **/clear recommended (cache_read prevention)**: after /flow completes, propose `/clear` before next task (`--auto`: append `→ next task: start after /clear`)

## Auto-apply features

| Feature | Condition | Action |
|------|------|------|
| worktree isolation | Default forced; skip on `--sequential` / downgrade | `isolation: "worktree"` auto-create / cleanup |
| Post-impl verify | `--auto` complete | `/lint-test` (verify-app explicit only) |
| `IMPL_NOTES` | Team path (Dev via Task()) | Dev writes `dev-<task-id>.md` → Manager merges → parent persists `MERGED.md` under `~/.claude/plans/impl-notes/<run-dir>/`. `/git-push --pr` consumes for PR draft (`--no-impl-notes` to skip) |

worktree apply decision: `references/PARALLEL-PATTERNS.md#worktree-applicability-flow`.

ARGUMENTS: $ARGUMENTS
