---
allowed-tools: Read, Glob, Grep, Bash, Task, AskUserQuestion, mcp__serena__*, mcp__context7__*
argument-hint: "[--go] <task-or-scope>"
description: Design & planning — strategy formulation via PO Agent (read-only, --go chains into impl)
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
4. **Sub question (exception only)**: AskUserQuestion (**max 1**、plan 特化の絞り込み。全体 canonical は max 2 = `rules/minimize-questions.md`) は scope input 完全欠落 / 2 推奨拮抗 / 破壊的操作・既存方針との明確衝突、のいずれかでのみ発火する
5. **Skip condition (→ Step 2 直行)**: typo / 1 symbol rename / 1-2 file edit / 明示指示 / 推奨 1 件確定 → no question

## Step 2: Execution mode judgment (required)

Choose from these options: `inline` / `/dev` / `/workflow <template>` (7 template: review / migrate / research / understand / judge-panel / scan / loop-until-dry) / `/flow N=<n>` / `/flow --auto` / `/goal "<stop>"` / `/loop`. `/goal` is orthogonal (iterative objective-gate tasks only; combinable as `/goal --inner /dev` etc.). `/loop` covers cadence / unattended / >5-iteration variants of the same objective-gate tasks (external headless loop).

| Condition | Mode | Why |
|------|---------|------|
| 1 file / 1 symbol / few lines | **inline** (parent Edit direct) | no agent overhead |
| 1-2 files / single task / cross-file coupling | **`/dev`** (1 developer-agent) | delegate only, no parallel |
| review N lens 並列 (diff lens 分割 / adversarial verify) | **`/workflow review`** | dimensions → find → verify pipeline |
| N file 一括 migrate (pattern → replacement) | **`/workflow migrate <pattern> <replacement>`** | discover → transform (worktree isolation) → verify |
| research (topic を N 角度 fan-out + 出典付き synthesize) | **`/workflow research <topic>`** | angles → deep-read top hits → cited report |
| N subsystem 一括理解 (entry / deps / data flow map) | **`/workflow understand`** | 並列 map、structured 返却 |
| 設計案 majority-vote (N 案 draft → judge score → winner + graft) | **`/workflow judge-panel`** | 独立 N draft、多数決 |
| repo-scale rule sweep (静的 rule → file:line:rule-id 単位で triage) | **`/workflow scan`** | 決定的 rule engine + agent triage |
| 発掘系 (件数不明) — bug sweep / issue 発掘 / edge case 全数 | **`/workflow loop-until-dry <task>`** | seen set dedupe + K round dry 停止 (`references/loop-engineering.md` § dedupe vs seen) |
| 3-5 files / high independence / ≥30 lines each / feature impl | **`/flow` N=3-5** | PO/Manager/Dev + 3 Gates, parallel benefit > overhead (60s+) |
| 6+ files / fully independent / feature impl | **`/flow` N=min(file count, 8)** | cap at 8 (session limit) |
| above /flow conditions + fully auto (through PR) | **`/flow --auto`** | AskUserQuestion auto-adopt, auto PR, auto lint-test fix 1× |
| 3+ files / strong cross-file coupling or order dependency | **`/dev` sequential** | parallelism causes conflict |
| 3+ files / only few lines each | **inline consecutive Edit** | overhead unrecoverable |
| iterative + objective gate (test / lint / build exit code) for done | **`/goal "<stop>"`** | maker-checker separation + iteration, Ralph Wiggum guard |
| cadence / unattended / >5 iter + objective gate | **`/loop`** (external headless loop) | fresh context per iteration, no context rot / goal drift |

**`/goal` 4 conditions** (all required; canonical: `commands/goal.md`): iterative task / automated stop-condition (exit code) / token budget absorbs N iter waste / agent holds senior tools (Bash/Edit/Task)

**Anti-patterns**: canonical `references/auto-delegation-detailed.md` 参照。

### /workflow vs /flow

Comparison table canonical: `commands/workflow.md` § /workflow vs /flow.

Decision examples: review **only** → `/workflow review` / review→fix→push auto → `/flow --auto` / migrate N files → `/workflow migrate` / new feature (PO needed) → `/flow` / design majority-vote → `/workflow judge-panel` / 発掘系 (件数不明) → `/workflow loop-until-dry`

N formula (/flow): canonical = `references/PARALLEL-PATTERNS.md#critical-path-reduction-formula`。LPT_makespan + overhead(N) と T_i 見積 4 段優先順を canonical 参照する。旧 `max(T_i) + 60s` 簡略式は overhead(N) と桁が異なるため使わない。

## Self-Review (required, 2-stage)

Run before any `/plan` output. Cannot skip. Applies uniformly across PO Agent / Direct / `--update` / `--scope` modes. Stage common definition (Stage A plan-specific filter + Stage B aggregate view を含む): `commands/review.md` `## Delegation & Self-Review`. Noise discard: `references/on-demand-rules/review-noise-discard.md`.

## Step 3: Handoff to implementation (required)

Plan 保存後、実装への受け渡しを必ず行う。判定 mode を user が手で組み立て直す状態を残さない。

1. **Next command block を必ず出力**: Step 2 の判定 mode を、plan file path 込みで copy-paste 可能な 1 行にする (例: `/dev --plan ~/.claude/plans/2026-07-05_ai-tools_foo.md` / `/flow N=3 --plan <path>` / `/loop` 判定時は `/loop init <name> "<objective>" --gate "<cmd>"` → `/loop run <name>` の 2 行 / inline 判定時は「このまま実装を指示すれば inline で開始する」の 1 行)
2. **引き継ぐ context**: Requirements / Phase 分割 / mode 判定根拠 / worktree 判断を plan file に閉じる。実装側は plan を SoT として読み、scope 再調査と mode 再判定をしない
3. **`--go` flag**: `/plan --go <task>` は plan 出力 + 保存後、そのまま判定 mode で実装を開始する (Next command を自分で発火、user 確認なし)。破壊的操作 (削除 / migration / force 系) を含む Phase のみ実行前確認に戻す
4. **pending-improvements 消化の同時反映**: task が `memory/pending-improvements.md` の Pending 由来なら、実装完了 turn で該当 entry を Completed へ移す。放置すると実装済 item を後日再設計しかける (2026-07-20 pending B で実績)

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
- Mode: inline / `/dev` / `/workflow <template>` / `/flow N=<n>` / `/flow --auto` / `/goal "<stop>"` / `/loop`
- Basis: [file count / coupling / T_i / overhead comparison + /workflow vs /flow orthogonal judgment + (if /goal or /loop) 4 conditions and stop-condition cmd in 1 line]
- (if /goal only) Stop-condition: [`bats tests/foo` / `npm run lint` etc. exit code as verdict cmd], Hard stops: max-iter=5 / max-token=100000 / timeout=30m
- (if /loop only) Gate cmd + hard stops: max-iter=10 / cost $5 / 60m (canonical: `commands/loop.md`)

## Worktree
- Needed: Yes/No
- Branch name: [propose]

## Next command
[copy-paste 可能な 1 行: `/dev --plan <plan-file>` / `/flow N=<n> --plan <plan-file>` 等]
```

## Plan storage

Save to `plansDirectory` (default `~/.claude/plans`) as `YYYY-MM-DD_[project]_[feature].md`. Loadable via `/reload`.

## Fail behavior

PO Agent launch fail → direct downgrade + warn (complex 時は requirement split 提案) / Guideline load fail → common のみで継続、maintainer 判断 / Serena MCP fail → grep/Glob 代替 + 精度低下 warn / `plansDirectory` write fail → chat 出力のみ + manual save 誘導

**Read-only** (default) — 実装は Step 3 の Next command 経由で開始する。`--go` 指定時のみ plan 確定後にそのまま実装へ continue する。
