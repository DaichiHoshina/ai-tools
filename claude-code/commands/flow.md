---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Task, AskUserQuestion, Skill, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*
description: Orchestration-first workflow — parent-led parallel fan-out (orchestrate + parallel forced)
---

## /flow - Orchestration-first workflow

**核**: `/flow` は orchestration 専用 command。parent 指揮で worktree 並列発火を強制し、makespan 最短化を最上位 KPI とする。並列化が成立しない task (file 競合 / 単一 symbol edit 等) は sequential downgrade で fallback する。

> When to use: `/flow` (orchestrated parallel pipeline) / `/dev` (single-agent impl) / `/flow-auto` (`/flow --auto` alias、全自動) / `/review-fix-push` (review-loop only)

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
--sequential  (opt-out: 物理的に並列化不能と parent 判断時のみ、PO/Manager は常時必須)
```

**Default = orchestrate + parallel 強制 ON**。素の `/flow` 起動で parent 事前準備 (N 算定 / target echo / verify echo / DoD echo) + worktree 並列発火が同時発動する。`--auto` 追加で fully autonomous mode (確認スキップ + 自動 push)。`--sequential` は file 競合等で並列化が物理不可能な場合のみ使う緊急 fallback。

## Orchestration (forced)

Parent 指揮 mode を常時強制する。pre-delegation 4 step (N 算定 / target / verify / DoD) は **内部処理**で、user 提示は 1 行要約のみ (`fan-out: N=<n>, targets=<file count>`)。詳細 echo は subagent prompt に literal 埋込、chat 出力禁止。

完了後、**1 message 内 N tool_use 並列発火** (1 message 1 Agent N message 繰返しは逐次化するため禁止)。仕様詳細: `references/orchestrate-mode.md` / `references/PARALLEL-PATTERNS.md`。

## Parallel (forced)

worktree 分離で物理並列化する。

| Item | Action |
|------|------|
| Parallelism degree eval | Forced (Manager) |
| worktree proposal | Forced (PO) |
| worktree creation | `--auto` 時 4 skip 条件で自動、それ以外は user 確認 |
| Sequential downgrade | file 競合 / 物理 conflict 検出時、または `--sequential` |

### `--auto` 4 skip conditions

1. Parallel formula PASS (式は `references/PARALLEL-PATTERNS.md#critical-path-reduction-formula` 参照、first choice `N=8`)
2. clean worktree (git status / stash both none)
3. branch/worktree name no collision
4. Creation fail → sequential downgrade + notify

### worktree cleanup

Changes present → return branch / parent merge / worktree delete. no changes → auto-delete. Collision → sequential downgrade, worktree left in place.

### `worktree.baseRef` (advanced)

Default `fresh` = base on `origin/<default>`. Set `"head"` per task in `~/.claude/settings.local.json` to carry unpushed commits to new worktree. Not recommended for regular use (main pollution risk).


## --auto fully autonomous mode (opt-in)

| Decision | Action |
|------|------|
| AskUserQuestion | Don't call, auto-adopt recommendation |
| Agent launch | `mode: "bypassPermissions"` |
| Push target | Always PR (no main direct push) |
| Design decision | Recommend, priority simple |
| lint-test fail | Auto-fix 1×, 2nd fail stop + report |

Flow: receive → judge → execute → lint-test → review-fix → secret check → /git-push → Serena memory → PushNotification.

review-fix loop: post-impl `/review` → auto-fix repeat **until Critical 0 + Warning 0** (max 3×, excess reported, continue).

## Execution logic

1. **git status check**: 変更あり → WIP 確認後 step 2 (orchestration 継続、`/dev` redirect しない)
2. **Sequential downgrade check** (`--sequential` 明示時のみ): default は downgrade しない。downgrade 時のみ `/dev` 単体委譲、PO/Manager skip
3. **PO Agent (必須)**: 設計判断 / scope 切り分け。skip 不可 (旧 `--no-po` 廃止)
4. **Manager Agent (必須)**: task 分割 / file 重複排除 / N 算定
5. **Orchestration pre-delegation** (内部処理): target / verify / DoD を subagent prompt に埋込み、user 提示は 1 行要約 (`fan-out: N=<n>`)。`mkdir -p <impl_notes.dir>` 実行
6. **Parallel fan-out**: 1 message 内 `Task(developer-agent)×N` 並列発火 (worktree 分離)
7. **Manager integrate**: 各 dev 完了報告を集約 → MERGED.md を `<impl_notes.dir>/MERGED.md` に persist
8. **Team review**: `Task(reviewer-agent, --codex)` (comprehensive + codex parallel) → P0/P1 judge
   - P0: manager realloc → developer×M fix → reviewer re-verify (**max 1 loop**)
   - P0 残 / P1: report & continue (`--auto` 時 stop)
   - codex 未配備: comprehensive single fallback
9. Post-*impl* sequential steps from Task table (review は step 8 で完了済、skip)

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
| worktree isolation | Default forced, `--sequential` / downgrade で skip | `isolation: "worktree"` auto-create / cleanup |
| Post-impl verify | `--auto` complete | `/lint-test` (verify-app explicit only) |
| `IMPL_NOTES` | Team path (Dev via Task()) | Dev writes `dev-<task-id>.md` → Manager merges → parent persists `MERGED.md` under `~/.claude/plans/impl-notes/<run-dir>/`. `/git-push --pr` consumes for PR draft (`--no-impl-notes` to skip) |

worktree apply decision: `references/PARALLEL-PATTERNS.md#worktree-applicability-flow`.

ARGUMENTS: $ARGUMENTS
