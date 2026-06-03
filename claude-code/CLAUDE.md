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
| 3+ query / broad search | `Task(explore-agent)` 並列発火 default (domain 数 = 並列数、max 8)、ambiguous 判定不要 |
| Claude Code CLI/SDK/API spec | `claude-code-guide` agent |
| Other genuinely broad analysis | Explore (built-in, last resort) |

**Avoid `general-purpose` agent** (measured highest cost source, max 501s). Metrics: `references/performance-insights.md`

## Auto-Delegation (parent=Opus orchestrates, subagent=Sonnet executes)

*(For impl/edit tasks. Investigation phase → Discovery Routing)*

**Decision principle (top priority)**: Delegate on uncertainty. Under-delegation risk > over-delegation cost. Opus parent handles orchestration / judgment only; all actual work (write / refactor / commit) goes to Sonnet. Verification: parent inline default (build / typecheck 必須 language project は subagent 側、詳細 `references/developer-agent-delegation-prompt.md`)。

**Time-first (top priority)**: 最速 makespan を選ぶことが全 routing の上位原則。並列禁止 case (物理制約: 同一 file edit / 結果依存) 以外は常に並列発火、cap default 8 (parent + Dev×8 = 9 concurrent)、makespan 5% 以上短縮見込みなら採用。迷ったら並列+委譲 (under-parallel risk > over-parallel cost)。詳細: `references/PARALLEL-PATTERNS.md`

**Default = delegate to `developer-agent` (Sonnet)**. "If told to do it, Sonnet does it" principle (per user direction 2026-05-22). Inline execution only for exceptions below.

**Delegate threshold (declaration 不要)**: 2+ files / 10+ lines / 2+ symbols / new file / commit-bearing いずれか → `developer-agent` 委譲。それ以下は inline 可。違反 (delegate 怠り) は feedback memory 記録。

**委譲分割義務 (束ね禁止)**: 1 prompt に 2+ domain (異 file group / 異 root cause / 異 verify 系) を束ねず、domain 別に 単一 message 内 複数 Agent tool_use で並列発火する。束ねは subagent 内逐次処理で makespan 累積 `[[parallel-brushup-makespan-2026-05-31]]`。

**並列発火 = 単一 message に Agent tool_use を N 個並べる (書式強制)**: 独立 task を N 個流す時は **1 つの assistant message 内に N 個の `Agent` tool_use を同時に置く**。1 message 1 Agent を N message 繰り返すと前 agent の STOP 待ち逐次化し、peak concurrency=1 に落ちる (formula PASS / cap 8 を満たしても同時並列は発生しない `[[parallel-fire-format-peak-concurrency]]`)。**「並列で流す」と判断した瞬間、tool_use を 1 message に束ねること自体が並列化の実体**であり、cap / formula は発火数の上限を決めるだけで同時性は保証しない。検証: `scripts/flow-baseline.sh --summary` の `peak_concurrency distribution` が 1 偏重なら逐次化の兆候。

**parent 事前準備義務**: 委譲前 parent が (a) target `file:line` 特定 (`find_symbol` / `grep`) (b) verify コマンド確定 (c) DoD 1 行化 を完了する。subagent に探索を投げない (探索 phase が makespan 支配要因)。target 不明示の prompt は full repo scan を誘発する。

**Agent 発火直前 self-review 必須**: Task tool 発火の直前に並列化判定を自己確認する。判定 checklist は `references/PARALLEL-PATTERNS.md` を canonical 参照とする (CLAUDE.md に重複コピーしない)。hook が Task 発火時に self-review reminder を additionalContext として自動 inject する。

**Inline exceptions (no delegation)**: Q&A / already-read file check (同一 session で既に Read 完了した file への Q&A、追加 Read なし; 追加 Read 必要なら throttle count 算入) / dry-run / **1 symbol inside body replace** / **1 section edit** / **same-file 1 config value change** / **expected LLM execution <20s** / **read-only command 1 item** (`git status` / `ls` / `cat` / `wc -l` / etc)

**Inline exception throttle**: 2 consecutive inline exceptions in same session → next edit-class op is **mandatory** developer-agent delegation (reset counter after delegation). Investigation phase (Q&A / dry-run を除く調査専用 Read/Bash): 累積 ≥5 → switch subsequent investigation to `explore-agent`.

Note: **impl** = logic addition / new file / multi-symbol edit; **edit** = any of 2+ files, 10+ lines, or 2+ symbols

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

## Session Efficiency

- **Design decisions**: light → `Shift+Tab` Plan Mode / large → `/plan` (PO agent). **Long brainstorm → haiku separate session (`claude --model haiku`), handoff to Opus for impl**
- **Long tasks**: `/rename {type}-{scope}`, `claude --resume` (`references/session-management.md`)
- **Success-criteria principle**: "what defines success" over procedural steps
- **Verify first**: post-impl run test/lint/typecheck (DoD below)
- **MCP tool args: verify spec before writing**: use `ToolSearch select:<tool>` to confirm param names; do not rely on LLM autocorrect `[[hook-principles-path-bug-incident]]`
- **After regex replace, run `git diff --stat` immediately**: serena `replace_content` regex forces DOTALL/MULTILINE — `.*\n` greedy wipe risk. Single line: **literal + trailing `\n`**; multi-line: **non-greedy `.*?` + explicit end anchor** (`[[serena-replace-regex-dotall-pitfall]]`)
- **Minimize confirmation / choice**: execute safe ops without prompting; apply recommended option directly for minor choices. Confirm only for: file deletion / deploy / external send / critical decisions (architecture / cost / irreversible)
- **ROI gate**: even for "do everything" instructions, re-confirm individually if ultrathink judges low ROI
- **Bulk / 網羅 keyword**: 「全 N 件 / 網羅 / 一斉 / bulk / 大量」要求は parent Opus inline で sample 縮小判断する前に Sonnet 委譲 (read-only=`explore-agent` / edit=`developer-agent`) を第一選択検討。規模・cost を理由に sample 妥協は「Default delegate to Sonnet」原則違反 (`[[sonnet-delegate-bulk-readonly]]`)
- **pwd check**: verify existence before Read/Bash; check `pwd` before `cd`
- **Pre-delegation git status check**: developer-agent 委譲前に `git status` + `git log --oneline -3` で並列 session 作業 (自分が触っていない untracked / modified、直近 commit が自分由来でない) を確認する。検出時は user に「並列実装あり、進めて OK?」確認必須
- **/memory-save 発火条件 (いずれか満たせば対象)**: (a) commit 3+ file 変更 *かつ* 構造的変更 (refactor / 設計変更 / hook 追加) / (b) incident 対応 (root cause 特定 + fix) / (c) 非自明な調査結果 (再現手順 / 計測値 / 罠) / (d) ユーザ feedback で挙動変更を指示された場合。単純 typo fix / docs 微修正 / config 1 行 toggle は対象外
- **Token budget (Read/Bash output)**: use `limit:` / `offset:` for large files (default ~200 lines); truncate long logs with `| head -N` / `| tail -N`. **Full dump accumulates cost**; prefer serena symbol read when available
- **Subagent prompt context budget**: keep delegation prompts ≤500 words with minimum necessary context. **Never dump full conversation** (cheap per-token subagent cost reverses at high input volume; symmetric with "Completion report budget" in `agents/developer-agent.md`)
- **Multi-clause requests: echo intent first**: requests with ≥2 plausible interpretations (≥2 sentences, multi-item, OR single sentence with ambiguous referent like "X 機能" / "重い" / abstract directives) — echo `understood=X / missing=Y` line + ask 1 clarifying question before acting. Trigger = interpretation branches, not sentence length
- **PR/branch scope 言及時は scope 1 行 echo**: user が「PR を切り出す」「branch 分ける」「scope はあくまで X」等 PR/branch 単位の scope を口頭で示した時、`scope=<対象 file/symbol/diff 範囲> / 除外=<明示的に外す範囲>` 1 行を echo してから着手する。scope ずれ churn (`再度 PR 切り出し` / `スコープ違う` 等) の主因 (retrospective 2026-06-01 検出)
- **`/memory-save` rapid-fire guard**: same session, save within last 5 min → prefer diff-append over new memory
- **`/review-fix-push` pre-launch diff echo**: `git diff --stat | tail -1` one-liner before invoke; surfaces runaway diffs
- **Large-repo session split (snkrdunk-com / loadtest / docs etc)**: Hard reset (`/clear` or new session) at task boundary; never carry session past 1 task / 3h elapsed / 1000 msg / 40% context (whichever first). 1 task = 1 session principle in large repos
- **長文回答 = 冒頭結論 1 行強制**: chat 応答で 5 行超 + 列挙出す時は **1 行目に結論明示**。違反すると `つまり？` 再質問発生。
- **長文出力 = PREP 法**: 5 行超 + 複数項目は **P**oint→**R**eason→**E**xample→**P**oint 構造。抽象語禁止 (軸/層/土台→具体動作)。詳細: `guidelines/writing/PRINCIPLES.md` PREP section
- **decision 要求応答 = 冒頭に決定の枠を提示**: user に decision 要求する応答 (末尾 `?` + 選択肢 A/B・案 1/2・Yes/No・どちらにする等を含む) は冒頭 1 行に `要決定: <選択肢の枠> / <候補数>` を置く。長さ閾値なし (3 行でも適用)。違反すると `どういうこと?` 再質問発生 (root cause: 冒頭結論が `調査結果` で要決定が末尾に隠れる)。詳細: `guidelines/writing/PRINCIPLES.md` decision-frame-first section

## 派生値禁止 (no derived literals)

**全 project 共通 rule** (ai-tools / snkrdunk / 他 ghq repo 全適用)。canonical source (一次データ) から導出可能な派生値 (count / sum / list 長さ / 集計値) を別 file に literal で書かない、参照のみ。

- **書くな**: 「N 語」「N 件」「合計 N」「source の M 個」等の数字を canonical 外 file に literal で
- **書け**: 「source: <path>:<line>」参照のみ。list 全体埋めるなら canonical を **そこに移す** (片方削除)
- **例外**: 不変 magic number (HTTP 200 等) / test fixture 内 expected count (test 自体が canonical)
- **self-check**: 数字書く時「これ別の場所で count 可能?」→ Yes なら literal 禁止
- **review 検出**: `grep -nE '[0-9]+ ?(語|件|個|個所|箇所)' <changed_files>` で派生値疑い

(`[[feedback-no-derived-literals]]`)

**Hook block 対象**: AI 定型語 / カタカナ造語禁止 / 難読漢語 / 非日常英語 (PRINCIPLES.md の各 list から動的抽出)。英日混在語 (lock / commit / deploy / TX 等) は誤検出多発リスクのため hook block 対象外、PRINCIPLES.md (d) 表 + writing review で manual 検出する。
**PRINCIPLES.md list scope 記法**: `**<name> (block|warn-only)**: <terms>` 形式で scope を明示する。新規 list 追加時は適用 target (chat / 外向き prose / commit message 全許可 or 一部制限) を考慮して block か warn-only を選ぶ。**既存 key (`AI定型語` / `カタカナ造語禁止` / `断定語 (warn-only)`) の name 変更禁止** — hook (`hooks/pre-tool-use.sh:_extract_term_list`) が exact match で参照、rename で silent pass する。

## Rewind

- **Esc**: pause (context preserved) / **Esc x2** or `/rewind`: restore conversation, code, or both to a past checkpoint
- Details: `references/checkpoint-rewind.md`

## Context Management

- **>40% → suggest `/compact`** (cannot auto-execute). `/clear` at task boundary is best savings point (5+ min idle = prompt cache TTL expired → full cache miss). Session 30 min elapsed → propose `/clear` once in chat (single prompt only, no repeat).
- **同一問題の修正が2回連続失敗 → 容量に関わらず `/clear` + prompt 書き直しを提案** (公式 best practice: 失敗アプローチの context 蓄積が主要 failure mode、容量起因の `/clear` とは別軸)。
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
- Fix 指示に "update CLAUDE.md or related skill" 追記 → config update trigger。Details: `references/compounding-engineering-cycle.md` / `memory-usage.md`

## 書く前の自己確認 (chat 除く)

外向き文章 (PR / commit / Issue / Slack / Notion / DD / PRD / RCA / コードコメント等) は **今日の commit を read してから書く** (`git log --since=midnight --pretty=format:'%h %s'`)。hook が書く系 tool (Write / Edit / Bash commit·gh·glab / Slack MCP / Notion MCP) 直前に自動 inject する。inject は 2 source: (1) 作業中 repo の今日 commit + (2) `~/ai-tools` の `guidelines/` `CLAUDE.md` 限定の今日 commit (別 repo 作業時も writing 規約更新が届く設計)。漏れ時は主体的に確認。

## Genshijin Boundary

genshijin (体言止め / 助詞最小) は **chat 応答のみ**。外向き prose (PR / commit / Issue / Slack / Notion / DD / PRD / RCA / comments) と `/plan` `/design-doc` `/prd` `/post-comment` `/git-push --pr` `/docs` ドラフトは plain JP (〜する / 〜した、主語明示、指示語禁止: 「これ」「それ」「上記」→具体名)。Details: `rules/genshijin.md` + `guidelines/writing/PRINCIPLES.md`

**AI定型語 hook block**: git commit / gh/glab PR・Issue / Slack MCP / Notion MCP の外向き text に AI定型語 (source: PRINCIPLES.md) が含まれると `hooks/pre-tool-use.sh` が exit 2 でブロック。削除・置換してから再実行。
- 4 list (AI定型語/カタカナ造語/jargon/略語) は PRINCIPLES.md canonical、hook で自動 inject + 外向き block (`~/.claude/logs/jp-quality-block.log` に記録)

## References

High freq: `references/model-selection.md` / `natural-language-triggers.md` / `memory-usage.md` / `performance-insights.md` / `multi-repo-workflow.md` / `references/developer-agent-delegation-prompt.md` (delegation template)
Index: `references/INDEX.md`, Writing entry: `guidelines/writing/README.md`
Tools: `scripts/health-check.sh` (monthly) / `usage-stats.sh` / `hook-bench.sh`
- `references/anthropics-skills-catalog.md` (anthropics 公式 skill の on-demand 参照索引、永続取り込みなし)
