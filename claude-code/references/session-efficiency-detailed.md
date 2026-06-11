# Session Efficiency — Detailed Bullets

Detail for CLAUDE.md `## Session Efficiency`. CLAUDE.md keeps pointer only.

---

- **Design decisions**: light → `Shift+Tab` Plan Mode / large → `/plan` (PO agent). **Long brainstorm → haiku separate session (`claude --model haiku`), handoff to Opus for impl**
- **Long tasks**: `/rename {type}-{scope}`, `claude --resume` (`references/session-management.md`)
- **Success-criteria principle**: focus on "what defines success" over procedural steps
- **Verify first**: post-impl run test/lint/typecheck (DoD)
- **MCP tool args: verify spec before writing**: use `ToolSearch select:<tool>` to confirm param names; do not rely on LLM autocorrect `[[hook-principles-path-bug-incident]]`
- **After regex replace, run `git diff --stat` immediately**: serena `replace_content` regex forces DOTALL/MULTILINE — `.*\n` greedy wipe risk. Single line: **literal + trailing `\n`**; multi-line: **non-greedy `.*?` + explicit end anchor**
- **Minimize confirmation / choice**: execute safe ops without prompting; apply recommended option directly for minor choices. Confirm only for: file deletion / deploy / external send / critical decisions (architecture / cost / irreversible)
- **Autonomous mode (default ON)**: execute recommended judgment without user confirmation. Echo `要決定: A/B/C` + present options + wait for user only in these cases:
  - Destructive ops (file/branch deletion / force push / DB drop / rm -rf etc.)
  - External send (PR creation / Slack / Notion / Issue / push)
  - Design branch with large trade-off (architecture change / cost impact / irreversible) **and** user cannot proceed without the information
  - Mid-flow stage where result changes the next stage's premise
  Otherwise: inline echo of recommended option + immediate execution (e.g., "proceeding with B" → execute). `A/B/C options + which do you choose?` format degrades UX for unnecessary branches. Violations recorded in feedback memory.
- **ROI gate**: even for "do everything" instructions, re-confirm individually if judgment deems low ROI
- **Bulk / exhaustive keyword**: requests containing 「全N件 / 網羅 / 一斉 / bulk / 大量」— consider Sonnet delegation first (read-only=`explore-agent` / edit=`developer-agent`) before parent Opus inline sample reduction. Reducing sample under scale/cost rationale violates "Default delegate to Sonnet" principle `[[sonnet-delegate-bulk-readonly]]`
- **pwd check**: verify existence before Read/Bash; check `pwd` before `cd`
- **Pre-delegation git status check**: before delegating to developer-agent, run `git status` + `git log --oneline -3` to check for parallel session work (untracked/modified files you did not touch, recent commits not from you). If detected: confirm with user "parallel impl found, OK to proceed?"
- **/memory-save trigger (any one condition)**: (a) commit with 3+ file changes *and* structural change (refactor / design change / hook addition) / (b) incident response (root cause identified + fixed) / (c) non-obvious investigation result (reproduction steps / measured values / traps) / (d) user feedback instructing behavior change. Simple typo fix / minor docs edit / single config toggle: not a trigger
- **Token budget (Read/Bash output)**: use `limit:` / `offset:` for large files (default ~200 lines); truncate long logs with `| head -N` / `| tail -N`. Full dump accumulates cost; prefer serena symbol read when available
- **Subagent prompt context budget**: keep delegation prompts ≤500 words with minimum necessary context. Never dump full conversation (cheap per-token subagent cost reverses at high input volume; symmetric with "Completion report budget" in `agents/developer-agent.md`)
- **Multi-clause requests: echo intent first**: requests with ≥2 plausible interpretations (≥2 sentences, multi-item, or single sentence with ambiguous referent like "X feature" / "heavy" / abstract directives) — echo `understood=X / missing=Y` + ask 1 clarifying question before acting. Trigger = interpretation branches, not sentence length
- **PR/branch scope: echo scope 1 line**: when user indicates PR/branch-unit scope ("cut out PR" / "split branch" / "scope is only X"), echo `scope=<target files/symbols/diff range> / exclude=<explicitly excluded range>` before starting. Root cause of scope-drift churn (detected in retrospective 2026-06-01)
- **/memory-save rapid-fire guard**: same session, last save within 5 min → prefer diff-append over new memory
- **/review-fix-push pre-launch diff echo**: `git diff --stat | tail -1` one-liner before invoke; surfaces runaway diffs
- **Large-repo session split**: hard reset (`/clear` or new session) at task boundary; never carry session past 1 task / `$_TH_SESSION_AGE_S` sec elapsed / `$_TH_SESSION_MSG` msg / 40% context (whichever first). Canonical values: `hooks/lib/thresholds.sh`. 1 task = 1 session in large repos
- **Long answers: lead with conclusion**: for chat responses of 5+ lines with lists, **put conclusion on line 1**. Violation triggers "so what?" re-question
- **Long output = PREP structure**: 5+ lines + multiple items → **P**oint→**R**eason→**E**xample→**P**oint. No abstract words (axis/layer/foundation → specific actions). Details: `guidelines/writing/PRINCIPLES.md` PREP section
- **Decision requests: decision frame first**: responses asking user to decide (ends with `?` + includes A/B / option 1/2 / Yes/No / which) → put `要決定: <option frame> / <count>` on line 1. No length threshold (apply even for 3 lines). Violation triggers "what does this mean?" re-question (root cause: conclusion line says "investigation result" while decision buried at end). Details: `guidelines/writing/PRINCIPLES.md` decision-frame-first section
