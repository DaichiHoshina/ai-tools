# Auto-Delegation — Detailed Spec

Detail for CLAUDE.md `## Auto-Delegation`. CLAUDE.md keeps default declaration + cross-ref only. All thresholds / trigger table / inline exceptions are canonical here.

---

## Decision principle (top priority)

Delegate on uncertainty. Under-delegation risk > over-delegation cost. Parent handles orchestration / judgment only; all actual work (write / refactor / commit) goes to subagents (委譲先 model は各 agent frontmatter canonical、`references/model-selection.md` 参照). "If told to do it, the subagent does it" principle (per user direction 2026-05-22). Verification: parent inline default (build / typecheck required for compiled language projects goes to subagent; details: `references/developer-agent-delegation-prompt.md`).

## Time-first (top priority)

Fastest makespan wins for all routing. Always fire in parallel except physical constraints (same-file edit / result dependency). Cap default 8 (parent + Dev×8 = 9 concurrent). Adopt if makespan improvement ≥5%. When in doubt: parallel + delegate (under-parallel risk > over-parallel cost). Details: `references/PARALLEL-PATTERNS.md`

**same-file の複数独立修正を「並列不可」と早合点しない**。同一 file の別箇所を複数 agent で直列実装するのは遅い。read-only で **patch (old_string/new_string ペア) を並列生成** させ、**親が順次 apply → verify を 1 回**にまとめれば書き込み競合なしで並列化できる。worktree 分離は不要 (worktree は別 file 群を同時 mutate する時のみ)。判断を親が手動でせず迷う場合は `/flow` に委ね、Manager に並列度・分担・worktree 要否を決めさせる。

## Bundle prohibition (split obligation)

Never bundle 2+ domains (different file groups / root causes / verify systems) in 1 prompt. Fire per-domain as multiple Agent tool_use in a single message. Bundling causes sequential processing inside subagent, cumulating makespan.

### Per-agent scope cap (1 Task 詰め込み禁止)

1 Task prompt の scope 上限は file 3-5 / 観点 1-2 (CLAUDE.md 掲載値)。超えたら N Agent に分割して単一 message で並列発火する。詰め込みは context overflow で後半 file が雑になり、出力が要約化し、lens 直交性が消え、失敗時 retry cost も膨らむ。直列 chain (PO→Manager→Dev) でも各 step 内に複数 file / 観点があれば step 内で fan-out する (直列 = 単発 1 体丸投げと誤判定しない)。fire 前 self-check: (1) この prompt を agent が 1 pass で書ききれる量か — No なら分割 (2) この step 内に分割可能な単位が 2+ あるか — あれば step 内 fan-out。

### 「速さ重視」の軸確認

user が「速さ / 最速 / fast / quick」を指定したら、実装速度 (time-to-merge) / 効果速度 (KPI 改善 lead time) / response 速度 (1 turn latency) のどれかを冒頭で確定する。文脈から自明なら確認せず「実装速度重視のため X を選んだ」と軸を明示して進める。委譲は agent startup overhead (数十秒〜分) があり、実装速度の軸では単 file 微修正は inline が最速。誤解したまま進めると plan やり直しになる。

## Parallel fire format (mandatory)

For N independent tasks: **place N `Agent` tool_use calls in a single assistant message**. Repeating 1-message-1-Agent over N messages serializes on previous agent's STOP, reducing peak concurrency to 1 (formula PASS / cap 8 does not guarantee simultaneity). **The act of bundling tool_use in 1 message IS the parallelization**; cap/formula only sets the upper limit on fire count. Verify: `scripts/flow-baseline.sh --summary` `peak_concurrency distribution` — heavy 1s indicates serialization.

### Upfront decomposition (before the FIRST Task fire)

Enumerate ALL independent tasks **before firing the first developer-agent**, and include every independent task in the first bundle message. The fire-one-read-result-fire-next loop drops peak concurrency to 1 (30d measured: 10 of 22 flow runs at peak=1). Hook injects `[bundle-pre-check]` on the first dev fire as a reminder — at that point the parallelization decision for the current turn is already made, so enumeration must happen at planning time, not after.

#### `scope: i/N` declaration

- Format: write `scope: i/N` (example `scope: 2/3`) near the top of each Task prompt
- N = count of independent tasks enumerated above, i = this task's 1-based position
- N=1 (single task, no fan-out) may omit the declaration
- A false `scope: 1/1` used to hide an independent task from the bundle is forbidden
- Same abuse class as `serial_reason` misuse below
- A fire declares N≥2 but the actual bundle that turn was solo (size 1)
- The hook then warns `scope_declared_mismatch`
- Logged to `bundle-violation-warn.log` as an audit signal, not a hard block

### serial_reason declaration (dependent sequential fires)

A sequential developer-agent fire that **depends on a previous agent's output** (implement → reviewer reject → re-implement / patch apply → follow-up fix) is legitimate, not a bundle violation. Declare it by writing `serial_reason: <dependency, 1 line>` in the Task prompt. The hook excludes declared fires from the sequential counter (no warn / no hard block) and records `serial_reason_declared` in `bundle-violation-warn.log` for audit.

- Misuse ban: writing serial_reason on an independent task to dodge the counter is forbidden — independent tasks go in the bundle.
- Without the declaration, 3 cumulative sequential fires per session hard-block (PO Gate v2). Legitimate chains hitting the block was the main driver of "delegate feels slower than inline" (2026-07-04/05: 3 sessions blocked).

## Parent pre-delegation obligation

Pre-delegation 手順: `references/orchestrate-mode.md` §Pre-delegation 参照。

## Agent fire self-review (required before Task tool)

Self-check parallelization before firing Task tool. Checklist canonical: `references/PARALLEL-PATTERNS.md` (do not duplicate in CLAUDE.md). Hook auto-injects self-review reminder as additionalContext on Task fire.

## Inline exceptions (no delegation)

Q&A / already-read file check (file already Read in same session, no additional Read needed; additional Read required → count toward throttle) / dry-run / **1 symbol inside body replace** / **1 section edit** / **same-file 1 config value change** / **expected LLM execution <20s** / **read-only command 1 item** (`git status` / `ls` / `cat` / `wc -l` / etc)

**Grey zone (20–60s expected):** delegate launch floor is 22s startup (`performance-insights.md`). So a task that finishes inline in 20–60s often costs more if delegated. Rule: default inline when it is a single-file / single-symbol edit AND no commit. Delegate only when 2+ files are touched. Above 60s: delegate is clearly better.

## Inline exception throttle

2 consecutive inline exceptions in same session → next edit-class op is **mandatory** developer-agent delegation (reset counter after delegation). Investigation phase (Q&A / dry-run excluded; Read/Bash for investigation only): cumulative ≥5 → switch to `explore-agent`.

Read-only local queries (`git status` / `ls` / single `grep` / `find_symbol`) do NOT count toward this throttle. They are the cheapest, highest-frequency path, so counting them would push an `explore-agent` launch too early and add cost instead of saving it.

Note: **impl** = logic addition / new file / multi-symbol edit; **edit** = any of 2+ files, 10+ lines, or 2+ symbols; **commit-bearing** → delegate immediately (no inline commit). Violations recorded in feedback memory.

違反しやすい pattern (2026-06-04 観測): (1) new file を「軽量 housekeeping」と自己解釈して inline で Write する (2) 1 つの bash で 2+ file を触る操作 (`git mv A B && git mv C D` / `find ... -delete` 等) を inline 1 op と数える (3) 2 consecutive 到達後に counter をリセットし忘れて inline を続ける。new file と 2+ file 操作は内容を自分で書ける場合でも委譲する。各 inline op 直後に「inline 累積 N/2」を数え、2 到達で edit-class op は強制委譲にする。「全部やって」「修正して」等の口語起動 housekeeping ほど自己判定 bias が強く違反が多い。

適用境界: CLAUDE.md Auto-Delegation 表の「iteration 前提 (CI fail / fixture / test 連鎖 / review feedback) → inline 固定」に該当する task は本 throttle の対象外とする (inline 固定が優先)。throttle は単発 housekeeping / 散発 edit の連鎖にのみ適用する。

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
| **bulk / exhaustive / large-scale readonly** | `explore-agent` (read-only) or `developer-agent` (edit) — mandatory Sonnet delegate, parent sample reduction prohibited |

## Model default 切替経緯 (2026-06-29)

- 切替前: Opus 4.7 default
- 切替後: Sonnet 4.6 default
- 2026-07〜: session default = Fable 5 (`references/model-selection.md` canonical)。委譲先 model は各 agent frontmatter canonical
- 目的: cost 削減 (Opus cache_read $1.50/M → Sonnet $0.30/M、1/5)
- Opus 4.7 を使うべき task:
  - deep design (architecture 判断 / trade-off 整理)
  - 多 file 横断 review (10+ file)
  - `/flow` PO/Manager orchestration (judgment hierarchy)
  - Manager hallucination 防止が要る case
- 切替方法: `/model opus` で session 単位 (agent frontmatter は sonnet 固定のまま。manager-agent の hallucination 対策は literal echo 強制で手当済)
- 現状 (2026-07-19): 上記 Opus 4.7 用途は Fable 5 (session default) と `/fable` 委譲へ移行した。本節は経緯 log として残す (canonical: `references/model-selection.md`)

## Subagent silent-fail guard 詳細

subagent context での tool 制約:

- `AskUserQuestion` は use 不可 (parent context のみ可)
- permission prompt 系 tool (Edit / Write / Bash 一部) は auto-deny で **silent fail** する
  - error なし、status success の見た目で実際は何も書き込まれない
  - 出典: [claudefa.st sub-agent-best-practices (2026-06-24 web search)](https://claudefa.st/blog/guide/agents/sub-agent-best-practices)

### 対処

- approval-gated edit / 判断 fork は parent に escalate する
- escalate 形式: `status: blocked` + `issues_blocking[]` (具体的な block 理由 / 必要な user 判断)
- subagent 側 canonical: `agents/developer-agent.md` § Silent-fail guard
