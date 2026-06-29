# Auto-Delegation — Detailed Spec

Detail for CLAUDE.md `## Auto-Delegation`. CLAUDE.md keeps default declaration + cross-ref only. All thresholds / trigger table / inline exceptions are canonical here.

---

## Decision principle (top priority)

Delegate on uncertainty. Under-delegation risk > over-delegation cost. Opus parent handles orchestration / judgment only; all actual work (write / refactor / commit) goes to Sonnet. "If told to do it, Sonnet does it" principle (per user direction 2026-05-22). Verification: parent inline default (build / typecheck required for compiled language projects goes to subagent; details: `references/developer-agent-delegation-prompt.md`).

## Time-first (top priority)

Fastest makespan wins for all routing. Always fire in parallel except physical constraints (same-file edit / result dependency). Cap default 8 (parent + Dev×8 = 9 concurrent). Adopt if makespan improvement ≥5%. When in doubt: parallel + delegate (under-parallel risk > over-parallel cost). Details: `references/PARALLEL-PATTERNS.md`

**same-file の複数独立修正を「並列不可」と早合点しない**。同一 file の別箇所を複数 agent で直列実装するのは遅い。read-only で **patch (old_string/new_string ペア) を並列生成** させ、**親が順次 apply → verify を 1 回**にまとめれば書き込み競合なしで並列化できる。worktree 分離は不要 (worktree は別 file 群を同時 mutate する時のみ)。判断を親が手動でせず迷う場合は `/flow` に委ね、Manager に並列度・分担・worktree 要否を決めさせる (`[[feedback-samefile-patch-parallel-2026-06-14]]`)。

## Bundle prohibition (split obligation)

Never bundle 2+ domains (different file groups / root causes / verify systems) in 1 prompt. Fire per-domain as multiple Agent tool_use in a single message. Bundling causes sequential processing inside subagent, cumulating makespan `[[parallel-brushup-makespan-2026-05-31]]`.

## Parallel fire format (mandatory)

For N independent tasks: **place N `Agent` tool_use calls in a single assistant message**. Repeating 1-message-1-Agent over N messages serializes on previous agent's STOP, reducing peak concurrency to 1 (formula PASS / cap 8 does not guarantee simultaneity `[[parallel-fire-format-peak-concurrency]]`). **The act of bundling tool_use in 1 message IS the parallelization**; cap/formula only sets the upper limit on fire count. Verify: `scripts/flow-baseline.sh --summary` `peak_concurrency distribution` — heavy 1s indicates serialization.

## Parent pre-delegation obligation

Before delegating, parent must: (a) identify target `file:line` (`find_symbol` / `grep`) (b) finalize verify command (c) condense DoD to 1 line. Do not push exploration to subagent (exploration phase dominates makespan). Prompts without explicit targets trigger full-repo scans.

**Branch name per dev (mandatory for wt parallel):** When firing N≥2 developer-agents with `isolation: "worktree"`, assign each dev a unique branch name in the delegation prompt. Include `branch: feature/<name>` as a literal in §1. Without explicit branch assignment, agents may share branches and produce cross-scope commits.

**Dedup before fan-out:** before firing N agents, merge query lines that target the same file group or the same symbol set into 1 agent. Parallelism = count of *distinct* domains, not raw query count. Each extra agent adds a full LLM run (explore-agent avg 123s), so a redundant launch is pure waste. Never merge genuinely independent domains and never drop below 1.

## Agent fire self-review (required before Task tool)

Self-check parallelization before firing Task tool. Checklist canonical: `references/PARALLEL-PATTERNS.md` (do not duplicate in CLAUDE.md). Hook auto-injects self-review reminder as additionalContext on Task fire.

## Inline exceptions (no delegation)

Q&A / already-read file check (file already Read in same session, no additional Read needed; additional Read required → count toward throttle) / dry-run / **1 symbol inside body replace** / **1 section edit** / **same-file 1 config value change** / **expected LLM execution <20s** / **read-only command 1 item** (`git status` / `ls` / `cat` / `wc -l` / etc)

**Grey zone (20–60s expected):** delegate launch floor is 22s startup (`performance-insights.md`). So a task that finishes inline in 20–60s often costs more if delegated. Rule: default inline when it is a single-file / single-symbol edit AND no commit. Delegate only when 2+ files are touched. Above 60s: delegate is clearly better.

## Inline exception throttle

2 consecutive inline exceptions in same session → next edit-class op is **mandatory** developer-agent delegation (reset counter after delegation). Investigation phase (Q&A / dry-run excluded; Read/Bash for investigation only): cumulative ≥5 → switch to `explore-agent`.

Read-only local queries (`git status` / `ls` / single `grep` / `find_symbol`) do NOT count toward this throttle. They are the cheapest, highest-frequency path, so counting them would push an `explore-agent` launch too early and add cost instead of saving it.

Note: **impl** = logic addition / new file / multi-symbol edit; **edit** = any of 2+ files, 10+ lines, or 2+ symbols; **commit-bearing** → delegate immediately (no inline commit). Violations recorded in feedback memory.

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
| **bulk / exhaustive / large-scale readonly** | `explore-agent` (read-only) or `developer-agent` (edit) — mandatory Sonnet delegate, parent Opus sample reduction prohibited |

## Model default 切替経緯 (2026-06-29)

- 切替前: Opus 4.7 default
- 切替後: Sonnet 4.6 default
- 目的: cost 削減 (Opus cache_read $1.50/M → Sonnet $0.30/M、1/5)
- Opus 4.7 を使うべき task:
  - deep design (architecture 判断 / trade-off 整理)
  - 多 file 横断 review (10+ file)
  - `/flow` PO/Manager orchestration (judgment hierarchy)
  - Manager hallucination 防止が要る case
- 切替方法: `/model opus` で session 単位

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
