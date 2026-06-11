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
- **Direct**: `/dev` (review = `/review` = comprehensive-review skill). Sub-agents cannot spawn; parent launches each tier.

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
| 8 | データ分析, analysis, SQL | Analysis | Skill(data-analysis) → /docs → /git-push --pr |
| 9 | インフラ, terraform, k8s, IaC | Infrastructure | /plan → Skill(terraform) → /lint-test → /git-push --pr |
| 10 | 調査のみ, 診断, troubleshoot | Investigation (read-only) | /diagnose → /docs |
| 11 | その他 | New feature (default) | |

Boundary: "fix from error log"=1.5 / "bug root cause"=2 / "feature improvement"=7 (struct only=4) / "investigate & fix error"=3.

## Options

```text
--skip-prd / --skip-test / --skip-review / --auto
--sequential  (opt-out: only when parent judges parallelism physically impossible; PO/Manager always required)
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
7. **Parallel fan-out**: fire `Task(developer-agent)×N` in 1 message (worktree isolated; N=1 sequential path confirmed at step 5). **Bundle required** (operational spec of L50): bundle all N Tasks in the message immediately after fan-out declaration (N≥2). Splitting into 1-per-message creates sequential chain firing (parentUuid serial) — violates "repeating 1 message 1 Agent N times is sequential" (L50). N declaration : tool_use firing message = 1:1 strict
8. **Manager integrate**: aggregate dev completion reports → persist MERGED.md at `<impl_notes.dir>/MERGED.md`
9. **Team review**: `Task(reviewer-agent, --codex)` (comprehensive + codex parallel) → P0/P1 judge
   - P0: manager realloc → developer×M fix → reviewer re-verify (**max 1 loop**)
   - P0 remains / P1: report & continue (stop when `--auto`)
   - codex not configured: comprehensive single fallback
10. Post-*impl* sequential steps from Task table (review done at step 9, skip)

## Integration rules

- Required: impl → /lint-test → /review → review-fix → /git-push
- 2× fail rule: 2× fail with same approach → `/clear` → re-organize

### Completion actions

- Save Serena memory (`work-context-YYYYMMDD-{topic}`)
- `--auto`: secret check → /git-push --pr → PushNotification
- Normal: AskUserQuestion "push?"

### PushNotification (--auto)

- Success: `[flow-auto] {topic} complete → PR created`
- Fail: `[flow-auto] {topic} fail: {reason}`
- lint-test 2× fail: `[flow-auto] {topic} stop: lint-test 2× fail`

## Auto-apply features

| Feature | Condition | Action |
|------|------|------|
| worktree isolation | Default forced; skip on `--sequential` / downgrade | `isolation: "worktree"` auto-create / cleanup |
| Post-impl verify | `--auto` complete | `/lint-test` (verify-app explicit only) |
| `IMPL_NOTES` | Team path (Dev via Task()) | Dev writes `dev-<task-id>.md` → Manager merges → parent persists `MERGED.md` under `~/.claude/plans/impl-notes/<run-dir>/`. `/git-push --pr` consumes for PR draft (`--no-impl-notes` to skip) |

worktree apply decision: `references/PARALLEL-PATTERNS.md#worktree-applicability-flow`.

ARGUMENTS: $ARGUMENTS
