---
allowed-tools: Workflow, Read, Glob, Grep, Bash, AskUserQuestion, TaskCreate, TaskUpdate, TaskList
description: Workflow tool で deterministic な fan-out / pipeline / 多数決を 1 発火する軽量 orchestrator
---

## /workflow - Workflow-tool deterministic orchestration

**Core**: Claude Code native の `Workflow` tool を直叩きする軽量 command。`/flow` の重量 orchestration (PO/Manager/Dev 階層 + 3 Gate) と直交し、**deterministic な fan-out / pipeline / 多数決 / loop-until-dry** を 1 script で書き切る用途。

> When to use: `/workflow` (短〜中、deterministic、resume 可) / `/flow` (重い orchestration、PO Gate / Manager 含む) / `/dev` (単発 impl)

### `/flow` との使い分け

| 軸 | /workflow | /flow |
|---|---|---|
| 用途 | review・research・migrate 等の **構造化 fan-out** | 機能実装の **PO→Manager→Dev** 階層 orchestration |
| Gate | なし (script で自前検証) | 3 Gate 必須 (A/B/C) |
| resume | journal 経由で同一 prompt cache hit | 不可 (各 Agent fresh fire) |
| token budget | `budget.remaining()` で動的 scale | formula で N_chosen 算出 |
| best fit diff size | small〜medium (≤500 行) | medium〜large、impl 主体 |

混在時の判断:
- review **だけ** 並列したい → `/workflow review`
- review **後に PR 作成まで自動化** → `/flow --auto`
- migration を N file に fan-out → `/workflow migrate`
- 新機能実装 (PO 必要) → `/flow`

## Templates (5 種)

各テンプレは `Workflow` tool に script を inline 渡しする。引数 = `args` 経由。

### 1. review (canonical example、公式 best practice)

dimensions → find → adversarially verify pipeline。pipeline default (barrier なし)、verify は finding 単位で fire。

```javascript
export const meta = {
  name: 'review-changes',
  description: 'Review changed files across dimensions, verify each finding',
  phases: [{ title: 'Review' }, { title: 'Verify' }],
}
const DIMS = [
  { key: 'bugs', prompt: '...' },
  { key: 'perf', prompt: '...' },
  { key: 'security', prompt: '...' },
]
const results = await pipeline(DIMS,
  d => agent(d.prompt, { phase: 'Review', schema: FINDINGS_SCHEMA }),
  rev => parallel(rev.findings.map(f => () =>
    agent(`Adversarially verify: ${f.title}`, { phase: 'Verify', schema: VERDICT_SCHEMA })
      .then(v => ({ ...f, verdict: v }))
  ))
)
return { confirmed: results.flat().filter(Boolean).filter(f => f.verdict?.isReal) }
```

### 2. migrate (worktree isolation 必須)

discover sites → transform each → verify。同一 file の並列改変は worktree 隔離で衝突回避。

```javascript
phase('Discover')
const sites = await agent('Find all <pattern> usage sites', { schema: SITES_SCHEMA })
phase('Transform')
const fixed = await parallel(sites.items.map(s => () =>
  agent(`Migrate ${s.file}:${s.line} from X to Y`, { isolation: 'worktree' })
))
return { migrated: fixed.filter(Boolean).length }
```

### 3. research (multi-modal sweep)

異なる search angle で並列 fan-out → deep-read → synthesize。1 sweep で漏れる failure mode をカバー。

```javascript
const ANGLES = ['by-container', 'by-content', 'by-entity', 'by-time']
const hits = (await parallel(ANGLES.map(a => () =>
  agent(`Search ${args.topic} via ${a}`, { schema: HITS_SCHEMA })))).filter(Boolean)
const deep = await parallel(hits.flatMap(h => h.urls.slice(0, 3)).map(u => () =>
  agent(`Deep read: ${u}`, { schema: SUMMARY_SCHEMA })))
return await agent(`Synthesize cited report from: ${JSON.stringify(deep)}`, { schema: REPORT_SCHEMA })
```

### 4. understand (subsystem map)

複数 subsystem を並列に読み込んで構造化 map を得る。/flow より軽い codebase 把握。

```javascript
const SUBSYS = ['auth', 'api', 'db', 'ui']
const maps = await parallel(SUBSYS.map(s => () =>
  agent(`Map ${s} subsystem: entry points / dependencies / data flow`, { schema: MAP_SCHEMA })))
return { systems: maps.filter(Boolean) }
```

### 5. judge-panel (N independent approaches + 多数決)

3-5 個の design approach を独立生成 → judge agent で scoring → winner 採用 + runner-up の良案 graft。

```javascript
const ANGLES = ['MVP-first', 'risk-first', 'user-first']
const drafts = await parallel(ANGLES.map(a => () =>
  agent(`Design ${args.feature} from ${a} angle`, { schema: DESIGN_SCHEMA })))
const scored = await parallel(drafts.filter(Boolean).map(d => () =>
  agent(`Score this design: ${JSON.stringify(d)}`, { schema: SCORE_SCHEMA })))
const winner = scored.reduce((a, b) => a.score > b.score ? a : b)
return await agent(`Synthesize final from winner + graft top runner-up ideas: ${JSON.stringify(scored)}`,
  { schema: FINAL_SCHEMA })
```

## 起動 spec

ユーザー入力例:
- `/workflow review` (target diff = git diff HEAD~1..HEAD、dimensions = default 3)
- `/workflow research <topic>` (args.topic = 残り引数全体)
- `/workflow migrate <pattern> <replacement>` (args.pattern / args.replacement)

parent (Opus) の責務:
1. テンプレ選択 (上記 5 から match)
2. `args` 構築 (ユーザー入力を JSON value で渡す、stringified array 禁止)
3. `Workflow({ script: ..., args: ... })` を 1 発火
4. 完了通知 (`<task-notification>`) を受けて結果を user に prose 1-3 行で要約

### token budget

ユーザーが `+500k` 等を指定した場合は `budget.remaining()` で動的 scale (例: while loop の打ち止め条件)。指定なしは `budget.total = null` のため、テンプレ内の static N (`SUBSYS.length` 等) で抑える。

### isolation 判断

worktree isolation (`isolation: 'worktree'`) は **同一 file への並列改変**時のみ。read-only / 別 file 書きでは不要 (setup overhead 200-500ms + disk 消費)。`migrate` テンプレでのみ default ON。

## 制約

- subagent_type 既定は workflow native subagent。`agentType: 'explore-agent'` 等で ai-tools 既存 agent も指定可
- `Workflow` tool 本体の barrier vs pipeline 判断は [Workflow tool description] の "DEFAULT TO pipeline()" を遵守
- 1 message bundle 制約 (`[[parallel-fire-format-peak-concurrency]]`) は **`/flow` 専用**。Workflow tool 内部 fan-out は別系統 (peak は tool 側 cap)
- `nested workflow()` は 1 level のみ。深さ制限あり

ARGUMENTS: $ARGUMENTS
