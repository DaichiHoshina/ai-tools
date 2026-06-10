# Auto-Delegation — 詳細仕様

CLAUDE.md `## Auto-Delegation` section の本文詳細。CLAUDE.md には default 宣言 1 行 + cross-ref pointer のみ残す。threshold / trigger table / inline exceptions はすべて本 file が canonical。

---

## Decision principle (top priority)

Delegate on uncertainty. Under-delegation risk > over-delegation cost. Opus parent handles orchestration / judgment only; all actual work (write / refactor / commit) goes to Sonnet. Verification: parent inline default (build / typecheck 必須 language project は subagent 側、詳細 `references/developer-agent-delegation-prompt.md`)。

## Time-first (top priority)

最速 makespan を選ぶことが全 routing の上位原則。並列禁止 case (物理制約: 同一 file edit / 結果依存) 以外は常に並列発火、cap default 8 (parent + Dev×8 = 9 concurrent)、makespan 5% 以上短縮見込みなら採用。迷ったら並列+委譲 (under-parallel risk > over-parallel cost)。詳細: `references/PARALLEL-PATTERNS.md`

## 委譲分割義務 (束ね禁止)

1 prompt に 2+ domain (異 file group / 異 root cause / 異 verify 系) を束ねず、domain 別に 単一 message 内 複数 Agent tool_use で並列発火する。束ねは subagent 内逐次処理で makespan 累積 `[[parallel-brushup-makespan-2026-05-31]]`。

## 並列発火書式 (強制)

独立 task を N 個流す時は **1 つの assistant message 内に N 個の `Agent` tool_use を同時に置く**。1 message 1 Agent を N message 繰り返すと前 agent の STOP 待ち逐次化し、peak concurrency=1 に落ちる (formula PASS / cap 8 を満たしても同時並列は発生しない `[[parallel-fire-format-peak-concurrency]]`)。**「並列で流す」と判断した瞬間、tool_use を 1 message に束ねること自体が並列化の実体**であり、cap / formula は発火数の上限を決めるだけで同時性は保証しない。検証: `scripts/flow-baseline.sh --summary` の `peak_concurrency distribution` が 1 偏重なら逐次化の兆候。

## parent 事前準備義務

委譲前 parent が (a) target `file:line` 特定 (`find_symbol` / `grep`) (b) verify コマンド確定 (c) DoD 1 行化 を完了する。subagent に探索を投げない (探索 phase が makespan 支配要因)。target 不明示の prompt は full repo scan を誘発する。

## Agent 発火直前 self-review 必須

Task tool 発火の直前に並列化判定を自己確認する。判定 checklist は `references/PARALLEL-PATTERNS.md` を canonical 参照とする (CLAUDE.md に重複コピーしない)。hook が Task 発火時に self-review reminder を additionalContext として自動 inject する。

## Inline exceptions (no delegation)

Q&A / already-read file check (同一 session で既に Read 完了した file への Q&A、追加 Read なし; 追加 Read 必要なら throttle count 算入) / dry-run / **1 symbol inside body replace** / **1 section edit** / **same-file 1 config value change** / **expected LLM execution <20s** / **read-only command 1 item** (`git status` / `ls` / `cat` / `wc -l` / etc)

## Inline exception throttle

2 consecutive inline exceptions in same session → next edit-class op is **mandatory** developer-agent delegation (reset counter after delegation). Investigation phase (Q&A / dry-run を除く調査専用 Read/Bash): 累積 ≥5 → switch subsequent investigation to `explore-agent`.

Note: **impl** = logic addition / new file / multi-symbol edit; **edit** = any of 2+ files, 10+ lines, or 2+ symbols; **commit-bearing** も即委譲 (commit を伴う inline 実行禁止)。違反は feedback memory 記録。

## Auto-launch trigger table

| Trigger | Auto-launch |
|---|---|
| **All impl / edit / commit outside exceptions above** | `developer-agent` auto (`Task` tool) |
| broad search (3+ query / 3+ domain) | `explore-agent` parallel auto |
| review request / PR check | `reviewer-agent` auto (or `/review`) |
| unknown bug cause / recurring bug | `root-cause-analyzer` auto |
| design decision / large plan / multi-phase | `po-agent` auto (or `/plan`) |
| multi-stage task (investigate→design→impl→verify) | `/flow` hierarchy (PO→Manager→Dev→Reviewer) |
| 10+ file bulk processing | `claude -p` fan-out (`references/fanout-recipes.md`) |
| **網羅 / 全件 / 一斉 / bulk / 大量 file readonly** | `explore-agent` (read-only) or `developer-agent` (edit) Sonnet 委譲必須、parent Opus sample 縮小禁止 |
