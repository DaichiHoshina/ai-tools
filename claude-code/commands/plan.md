---
allowed-tools: Read, Glob, Grep, Bash, Task, AskUserQuestion, mcp__serena__*, mcp__context7__*
description: Design & planning — strategy formulation via PO Agent (read-only)
---

## /plan - Design & planning mode

## Boundary w/ `/design-doc`

| Aspect | `/design-doc` | `/plan` |
|--------|--------------|---------|
| Primary goal | communicate **design decisions** to team | decide impl **phase breakdown** |
| Output | 12-section md (Why/comparison/failure/migration) | Phase 1/2/... + worktree needed? |
| Input | PRD or natural language | Design Doc or settled design |
| Agent | none (direct Edit) | PO Agent (for complexity) |

Large feature: both (design-doc → plan). Small fix: plan only. Detail: `references/design-phase-flow.md`.

## Step 0: Auto-load guidelines (required)

### A. Design guidelines (required)

- `~/.claude/guidelines/design/clean-architecture.md`
- `~/.claude/guidelines/design/domain-driven-design.md`

### B. Language guidelines (auto-detect via `load-guidelines`)

TypeScript → `typescript.md`, `eslint.md` / Next.js → `nextjs-react.md`, `tailwind.md`, `shadcn.md` / Go → `golang.md`.

### C. Project type

Infrastructure → `infrastructure/terraform.md`, `infrastructure/aws-eks.md`.

### D. Skill coordination

`clean-architecture-ddd` / `api-design` / `microservices-monorepo` (on detect) auto-load guidelines. Detail: `references/command-resource-map.md`.

## Step 1: Scope intake (required)

Run before any judgment:

1. **File count**: Glob / wc -l で対象 file 数と各 file 行数を把握
2. **要件未確定箇所抽出**: 各 file の編集 scope / 削除 target / 選択肢が複数ある決定点を列挙
3. **Sub 質問**: 未確定箇所が 1 件以上 → AskUserQuestion (max 3 件、各 2-4 選択肢)
4. **Skip 条件**: 要件完全明確 (single typo / 1 symbol rename / explicit instruction) → sub 質問なしで Step 2 へ

## Step 2: Execution mode judgment (required)

`inline` / `/dev` / `/workflow <template>` / `/flow N=<n>` / `/flow --auto` の 5 択を判定。判定 table:

| 条件 | 実行方式 | 理由 |
|------|---------|------|
| 1 file / 1 symbol / 数行 | **inline** (parent 直接 Edit) | agent overhead 不要 |
| 1-2 file / 単一 task / file 間結合あり | **`/dev`** (developer-agent 1 体) | 委譲のみ、並列不要 |
| 構造化 fan-out (review N lens / migrate N file / research multi-modal / understand / judge-panel) | **`/workflow <template>`** | deterministic script、resume 可、Gate なし、≤500 行 diff 向け |
| 3-5 file / 独立性高 / 各 file ≥30 行 / 機能実装 | **`/flow` N=3-5** | PO/Manager/Dev 階層 + 3 Gate、並列短縮 benefit > overhead (60s+) |
| 6+ file / 完全独立 / 機能実装 | **`/flow` N=min(file数, 8)** | 8 上限 (session limit) |
| 上記 /flow 条件 + 全自動 (PR 作成まで) | **`/flow --auto`** | AskUserQuestion auto-adopt、PR 作成自動、lint-test 自動 fix 1× |
| 3+ file / file 間結合強 or 順序依存 | **`/dev` sequential** | 並列化で conflict |
| 3+ file / 各 file 数行のみ | **inline 連続 Edit** | overhead 回収不能 |

**不向き (誤判定回避、過去 churn から導出)**:

- **inline**: 3+ file / 各 30 行以上 → context 圧迫、Sonnet 委譲が cost 効率良い
- **/dev**: 完全独立な 3+ file → 並列短縮 benefit を捨てる、`/flow` か `/workflow migrate` 検討
- **/workflow**: PRD→Plan→impl→review→push 全工程 → Gate なしで進捗管理崩れる、`/flow` 使う
- **/flow**: ≤2 file / 単一 task → 60s+ overhead 回収不能、`/dev` で十分
- **/flow --auto**: design 分岐ある / large refactor → AskUserQuestion auto-adopt が誤判定を素通り、`/flow` (手動 Gate) 使う

### /workflow vs /flow (直交軸)

| 軸 | /workflow | /flow |
|---|---|---|
| 用途 | review / migrate / research / understand / judge-panel の構造化 fan-out | 機能実装の PO/Manager/Dev 階層 orchestration |
| Gate | なし (script で自前) | 3 Gate 必須 (PO/A/B、--auto で C) |
| resume | ⭕ journal cache hit | ❌ fresh fire |
| best fit | small〜medium (≤500 行)、review / migration | medium〜large、impl 主体 (PRD→Plan→impl→test→review→push) |

判定例: review **だけ** → `/workflow review` / review→修正→push 全自動 → `/flow --auto` / migration を N file → `/workflow migrate` / 新機能実装 (PO 必要) → `/flow` / 多数決 design 案 → `/workflow judge-panel`

並列数 N 計算式 (/flow 用):

```text
N_candidate = 独立 file 数 (file 間結合度 0)
wall_clock_parallel ≈ max(T_i) + overhead(60s)
wall_clock_sequential ≈ sum(T_i)
採用条件: wall_clock_parallel < wall_clock_sequential
N_final = min(N_candidate, 8)
```

T_i 見積 = file 行数 × 編集密度 (新規 ~3s/行 / 修正 ~5s/行 / 削除 ~1s/行)

## PO Agent flow

```
Launch Task(subagent_type: "po-agent")
  → requirement analysis → architecture design → worktree necessary? (confirm) → implementation approach
  → draft design document
  → **Self-Review (required, 2-stage)** (→ `## Self-Review` section)
  → output filtered design document
  → propose next actions (to `/dev`)
```

## Direct execution flow

1. Load guidelines (Step 0)
2. Analyze codebase w/ Serena MCP
3. Draft design document
4. **Apply Self-Review 2-stage gate** (→ `## Self-Review` section)
5. Output filtered design document + propose implementation plan for `/dev`

## Self-Review (required, 2-stage)

Run 2-stage self-review **before** any `/plan` output. Skip not allowed. Applies uniformly across PO Agent / Direct execution / `--update` / `--scope` modes. Stage common definition: `commands/review.md` `## Delegation & Self-Review` section. Noise discard policy: `rules/review-noise-discard.md`.

### Stage A: plan-specific filter

Investigation discard: speculative leads / hypothetical edge cases / findings unrelated to the change.
Plan discard: compat shims / future abstractions / impossible-case error handling / non-boundary validation / scope creep / premature optimization / half-finished phases.

**判定妥当性 review (Step 2 出力に適用)**:

- inline で済むのに `/dev` 委譲していないか (1 file / 数行 / 規約 file の sub 質問 1 件以下)
- `/dev` で済むのに `/flow` していないか (file 数 < 3 / 結合強 / overhead 回収不能)
- `/flow` で組んだが実は `/workflow` で十分でないか (構造化 fan-out / PO 不要 / resume 欲しい / 小規模)
- `/workflow` で組んだが実は機能実装で `/flow` 必須でないか (impl 主体 / PRD 必要 / Gate 必須)
- 並列数 N 過剰でないか (N_candidate が結合度 0 を満たさない / wall_clock_parallel ≥ wall_clock_sequential)
- `--auto` 提案時に user 確認すべき branch point が plan に残っていないか (大規模 design 分岐 / 破壊的操作 / external 送信は `--auto` 不可)
- 持ち越し task / 別 scope task を本 plan に混入していないか (混入 → 別 task 分離)

### Stage B: plan-specific aggregate view

Phase consolidation (same root cause → 1 Phase) / granularity alignment / convention alignment / Zero-phase valid (no padding). Do not include judgment log in plan file. Only results passing both stages proceed to Output Format.

## Plan storage

Stored in `plansDirectory` (default `~/.claude/plans`).

```
~/.claude/plans/YYYY-MM-DD_[project]_[feature].md
```

Reference across sessions, load w/ `/reload`.

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
- Mode: inline / `/dev` / `/workflow <template>` / `/flow N=<n>` / `/flow --auto`
- 根拠: [file 数 / 結合度 / T_i / overhead 比較 + /workflow vs /flow 直交判定を 1 行]

## Worktree
- Needed: Yes/No
- Branch name: [propose]
```

## Priority

1. Requirement clarity
2. Architecture fit
3. Extensibility・maintainability
4. Testability

## Fail behavior

| Scenario | Action |
|------|------|
| PO Agent launch fail | Downgrade to direct, warn. Complex tasks propose requirement split |
| Guideline load fail | Continue w/ common only, design decision on maintainer |
| Serena MCP fail | Substitute w/ grep/Glob, warn precision drop |
| `plansDirectory` write fail | Chat output only, guide manual save |

**Read-only** - Implementation via `/dev`.
