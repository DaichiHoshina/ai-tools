---
allowed-tools: Read, Glob, Grep, Edit, MultiEdit, Write, Bash, Task, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*, mcp__context7__*
argument-hint: "[--inline|--quick|--plan <file>] <task-description>"
description: Default = developer-agent delegation. Inline for 1-symbol fix only. Flag detail: see Default delegation table below.
---

## /dev - Implementation mode

> When to use: `/dev` = impl phase only, no Agent Team / `/flow` = auto task-type + PO→Manager→Dev×N hierarchy. When uncertain → `/flow`.
> Agent Team **only via `/flow`**. Direct `/dev` has no Team hierarchy.

## Default delegation

On `/dev` launch, delegate to `Task(developer-agent)` by default (model canonical: `agents/developer-agent.md` frontmatter + `references/model-selection.md`).

| Flag | Behavior |
|---|---|
| (none) | `developer-agent` delegation (default) |
| `--inline` | parent inline execution (1-symbol fix only) |
| `--quick` | low-cost model delegation, token-saving priority (short prompt) |

## Options

```bash
/dev --quick <task>      # Fast mode (token-saving, 1-2 files)
/dev --parallel <task>   # Worktree parallel (no PO/Manager, developer-agent ×N)
/dev <task>              # Normal (developer-agent delegation)
/dev --plan <file>       # /plan output intake (skip re-analysis & pre-impl confirm)
# Team hierarchy + parallel needed? Use /flow --parallel
```

## Plan intake (`--plan` / auto-detect)

`/plan` の成果物を入力として受け取り、scope 再分析と実行前確認を省いて即実装に入る。

| 入力 | 動作 |
|---|---|
| `--plan <file>` | plan file を Read し、Requirements / Phase / mode 判定根拠 / worktree 判断をそのまま採用する。Execution flow 2-4 (再分析 / 再計画 / user confirm) を skip し Phase 1 から実装する |
| flag なし + 同 session で `/plan` 済 | 当該 plan を同様に採用する (plansDirectory の最新該当 file) |
| plan なし | 通常 flow (Execution flow 1-6) |

plan は SoT として扱い、mode 再判定をしない。plan と実 code の乖離 (file 消失 / symbol 改名等) を検出した場合のみ再分析に戻し、乖離内容を 1 行報告する。破壊的操作 (削除 / migration / force 系) を含む Phase は plan 有無に関わらず実行前確認する。

## --parallel spec

Launch Developer×N worktree parallel w/o PO/Manager. Parallelism eval + worktree proposal は forced、worktree creation は user confirm required。Formula / `--auto` skip 4 conditions / cleanup policy は `references/PARALLEL-PATTERNS.md` canonical を参照する。Gate A/B (parallel self-review) not applied to `/dev --parallel` (`/flow --parallel` exclusive).

## --quick (formerly /quick-fix)

Use: 1-2 files typo / small bug / few-line change. **Token-saving priority (short prompt), no Agent Team, minimal confirm**.

Flow: identify file → fix (Serena MCP) → verify (lint/type) → propose commit.

3+ files / design decision needed → normal `/dev` or `/flow`.

## Thinking mode

**Always ultrathink** — for complex impl, think deep before execute. Avoid quick fixes; understand design intent before coding.

## Step 0: Guideline loading (conditional)

**Always-on (skip 不可)**: code comment (`// ` `# ` `-- ` `/* ` `<!-- `) を新規追加/編集する場合は hook 注入の要約で判定し、迷ったときのみ canonical `guidelines/writing/code-comment.md` を Read する (`--quick` でも skip しない)。

| Scenario | Action |
|----------|--------|
| `--quick` | skip (save tokens、ただし code-comment canonical のみ Read) |
| 1-2 files, minor | skip OK (if pattern known、code-comment canonical のみ Read) |
| new feature, design decision | `load-guidelines` (summary recommended) |
| UI dev | `ui-skills` recommended |
| Backend | `backend-dev` recommended |

```
load-guidelines skill        # summary only (~2.5K tokens、Skill tool 経由)
load-guidelines skill (full) # w/ detail (~5.5K tokens、Skill tool 経由)
```

Note: `load-guidelines` は skill (`skills/load-guidelines/`) であり、slash command (`commands/load-guidelines.md` は存在しない) ではない。

Detailed mapping: `references/command-resource-map.md`.

## Execution flow

1. Load guidelines
2. Analyze code w/ Serena MCP (plan intake 時 skip)
3. Plan w/ TaskCreate (plan intake 時 = plan の Phase をそのまま登録)
4. Confirm w/ user (plan intake 時 skip、plan 承認済とみなす)
5. Implement
6. Run lint/test

## Priority

1. Type-safety (any/as forbidden)
2. Guideline compliance
3. Architecture patterns
4. Testability

## Smoke test 完了報告 template (required)

実装完了報告には smoke test 実行結果を必ず含める。CLAUDE.md `## Definition of Done` の「1 smoke test 必須」と整合し、user 側の「全部完了したか再度チェックして」churn を防ぐ。

| 状態 | 表記 | 用例 |
|---|---|---|
| 実行済 | `Smoke test: <cmd> 実行、<結果 1 行>` | `Smoke test: bats tests/unit/foo.bats 実行、12/12 pass` |
| 未実行 | `Smoke test: 未実行 (理由: <1 行>)` | `Smoke test: 未実行 (理由: GUI 起動不能で手動確認要)` |

未実行 の理由は具体化する (「時間がなかった」等の主観的理由は不可)。想定される正当理由:
- 環境不備 (test target が local で起動しない / dev server 未起動)
- GUI / TUI で自動 smoke 不能 (user 側で目視確認要)
- test target 特定不能 (broad refactor で影響 test を絞り込めない)
- 変更が config / doc のみで smoke 対象なし

理由が「変更が config / doc のみ」の場合も、変更 file 名 + `git diff --stat` の 1 行要約を添えて代替する。

## Post-impl quality checks (required)

After completion: `/lint-test` auto-detects lang + runs all checks (lint/typecheck/test/build). 0 errors → report done, else → try auto-fix.

| Scenario | Action |
|----------|--------|
| 2 consecutive same-approach failures | objective gate (test / lint exit code) を定義できるなら `/loop` を提案 (fresh context 反復は同一 context 再試行より成功率が高い)、定義できなければ suggest `/clear` & stop, request replan |
| `--quick` unexpected error | fallback to default model, continue minor fixes |
| Serena MCP fails | degrade to grep/Read, warn |

PushNotification: notify only if task > 3min (`[dev] {task} done`).

## Next actions

```
/dev done
  → /lint-test → /test → /review → /git-push
  → on error: /diagnose
```

## Related commands

| Command | Relation |
|---------|----------|
| `/refactor` | structure improvement w/o behavior change. Can run after `/dev` |
| `/lint-test` | CI-equivalent checks. Recommended after `/dev` |

**Pre-impl user confirmation required (plan intake 時は skip、破壊的操作のみ確認). Use Serena MCP for code ops.**
