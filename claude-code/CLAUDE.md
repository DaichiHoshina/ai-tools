# claude-code Directory Config

**Respond in genshijin mode (normal).** No keigo, taigen-dome, minimal particles, preserve technical terms. Plain JP only for destructive-action confirmations.

`~/ai-tools/claude-code/` manages Claude Code config (commands / skills / hooks / agents / rules / guidelines / references). Synced to `~/.claude/` via `sync.sh`.

## Quick Reference

```bash
cd ~/ai-tools/claude-code
npm test                    # jest (statusline 等 JS test)
bats -r tests/              # bash hook / lib / scripts の bats 全実行
./sync.sh to-local --yes    # repo → ~/.claude 反映 (非対話)
./scripts/hook-bench.sh     # hook latency 計測 (warmup=5 / runs=15、--log で保存 / --diff で前回比較 / install-hook-bench-cron.sh で週次 cron)
```

**Golden workflow (頻出 3 種)**

- 実行 mode 判定 → `/plan` (inline / /dev / /workflow / /flow / /flow --auto / /goal の 6 択を Step 2 で判定、/goal は loop 系 objective gate task に限定)
- worktree 隔離 + commit + ff-merge + push (`[[ai-tools-worktree-workflow]]` canonical):
  ```bash
  git stash push -u -m wip && git worktree add ../ai-tools-wt-<topic> -b <branch>
  # wt 内で編集 + commit
  git merge --ff-only <branch> && git push origin main && git worktree remove ../ai-tools-wt-<topic> && git branch -d <branch>
  ```
- skill 追加 → `/skill-add` / guideline 更新 → `/update-guidelines` / commit + push + PR → `/git-push --pr` (`pushして` でも発火)

## Repo layout

| dir | 役割 |
|---|---|
| `commands/` | slash command (`/plan` `/flow` `/review` `/workflow` 等) |
| `skills/` | Skill (`comprehensive-review` `jp-writing` `local-docs` 等) |
| `agents/` | subagent 定義 (`developer-agent` `po-agent` `manager-agent` `reviewer-agent` `explore-agent` 等) |
| `hooks/` | Claude Code hooks (`pre-tool-use.sh` `post-tool-use.sh` `session-start.sh` 等) |
| `rules/` | 規約 (`genshijin.md` `public-repo-private-data-block.md` `markdown-anchor-sync.md` 等) |
| `guidelines/` | 執筆 / language / design 規範 (`writing/` `design/` 等) |
| `references/` | 詳細仕様 / 履歴 / cross-ref 集 (`PARALLEL-PATTERNS.md` `INDEX.md` 等) |
| `templates/` | `settings.json.template` ほか canonical config |
| `scripts/` | sync 補助 / hook-bench / git-hooks |
| `lib/` | bash 共通 lib (`print-functions.sh` 等) |
| `tests/` | bats (`tests/integration/` `tests/unit/`) + jest |

詳細 dir 内 cross-ref は `references/INDEX.md` 参照。

## Editing Rule (data-loss guard)

- **Always edit source `~/ai-tools/claude-code/`. `~/.claude/` direct edits are wiped by `sync.sh to-local`** (applies to CLAUDE.md / commands / skills / hooks / agents / rules / guidelines / config / references)
- **root keys (`env` / `model` / `statusLine` / `permissions` / `sandbox` / `worktree` / `enabledPlugins` / `extraKnownMarketplaces` / `autoUpdatesChannel` and all allowlisted root keys) are template canonical**; `to-local` overwrites entirely. Live additions are wiped. Add settings via template edit → `to-local` (exceptions: `hooks` / `skillOverrides` have dedicated merge logic)
- 🔒 PROTECTED SECTION in CLAUDE.md must not be modified. YAML frontmatter must remain valid
- `VERSION` / `SERENA_VERSION` bumped only on CLI / Serena release intake (`/claude-update-fix` / `/serena-update-fix`)
- Claude Code runs on **stable channel** (switched back from latest 2026-06-23); `/claude-update-fix` TARGET is `dist-tags.stable` (details: `commands/claude-update-fix.md`)

## Definition File Token Saving

`.md` in commands/, skills/, agents/ consume tokens every session. Keep: decision tables, workflow defs, operation guards, prohibitions, 1 example. Remove: sample impl, duplicate explanations, detailed usage. Target: agent ≤300 / command ≤150 / skill 100-130 lines.

**EN-conversion-protected files/sections**: see `references/on-demand-rules/en-conversion-protected.md` (mistranslation breaks rules, bats tests, JP trigger matching).

**On-demand rules (auto-load 対象外、trigger 時のみ Read)**: `references/on-demand-rules/` 配下 (markdown-anchor-sync / en-conversion-protected / api-design)。session-start auto-inject から外して token 節約。trigger: md heading rename → `markdown-anchor-sync.md` / EN refactor・`/claude-update-fix` → `en-conversion-protected.md` / handler・controller・resolver・api・endpoint 触る → `api-design.md`。

## Discovery / Investigation Routing (anti-overuse)

Agent startup is the biggest cost source (dozens of seconds to minutes).

> ⛔ **`general-purpose` agent is absolutely banned** — `subagent_type` must be explicit on every `Task` call; unspecified fallback is also forbidden. On violation: abort immediately and switch to `explore-agent` (search) / `claude-code-guide` (CLI/SDK) / `developer-agent` (impl).

| Scope | Tool |
|---|---|
| 1-2 files / specific symbol | Bash grep/find or `mcp__serena__find_symbol` |
| 3+ query / broad search | `Task(explore-agent)` parallel fan-out by default (parallelism = domain count, max 8); no ambiguity check needed |
| Claude Code CLI/SDK/API spec | `claude-code-guide` agent |
| Other genuinely broad analysis | Explore (built-in, last resort) |
| **`general-purpose` agent** | **Forbidden** — highest cost source (measured max 501s). Always substitute with `explore-agent` / `claude-code-guide` / `developer-agent` |

> explore-agent / root-cause-analyzer を発火した後は、trailer フィールド (`status` / `confidence` / `issues_blocking`) を必ず読む。詳細: `references/agent-output-schema.md`

## Library API Live Doc Required

外部 library / framework の API method / hook / config を直書きする前に **context7 skill か WebFetch で最新 docs を取得すること**。training cutoff (Jan 2026) 以降の API 変更は推測で書かない。

trigger: library method を直書きする場合 (`useState` / `axios.create` / `fastapi.Depends` 等) / 新 library 採用 / API spec が 6 か月超の場合。

hook が warn-only で検出 (`hooks/pre-tool-use.sh`)。skill: `skills/context7/SKILL.md`。

## Auto-Delegation (parent=Opus orchestrates, subagent=Sonnet executes)

*(Impl/edit task。Investigation phase → Discovery Routing)*

**Default = delegate to `developer-agent` (Sonnet)**。inline は detailed.md 列挙 exception のみ。**1 dev = 1 file 原則** (`bundle_justification` なき複数 file fan-out 禁止) + **1 Task scope 上限** (file 3-5 / 観点 1-2 超 → 単一 message に N Agent 並列分割) + **parent 監視責任** (PO/Manager は subagent に丸投げ禁止、bundle 違反は PO Gate で阻止)。直列 chain でも各 step 内に複数 file/観点あるなら step 内 fan-out する (`[[feedback-no-single-agent-overload]]`)。

**Parallel fan-out 自己強制 (hard rule)**: N≥2 dev を発火するときは**必ず単一 assistant message に N 個の Agent tool_use を含める**。連続する assistant message に Agent を 1 体ずつ並べる直列発火は禁止 (`[[parallel-fire-format-peak-concurrency]]` で実測検証済、flow-baseline.sh が `bundle_violations` として記録)。発火直前 self-check:「これから発火する N は何件か / 単一 message 内で N tool_use ブロックを並べているか」を chat 内で 1 行宣言してから発火。N=1 は単発 dev (違反なし)、N=2+ で別 msg に分けたら自己訂正必須。違反検出 hook: `pre-tool-use.sh:_check_developer_agent_bundle_violation`。

**Subagent silent-fail guard**: subagent context では `AskUserQuestion` 不可 + permission prompt 系 tool (Edit / Write / Bash 一部) が auto-deny で**silent fail** する (web search 2026-06-24 出典: [claudefa.st](https://claudefa.st/blog/guide/agents/sub-agent-best-practices))。approval-gated edit / 判断 fork は parent に escalate (`status: blocked` + `issues_blocking[]`)。subagent 側仕様は `agents/developer-agent.md` § Silent-fail guard canonical。

詳細 (delegate threshold / parallel fire format / inline exceptions / trigger table / 違反パターン): `references/auto-delegation-detailed.md`

## Tool Call Format (生テキスト呼び出し禁止)

ツール呼び出しは**必ず harness の正規 function-call 機構**で行う。応答本文に `call` / `<invoke ...>` / `<parameter ...>` 等のツール呼び出し XML を**テキストとして書かない**。本文に書いても実行されず、`Your tool call was malformed` エラーになる。

- 本文 = ユーザ向けの説明 (日本語 prose) のみ。tool は別チャネルで発火する
- 同じ malformed を繰り返したら**即停止**し、次の発話で正規 tool call をやり直す (テキスト再掲しない)
- `[[feedback-no-raw-text-tool-call]]`

## Collaboration stance (AI = 思考パートナー)

AI を**思考パートナー**として扱う。生成物を盲信せず parent / user 側で検証 (`fact-check on agent return` = `references/developer-agent-delegation-prompt.md` §0.5 B)。subagent report の数値 / file 変更 / 測定値は最低 1 つ cross-check してから採用する。単なる自動実装より、人間検証 + AI 起案の協働が最も効果的 (Anthropic 公式 [How Anthropic teams use Claude Code](https://claude.com/ja/blog/how-anthropic-teams-use-claude-code))。

**Pattern**: developer-agent (Generator) → reviewer-agent / verify-app (Verifier) は Anthropic 公式 [Generator-Verifier pattern](https://claude.com/blog/multi-agent-coordination-patterns) を実装する。Verifier は `status: accept` または `status: reject` + 具体 feedback (file:line / severity / suggested fix) を return、reject feedback を受けた Generator が再生成する 1 round loop を採用する。

## Session Efficiency

**Autonomous mode ON by default + 質問抑制 default**。AskUserQuestion / 確認は exception only。推奨が context から 1 つに絞れるなら質問せず即決、根拠 1 行のみ chat 出力する。質問許可は 4 条件 (破壊的操作 / scope 完全欠落 / 推奨拮抗 / 既存方針競合) のみ。canonical: `rules/minimize-questions.md`。

Confirm only for: destructive ops / external sends / large design branches / flow stage changing next-stage assumptions / re-try right after Esc interrupt (`[[feedback-no-retry-after-interrupt]]`). Long output = conclusion-first + PREP. Decision request = leading `要決定:` block. Token budget: Read with `limit`/`offset` (>200-line files), Bash long output via `| head/tail -N`, code via Serena `find_symbol` over full Read, casual chat via `/btw`. Full list: `references/session-efficiency-detailed.md`. Prompt caching 設計指針: `guidelines/operations/prompt-caching.md`。

## No Derived Literals

Do not write derived values (count / sum / list length) computable from a canonical source as literals in separate files. Reference only. Exceptions: immutable magic numbers / test fixture expected counts. (`[[feedback-no-derived-literals]]`)

## Public-repo private-data block

**ai-tools repo は public**。社内 product 名 / 社内識別子 (`snkrdunk` `@batch_name` `@feature_tag` `recovery-runbook` `pm-consultation-draft` 等) に加え、**個人名 / 会社名 / project 固有名詞** を `~/ai-tools/` 配下 file・commit message に書き込み禁止。`pre-tool-use.sh` が hard block。canonical list: `~/.claude/references-private/private-name-list.txt` (user 記入、AI 読込のみ)。詳細 + allowlist + AI 側 fallback rule: `rules/public-repo-private-data-block.md` (`[[public-repo-social-hit-incident]]`)。

**Hook block / NG-DICTIONARY.md**: AI 定型語 / カタカナ造語禁止 / 難読漢語 / 非日常英語を hook block。`**<name> (block|warn-only)**: <terms>` 形式 canonical。**既存 key (`AI定型語` / `カタカナ造語禁止` / `断定語 (warn-only)`) の name 変更禁止** — hook が exact match 参照。

## Rewind

**Esc**: pause / **Esc ×2** or `/rewind`: restore to checkpoint. Details: `references/checkpoint-rewind.md`

## Context Management

- **>40% → suggest `/compact`**. Task boundary is the best savings point for `/clear` (5+ min idle = cache TTL expired). After 30 min → suggest `/clear` once in chat.
- **Long session = top cost source**: measured (2026-06-19) 150-300 msg session occupies $30-$45 / session cache_read range. `user-prompt-submit.sh` auto-warns at 150 msg (~75 turn) and urgent at 350 msg (~175 turn). On warn, finish current task then `/clear` — cache_read is billed every turn at base-context size.
- **Same problem fails twice in a row → suggest `/clear` + rewrite prompt** (accumulated failure context is the primary failure mode, independent of capacity).
- Continue: "generate next-session mega-prompt" → paste into new session. Uncontaminated question: `/btw`

## Work output routing

進捗 / 永続知識 / session 内 plan の出力先を分離する。

| 種別 | 出力先 | 起動 |
|---|---|---|
| 進捗報告 (status / 着手 / 完了 / blocker / 観測中の事象) | GitHub issue comment | `/post-comment gh-issue-comment` |
| 調査ログ / 手順書 / 計画書 / RCA / postmortem / 監視ログ | local-docs HTML (`projects/` `domain-specs/` `tool-guides/` `operations/`) | `local-docs` skill (trigger 語で auto-fire) |
| session 内一時 plan (phase 分割 / next-action) | `~/.claude/plans/` md | `/plan` (既存) |

**判定 trigger**:

- 「issue に進捗書いて」「ステータス更新」「コメント書いて」「進捗まとめて」 → `/post-comment gh-issue-comment`
- 「調査結果まとめて」「手順書作って」「計画書 doc に」「RCA 書いて」「postmortem 書いて」「監視ログ残して」 → `local-docs` skill (HTML 作成、template 準拠)
- 「impl の phase 分割」「次やること整理」「実装方針」 → `/plan` (md → `~/.claude/plans/`)

**重複回避ルール**:

- `/plan` 出力は session 内 working memo。チーム共有が必要になったら local-docs `plan.html` に昇格する
- issue comment は短文 PREP 3pts (永続知識ではない)。深い調査結果は local-docs に書き、issue から URL link する
- 同じ内容を issue comment と local-docs の両方に書かない (issue = 進捗 + link / local-docs = 知識本体)

## Natural Language Triggers (top 7)

| Input | Action |
|---|---|
| "push" / "pushして" | `/git-push --pr` |
| "全自動で" / "autoで" / "おまかせ" | `/flow-auto` |
| "レビュー" / "レビューして" | `/review` |
| "team で" / "agent team で" / "分担で" / "本格的に" | `/flow` (PO/Manager/Dev hierarchy, forced) |
| "workflow で" / "pipeline で" / "多数決で" | `/workflow` |
| "並列実行で" / "wt 分けて" / "worktree 分けて" / "Developer 並列で" | `/flow --parallel` |
| "test が通るまで" / "lint clean まで" / "build 通るまで loop" | `/goal` (objective stop-condition, Ralph Wiggum guard) |

これ以外の natural-language 解釈はしない。全 list (Slack / Notion / `/api-design` / `/backend-dev` / `/brainstorm` / `/flow --parallel` / `/session-mode` 等): `references/natural-language-triggers.md`

## Git Merge Prohibition

| Operation | Rule |
|---|---|
| PR branch merge (`gh pr merge` etc.) | **Strictly forbidden**. Output PR URL, direct to browser |
| git merge / rebase / branch delete | User confirmation required |
| Circumventing a deny rule with another tool | **Forbidden**. Keep the same intent and ask user (`[[feedback-deny-rule-no-escalation]]`) |

## Definition of Done (DoD)

Apply relevant items only. Scale by change size (typo → #6 / new feature → all): (1) Types 0 errors (2) Tests pass ≥80% (3) Lint 0 (4) Security clean (5) Build success (6) **1 smoke test** (required) (7) For DB changes, verify 4 paths: FK / long TX / replica lag / maintenance scope impact (`[[feedback-db-change-review-blind-spot]]`). Bundle: `/lint-test` / `/verify-once`.

## Root Cause Analysis

Structural fix over symptomatic. **Reproduce → identify → design → verify** 4 steps required. Details: `/root-cause` skill.

Production rollback: use the CI canonical path (revert PR → main merge → deploy) as the primary approach. Direct platform operations (ECS task def rollback etc.) are emergency measures; they will be overwritten on the next deploy, so always run them in parallel with a revert PR (`[[feedback-rollback-via-revert-pr]]`).

## Compounding Engineering

Misbehavior / non-obvious success → document immediately → auto-avoid next session. Misbehavior → record in CLAUDE.md / skill / hook. Append "update CLAUDE.md or related skill" to fix instructions. Details: `references/compounding-engineering-cycle.md`

Memory write target: Claude Code auto-memory only; Serena `.serena/memories/` forbidden — `pre-tool-use.sh` が hard block (`references/compounding-engineering-cycle.md` §Memory write target)

block / warn 系 hook 投入前は latency + flow baseline を必ず記録する (`rules/measure-before-hook-change.md`)

## Pre-write Self-check (except chat)

Before writing any outward-facing text, **read today's commits** (`git log --since=midnight --pretty=format:'%h %s'`). Hook auto-injects before write-type tools (2 sources: working repo + `~/ai-tools` guidelines). Code comments: see `guidelines/writing/code-comment.md`.

## Genshijin Boundary

genshijin (体言止め / 助詞最小) は **chat 応答のみ**。外向き prose (PR / commit / Issue / Slack / Notion / DD / PRD / RCA / comments) と `/plan` `/design-doc` `/prd` `/post-comment` `/git-push --pr` `/docs` ドラフトは plain JP (〜する / 〜した、主語明示、指示語禁止: 「これ」「それ」「上記」→具体名)。Details: `rules/genshijin.md` + `guidelines/writing/PRINCIPLES.md`

**AI定型語 hook block**: 外向き text に AI定型語 (NG-DICTIONARY.md canonical) が含まれると `hooks/pre-tool-use.sh` が exit 2 でブロック。削除・置換して再実行 (`~/.claude/logs/jp-quality-block.log`)。

**Commit message pre-draft sweep** (`[[retrospective-2026-06-12]]` P1): draft 生成前に NG 語 self-check してから出力する。hook block で retry になると 2〜3 往復のトークン損失が発生する。canonical 語彙 list (頻出 block 語 / 連続漢字 / 置換候補) は `guidelines/writing/NG-DICTIONARY.md` 参照。

## Default Readability (全出力 baseline、/jp-writing 不要)

prose 出力に proactive 適用 (hook block 待ち retry を減らす = token 節約)。文体規範 (結論冒頭 / 1 文短く / 連続漢字制限 / 冗長圧縮 / NG 語回避) の canonical は `guidelines/writing/PRINCIPLES.md` + `NG-DICTIONARY.md`。

- 外向き prose・docs は 1 文 100 字 (短文 60 字) 上限、chat は genshijin 継続
- 外向き doc は**種別 guideline を on-demand で 1 本だけ読んで書く** (一覧: `guidelines/writing/README.md`)。常時全ロード禁止
- 深い書き直し / 全観点 self-check 時のみ `/jp-writing`

## Boris-style mapping

Boris Cherny 流 + 公式 best practice の主要 13 tip 反映済 (worktree 並列 / PostCompact reload / Stop hook verify / verifier panel / /workflow / /goal ほか)。未取り込みは third-party 命名の `/loop` `/schedule` のみ。Loop engineering 14-step canonical は `references/loop-engineering.md`。詳細対応表: `references/boris-style-mapping.md`。

## References

High-freq: `references/model-selection.md` / `memory-usage.md` / `performance-insights.md` / `multi-repo-workflow.md` / `references/developer-agent-delegation-prompt.md`
Index: `references/INDEX.md` / Writing: `guidelines/writing/README.md` / Tools: `scripts/health-check.sh` / `usage-stats.sh`
