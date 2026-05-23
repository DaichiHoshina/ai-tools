# claude-code Directory Config

**Respond in genshijin mode (normal).** No keigo, taigen-dome, minimal particles, preserve technical terms. Plain JP only for destructive-action confirmations.

`~/ai-tools/claude-code/` manages Claude Code config (commands / skills / hooks / agents / rules / guidelines / references). Synced to `~/.claude/` via `sync.sh`.

## Editing Rule (data-loss guard)

- **Always edit source `~/ai-tools/claude-code/`. `~/.claude/` direct edits are wiped by `sync.sh to-local`** (applies to CLAUDE.md / commands / skills / hooks / agents / rules / guidelines / config / references)
- 🔒 PROTECTED SECTION in CLAUDE.md must not be modified. YAML frontmatter must remain valid
- `VERSION` / `SERENA_VERSION` bumped only on CLI / Serena release intake (`/claude-update-fix` / `/serena-update-fix`)
- Claude Code は **stable channel** 運用、`/claude-update-fix` TARGET は `dist-tags.stable`、`latest` tag 採用禁止 (詳細 `commands/claude-update-fix.md`)

## Definition File Token Saving

`.md` in commands/, skills/, agents/ consume tokens every session. Keep: decision tables, workflow defs, operation guards, prohibitions, 1 example. Remove: sample impl, duplicate explanations, detailed usage. Target: agent ≤300 / command ≤150 / skill 100-130 lines.

**EN 化禁止 file/section**: `rules/en-conversion-protected.md` 参照 (誤訳すると規約・bats test・JP trigger 破壊)。

## Discovery / Investigation Routing (anti-overuse)

Agent startup is the biggest cost source (dozens of seconds to minutes).

| Scope | Tool |
|---|---|
| 1-2 files / specific symbol | Bash grep/find or `mcp__serena__find_symbol` |
| 3-4 query broad search | `Task(explore-agent)` parallel (2 if ambiguous, all 4 for 3+ domains) |
| Claude Code CLI/SDK/API spec | `claude-code-guide` agent |
| Other genuinely broad analysis | Explore (built-in, last resort) |

**Avoid `general-purpose` agent** (measured highest cost source, max 501s). Metrics: `references/performance-insights.md`

## Auto-Delegation (parent=Opus orchestrates, subagent=Sonnet executes)

*(For impl/edit tasks. Investigation phase → Discovery Routing)*

**Decision principle (top priority)**: Delegate on uncertainty. Under-delegation risk > over-delegation cost. Opus parent handles orchestration / judgment only; all actual work (write / refactor / verification / commit) goes to Sonnet.

**Default = delegate to `developer-agent` (Sonnet)**. "If told to do it, Sonnet does it" principle (per user direction 2026-05-22). Inline execution only for exceptions below.

**Edit/Write declaration rule**: Before calling Edit or Write tool, declare in chat **one line**:
- `Inline exception (reason: 1 symbol body / 1 section / 1 config value / read-only cmd / expected <20s) → parent inline execution` 
- OR `Inline prohibited (reason: 2+ files / 10+ lines / 2+ symbols / new file / revert / 5+ line markdown section / refactor / commit-bearing) → delegate to developer-agent`

Skipping declaration = rule violation, recorded to feedback memory.

**Inline exceptions (no delegation)**: Q&A / already-read file check / dry-run / **1 symbol inside body replace** / **1 section edit** / **same-file 1 config value change** / **expected LLM execution <20s** / **read-only command 1 item** (`git status` / `ls` / `cat` / `wc -l` / etc)

**Inline prohibited (must delegate)**: 2+ files / 10+ lines / 2+ symbols / new file / revert-series / 5+ line markdown section add / refactor / commit-bearing ops

Note: **impl** = logic addition / new file / multi-symbol edit; **edit** = any of 2+ files, 10+ lines, or 2+ symbols

| Trigger | Auto-launch |
|---|---|
| **All impl / edit / commit outside exceptions above** | `developer-agent` auto (`Task` tool) |
| broad search (3+ query / 3+ domain) | `explore-agent` parallel auto |
| review request / PR check | `reviewer-agent` auto (or `/review`) |
| unknown bug cause / recurring bug | `root-cause-analyzer` auto |
| design decision / large plan / multi-phase | `po-agent` auto (or `/plan`) |
| multi-stage task (investigate→design→impl→verify) | `/flow` hierarchy (PO→Manager→Dev→Reviewer) |
| 20+ file bulk processing | `claude -p` fan-out (`references/fanout-recipes.md`) |

## Session Efficiency

- **Design decisions**: light → `Shift+Tab` Plan Mode / large → `/plan` (PO agent). **Long brainstorm → haiku separate session (`claude --model haiku`), handoff to Opus for impl**
- **Long tasks**: `/rename {type}-{scope}`, `claude --resume` (`references/session-management.md`)
- **Success-criteria principle**: "what defines success" over procedural steps
- **Verify first**: post-impl run test/lint/typecheck (DoD below)
- **MCP tool args: verify spec before writing**: use `ToolSearch select:<tool>` to confirm param names; do not rely on LLM autocorrect (2026-05-17: `memory_file_name` / `path=` incident)
- **After regex replace, run `git diff --stat` immediately**: serena `replace_content` regex forces DOTALL/MULTILINE — `.*\n` greedy wipe risk. Single line: **literal + trailing `\n`**; multi-line: **non-greedy `.*?` + explicit end anchor** (2026-05-18 incident, see `[[serena-replace-regex-dotall-pitfall]]` memory)
- **Minimize confirmation / choice**: execute safe ops without prompting; apply recommended option directly for minor choices. Confirm only for: file deletion / deploy / external send / critical decisions (architecture / cost / irreversible)
- **ROI gate**: even for "do everything" instructions, re-confirm individually if ultrathink judges low ROI (2026-05-07 bulk low-ROI impl incident)
- **pwd check**: verify existence before Read/Bash; check `pwd` before `cd`
- **/memory-save**: only for 3+ file changes / non-obvious refactor / incident
- **Token budget (Read/Bash output)**: use `limit:` / `offset:` for large files (default ~200 lines); truncate long logs with `| head -N` / `| tail -N`. **Full dump accumulates cost**; prefer serena symbol read when available
- **Subagent prompt context budget**: keep delegation prompts ≤500 words with minimum necessary context. **Never dump full conversation** (cheap per-token subagent cost reverses at high input volume; symmetric with "Completion report budget" in `agents/developer-agent.md`)

## Rewind

- **Esc**: pause (context preserved) / **Esc x2** or `/rewind`: restore conversation, code, or both to a past checkpoint
- Details: `references/checkpoint-rewind.md`

## Context Management

- **>50% → suggest `/compact`** (cannot auto-execute). `/clear` at task boundary is best savings point (5+ min idle = prompt cache TTL expired → full cache miss)
- Continue: request "generate next-session mega-prompt" → paste into new session
- Uncontaminated question: `/btw` (overlay, not saved to history)

## Natural Language Triggers (major only)

| Input | Action |
|---|---|
| "push" / "pushして" | `/git-push --pr` |
| "全自動で" / "autoで" / "おまかせ" | `/flow-auto` |
| "レビュー" / "レビューして" | `/review` |
| "{strict\|fast\|normal} mode" | `/session-mode {strength}` |
| "並列実行で" / "wt 分けて" | `/flow --parallel` |
| "team で" / "agent team で" / "分担で" / "本格的に" | `/flow` (PO/Manager/Dev hierarchy, forced) |
| "Slack に投げて" / "Slack に送って" | `mcp__claude_ai_Slack__slack_send_message` |
| "Notion に書いて" / "Notion メモして" | `mcp__claude_ai_Notion__notion-create-pages` |

No other natural-language interpretation. Full list: `references/natural-language-triggers.md`

## Git Merge Prohibition

| Operation | Rule |
|---|---|
| PR branch merge (`gh pr merge` etc.) | **Strictly forbidden**. Output PR URL, direct to browser |
| git merge / rebase / branch delete | User confirmation required |

## Definition of Done (DoD)

Apply only relevant items, skip N/A. Scale by change size (typo → #6 only / new feature → all).

1. Types: 0 errors (typed only)
2. Tests: relevant pass, coverage ≥80% (project standard takes priority)
3. Lint: 0 violations
4. Security: audit clean
5. Build: success
6. **Actual behavior: 1 manual or smoke test** (required)

Bundle: `/lint-test` (CI equivalent) / `/verify-once` (structural). Cannot report completion until all applicable items pass.

## Root Cause Analysis

Structural fix over symptomatic. **Reproduce → identify → design → verify** 4 steps required. Details: `/root-cause` skill / `/protection-mode`.

## Compounding Engineering

Claude misbehavior / non-obvious success = signal that config is not reflecting reality. Document immediately → auto-avoid next session (Boris style).

- Misbehavior → record in CLAUDE.md / skill / hook
- Non-obvious success → codify as a rule
- Append "update CLAUDE.md or related skill to ensure reproducibility" to fix instructions → triggers config update
- Details: `references/compounding-engineering-cycle.md` / `memory-usage.md`

## Genshijin Boundary

genshijin (体言止め / 助詞最小) は **chat 応答のみ**。外向き prose (PR / commit / Issue / Slack / Notion / DD / PRD / RCA / comments) と `/plan` `/design-doc` `/prd` `/post-comment` `/git-push --pr` `/docs` ドラフトは plain JP (〜する / 〜した、主語明示、指示語禁止: 「これ」「それ」「上記」→具体名)。Details: `rules/genshijin.md` + `guidelines/writing/PRINCIPLES.md`

## References

High freq: `references/model-selection.md` / `natural-language-triggers.md` / `memory-usage.md` / `performance-insights.md` / `multi-repo-workflow.md` / `references/developer-agent-delegation-prompt.md` (delegation template)
Index: `references/INDEX.md`, Writing entry: `guidelines/writing/README.md`
Tools: `scripts/health-check.sh` (monthly) / `usage-stats.sh` / `hook-bench.sh`
