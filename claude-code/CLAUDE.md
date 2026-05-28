# claude-code Directory Config

**Respond in genshijin mode (normal).** No keigo, taigen-dome, minimal particles, preserve technical terms. Plain JP only for destructive-action confirmations.

`~/ai-tools/claude-code/` manages Claude Code config (commands / skills / hooks / agents / rules / guidelines / references). Synced to `~/.claude/` via `sync.sh`.

## Editing Rule (data-loss guard)

- **Always edit source `~/ai-tools/claude-code/`. `~/.claude/` direct edits are wiped by `sync.sh to-local`** (applies to CLAUDE.md / commands / skills / hooks / agents / rules / guidelines / config / references)
- **root keys (`env` / `model` / `statusLine` / `permissions` / `sandbox` / `worktree` / `enabledPlugins` / `extraKnownMarketplaces` / `autoUpdatesChannel` ほか allowlist 全 root key) は template canonical**、`to-local` で全上書き。live 直追加は wipe される。設定追加は template 編集 → `to-local` で反映する流れに統一 (例外: `hooks` / `skillOverrides` は専用 merge ロジック)
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

**Inline exceptions (no delegation)**: Q&A / already-read file check (同一 session で既に Read 完了した file への Q&A、追加 Read なし; 追加 Read 必要なら throttle count 算入) / dry-run / **1 symbol inside body replace** / **1 section edit** / **same-file 1 config value change** / **expected LLM execution <20s** / **read-only command 1 item** (`git status` / `ls` / `cat` / `wc -l` / etc)

**Inline exception throttle**: 3 consecutive inline exceptions in same session → next edit-class op is **mandatory** developer-agent delegation (reset counter after delegation). Investigation phase (Q&A / dry-run を除く調査専用 Read/Bash): 累積 ≥5 → switch subsequent investigation to `explore-agent`.

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
| **網羅 / 全件 / 一斉 / bulk / 大量 file readonly** | `explore-agent` (read-only) or `developer-agent` (edit) Sonnet 委譲必須、parent Opus sample 縮小禁止 |

## Session Efficiency

- **Design decisions**: light → `Shift+Tab` Plan Mode / large → `/plan` (PO agent). **Long brainstorm → haiku separate session (`claude --model haiku`), handoff to Opus for impl**
- **Long tasks**: `/rename {type}-{scope}`, `claude --resume` (`references/session-management.md`)
- **Success-criteria principle**: "what defines success" over procedural steps
- **Verify first**: post-impl run test/lint/typecheck (DoD below)
- **MCP tool args: verify spec before writing**: use `ToolSearch select:<tool>` to confirm param names; do not rely on LLM autocorrect (2026-05-17: `memory_file_name` / `path=` incident)
- **After regex replace, run `git diff --stat` immediately**: serena `replace_content` regex forces DOTALL/MULTILINE — `.*\n` greedy wipe risk. Single line: **literal + trailing `\n`**; multi-line: **non-greedy `.*?` + explicit end anchor** (2026-05-18 incident, see `[[serena-replace-regex-dotall-pitfall]]` memory)
- **Minimize confirmation / choice**: execute safe ops without prompting; apply recommended option directly for minor choices. Confirm only for: file deletion / deploy / external send / critical decisions (architecture / cost / irreversible)
- **ROI gate**: even for "do everything" instructions, re-confirm individually if ultrathink judges low ROI (2026-05-07 bulk low-ROI impl incident)
- **Bulk / 網羅 keyword**: 「全 N 件 / 網羅 / 一斉 / bulk / 大量」要求は parent Opus inline で sample 縮小判断する前に Sonnet 委譲 (read-only=`explore-agent` / edit=`developer-agent`) を第一選択検討。規模・cost を理由に sample 妥協は「Default delegate to Sonnet」原則違反 (2026-05-23 incident、memory `[[sonnet-delegate-bulk-readonly]]`)
- **pwd check**: verify existence before Read/Bash; check `pwd` before `cd`
- **Pre-delegation git status check**: developer-agent 委譲前に `git status` + `git log --oneline -3` で並列 session 作業 (自分が触っていない untracked / modified、直近 commit が自分由来でない) を確認する。検出時は user に「並列実装あり、進めて OK?」確認必須 (2026-05-23 incident: hook-bench --check 固定閾値式を委譲中、user 並列で baseline 比較式 `hook-bench-ci.sh` 実装中で機能重複、`2cef2a5` 破棄に至った)
- **/memory-save 発火条件 (いずれか満たせば対象)**: (a) commit 3+ file 変更 *かつ* 構造的変更 (refactor / 設計変更 / hook 追加) / (b) incident 対応 (root cause 特定 + fix) / (c) 非自明な調査結果 (再現手順 / 計測値 / 罠) / (d) ユーザ feedback で挙動変更を指示された場合。単純 typo fix / docs 微修正 / config 1 行 toggle は対象外
- **Token budget (Read/Bash output)**: use `limit:` / `offset:` for large files (default ~200 lines); truncate long logs with `| head -N` / `| tail -N`. **Full dump accumulates cost**; prefer serena symbol read when available
- **Subagent prompt context budget**: keep delegation prompts ≤500 words with minimum necessary context. **Never dump full conversation** (cheap per-token subagent cost reverses at high input volume; symmetric with "Completion report budget" in `agents/developer-agent.md`)
- **Multi-clause requests: echo intent first**: requests with ≥2 plausible interpretations (≥2 sentences, multi-item, OR single sentence with ambiguous referent like "X 機能" / "重い" / abstract directives) — echo `understood=X / missing=Y` line + ask 1 clarifying question before acting. Trigger = interpretation branches, not sentence length. Kills `再度〜` churn (56 hits / 3 days, 2026-05-22〜25, top time sink). 2026-05-25 incident: "ai-tools 機能読み込まない" を逆解釈、3 turn 浪費
- **`/memory-save` rapid-fire guard**: same session, save within last 5 min → prefer diff-append over new memory (94 hits w/ multiple 5x bursts, low-ROI redundancy)
- **`/review-fix-push` pre-launch diff echo**: `git diff --stat | tail -1` one-liner before invoke; surfaces 500+ diffs that triggered sub-flow runaway (2026-05-23 incident)
- **Large-repo session split (snkrdunk-com / loadtest / docs etc)**: cache_read 96.8% of token cost, 1B+ token sessions (4 days, 26K msg) eat 23% monthly token alone. Hard reset (`/clear` or new session) at task boundary; never carry session past 1 task / 3h elapsed / 1000 msg / 40% context (whichever first). 1 task = 1 session principle in large repos. Measured 2026-05-25
- **長文回答 = 冒頭結論 1 行強制**: chat 応答で 5 行超 + 列挙 (A/B/C 案 / Phase 1/2/3 / 表) 出す時は **1 行目に結論明示**。読み手が後段読まずに次の指示出せる状態にする。違反すると `つまり？` / `どういうこと？` 再質問発生 (2026-05-22〜28 計 9 件/週、retro 第 3 churn 源)。`guidelines/writing/PRINCIPLES.md` chat 行「結論先出し」を chat 応答に明示適用

## 派生値禁止 (no derived literals)

**全 project 共通 rule** (ai-tools / snkrdunk / 他 ghq repo 全適用)。canonical source (一次データ) から導出可能な派生値 (count / sum / list 長さ / 集計値) を別 file に literal で書かない、参照のみ。

- **書くな**: 「N 語」「N 件」「合計 N」「source の M 個」等の数字を canonical 外 file に literal で
- **書け**: 「source: <path>:<line>」参照のみ。list 全体埋めるなら canonical を **そこに移す** (片方削除)
- **例外**: 不変 magic number (HTTP 200 等) / test fixture 内 expected count (test 自体が canonical)
- **self-check**: 数字書く時「これ別の場所で count 可能?」→ Yes なら literal 禁止
- **review 検出**: `grep -nE '[0-9]+ ?(語|件|個|個所|箇所)' <changed_files>` で派生値疑い

2026-05-27 incident: commit `9b2247a` で AI 定型語辞書数 (27/10/37) を hook + 2 commands に重複 literal 化、将来 PRINCIPLES.md 更新で desync 必至 (`[[feedback-no-derived-literals]]` memory)

## Rewind

- **Esc**: pause (context preserved) / **Esc x2** or `/rewind`: restore conversation, code, or both to a past checkpoint
- Details: `references/checkpoint-rewind.md`

## Context Management

- **>40% → suggest `/compact`** (cannot auto-execute; restored from 25% on 2026-05-25 — median session = 1.4M tokens, 25% triggered too often. snkrdunk "heavy" 現象は top 3 session が 30 日 token の 44% 占有する偏り起因、全 session 圧縮でなく long-running session 分割が正しい対策). `/clear` at task boundary is best savings point (5+ min idle = prompt cache TTL expired → full cache miss). Session 30 min elapsed → propose `/clear` once in chat (single prompt only, no repeat).
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
- `references/anthropics-skills-catalog.md` (anthropics 公式 skill の on-demand 参照索引、永続取り込みなし)
