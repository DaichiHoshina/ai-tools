---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Task, AskUserQuestion, Skill, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*
description: Workflow automation — auto-detect task type, execute optimal workflow
---

## /flow - Automated workflow execution

> When to use: `/flow` (recommended) / `/dev` (impl only) / `/groove` (YAML-defined, compare `references/flow-vs-groove.md`)

Describe task once, auto-execute optimal workflow.

## Task type detection

Match keywords top-down, **adopt priority of first hit**. If mixed, ask user.

Legend: `*impl*` = expanded by PO decision. Team path `/review` → `Task(reviewer-agent)` replacement.

- **Team use**: parent spawns `Task(po-agent)` → `Task(manager-agent)` → `Task(developer-agent)×N` parallel → manager aggregate → `Task(reviewer-agent)` → if P0 found, re-fix 1 loop
- **Direct exec**: `/dev` (review = `/review` = comprehensive-review skill)
- sub-agents cannot spawn, parent launches each tier sequentially

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
--skip-prd / --skip-test / --skip-review / --no-po / --interactive / --auto / --parallel
```

## --parallel

Team path forces worktree parallel eval. Formula detail: `references/PARALLEL-PATTERNS.md`.

| Item | Action |
|------|------|
| Parallelism degree eval | Forced (Manager required) |
| worktree proposal | Forced (PO required) |
| worktree creation | PO user confirm required |

### `--parallel --auto` 4 skip conditions

1. Team formula PASS (`LPT_makespan + 180 + 21N < sum × 0.7`, first candidate `N=4 + T_task>147s`)
2. clean worktree (git status / stash both none)
3. branch/worktree name no collision
4. Creation fail → sequential downgrade + notify

### worktree cleanup

Changes present → return branch・parent merge・worktree delete / no changes → auto-delete / collision → sequential downgrade・worktree left in place.

### `worktree.baseRef` setting (advanced use case)

Default `fresh` (`origin/<default>` base) adopted = worktree create on clean main. Specify `"head"` per task in `~/.claude/settings.local.json` to bring unpushed commits to new worktree (only when need to branch from in-progress). Not recommended for regular use (main pollution risk).

## --auto fully autonomous mode

| Decision | Action |
|------|------|
| AskUserQuestion | Don't call, auto-adopt recommendation |
| Agent launch | `mode: "bypassPermissions"` |
| Push target | Always PR (no main direct push) |
| PO Agent | Skip (`--no-po` equivalent) |
| Design decision | Recommend・priority simple |
| lint-test fail | Auto-fix 1×, 2nd fail stop・report |

Flow: receive → judge → execute → lint-test → review-fix → secret check → /git-push → Serena memory → PushNotification.

review-fix loop: post-impl `/review` → auto-fix repeat **until Critical 0 + Warning 0** (max 3×, excess reported, continue).

## Execution logic

1. Check git status: changes present → from `/dev`, none → from start
2. **Pre-check lightweight task** (skip on `--parallel`/`--no-po`): all of the following → delegate to `/dev --quick`, else next
   - 編集対象ファイル想定 ≤ 2
   - 既存ファイル内変更のみ (新規ファイル作成なし)
   - 単一レイヤ完結 (UI/API/DB 等を跨がない)
   - 公開 API / 型シグネチャ変更なし
   - 並行 / 並列性に関わる変更なし
   - user が明示的に Team / 並列を求めていない
   いずれか不成立 → PO Agent 起動
3. Launch PO Agent (skip on `--no-po`)
4. Impl branch: Team use → manager → developer×N → manager integrate / direct → `/dev`
5. **Team review**: `Task(reviewer-agent, --codex)` fixed (comprehensive + codex parallel, common notes priority) → P0/P1 judge
   - P0 present: manager realloc → developer×M fix → reviewer re-verify (**max 1 loop**)
   - P0 remains after 1 loop or P1: report & continue (stop on `--auto`)
   - codex not deployed: comprehensive single fallback
6. Execute sequentially post-*impl* from table (Team's `/review` complete at Step 5, skip)

## Bug fix complexity

| Level | Example | Flow |
|-------|-----|-------|
| Low | Typo | /diagnose → *impl* → /lint-test → /review → /git-push --pr |
| Medium | Logic bug | /diagnose → Skill(root-cause) → *impl* → /lint-test → /review → /git-push --pr |
| High | Race/Security | /diagnose → Task(root-cause-analyzer) → *impl* → /lint-test → /review → /git-push --pr |

## Integration rules

- Required: impl → /lint-test → /review → review-fix → /git-push
- 2× fail rule: 2× fail w/ same approach → `/clear` → re-organize

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
| worktree isolation | `--parallel` or `--auto` independent parallel | `isolation: "worktree"` auto-create・cleanup |
| `/simplify` | Post-impl | Bundle fast execute |
| Post-impl verify | `--auto` complete | `/lint-test` (verify-app explicit only) |

worktree apply decision: `references/PARALLEL-PATTERNS.md#worktree-apply-judgment-flow`.

ARGUMENTS: $ARGUMENTS
