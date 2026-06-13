# claude-code Directory Config

**Respond in genshijin mode (normal).** No keigo, taigen-dome, minimal particles, preserve technical terms. Plain JP only for destructive-action confirmations.

`~/ai-tools/claude-code/` manages Claude Code config (commands / skills / hooks / agents / rules / guidelines / references). Synced to `~/.claude/` via `sync.sh`.

## Quick Reference

```bash
cd ~/ai-tools/claude-code
npm test                    # jest (statusline 等 JS test)
bats -r tests/              # bash hook / lib / scripts の bats 全実行
./sync.sh to-local --yes    # repo → ~/.claude 反映 (非対話)
./scripts/hook-bench.sh     # hook latency 計測 (warmup=5 / runs=15)
```

## Editing Rule (data-loss guard)

- **Always edit source `~/ai-tools/claude-code/`. `~/.claude/` direct edits are wiped by `sync.sh to-local`** (applies to CLAUDE.md / commands / skills / hooks / agents / rules / guidelines / config / references)
- **root keys (`env` / `model` / `statusLine` / `permissions` / `sandbox` / `worktree` / `enabledPlugins` / `extraKnownMarketplaces` / `autoUpdatesChannel` and all allowlisted root keys) are template canonical**; `to-local` overwrites entirely. Live additions are wiped. Add settings via template edit → `to-local` (exceptions: `hooks` / `skillOverrides` have dedicated merge logic)
- 🔒 PROTECTED SECTION in CLAUDE.md must not be modified. YAML frontmatter must remain valid
- `VERSION` / `SERENA_VERSION` bumped only on CLI / Serena release intake (`/claude-update-fix` / `/serena-update-fix`)
- Claude Code runs on **stable channel**; `/claude-update-fix` TARGET is `dist-tags.stable`; `latest` tag is forbidden (details: `commands/claude-update-fix.md`)

## Definition File Token Saving

`.md` in commands/, skills/, agents/ consume tokens every session. Keep: decision tables, workflow defs, operation guards, prohibitions, 1 example. Remove: sample impl, duplicate explanations, detailed usage. Target: agent ≤300 / command ≤150 / skill 100-130 lines.

**EN-conversion-protected files/sections**: see `rules/en-conversion-protected.md` (mistranslation breaks rules, bats tests, JP trigger matching).

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

## Auto-Delegation (parent=Opus orchestrates, subagent=Sonnet executes)

*(For impl/edit tasks. Investigation phase → Discovery Routing)*

**Default = delegate to `developer-agent` (Sonnet)**. "If told to do it, Sonnet does it" principle (per user direction 2026-05-22). Inline execution only for exceptions listed in detailed.md.

Details (delegate threshold / decision principle / parallel fire format / bundle prohibition / parent prep / inline exceptions / trigger table): `references/auto-delegation-detailed.md`

## Session Efficiency

Details: `references/session-efficiency-detailed.md`. Key: **autonomous mode ON by default** (confirm only for: destructive ops / external sends / large design branches / flow stage that changes next-stage assumptions / **re-try of same op immediately after Esc interrupt** (`[[feedback-no-retry-after-interrupt]]`); see ref for full list) / **long output = conclusion first + PREP structure** / **decision request = leading `要決定:` block** / **Token budget**: Read with `limit`/`offset` (>200-line files), Bash long output via `| head -N` / `| tail -N`, code via Serena symbolic (`find_symbol` > full Read), casual chat via `/btw` to avoid history pollution

## No Derived Literals

Do not write derived values (count / sum / list length) computable from a canonical source as literals in separate files. Reference only. Exceptions: immutable magic numbers / test fixture expected counts. (`[[feedback-no-derived-literals]]`)

## Public-repo private-data block

**ai-tools repo は public**。社内 product 名 / 社内識別子 (`snkrdunk` `@batch_name` `@feature_tag` `recovery-runbook` `pm-consultation-draft` 等) に加え、**個人名 / 会社名 / project 固有名詞** を `~/ai-tools/` 配下 file・commit message に書き込み禁止。`pre-tool-use.sh` が hard block。canonical list: `~/.claude/references-private/private-name-list.txt` (user 記入、AI 読込のみ)。詳細 + allowlist + AI 側 fallback rule: `rules/public-repo-private-data-block.md` (`[[public-repo-social-hit-incident]]`)。

**Hook block / NG-DICTIONARY.md**: AI 定型語 / カタカナ造語禁止 / 難読漢語 / 非日常英語を hook block。`**<name> (block|warn-only)**: <terms>` 形式 canonical。**既存 key (`AI定型語` / `カタカナ造語禁止` / `断定語 (warn-only)`) の name 変更禁止** — hook が exact match 参照。

## Rewind

**Esc**: pause / **Esc ×2** or `/rewind`: restore to checkpoint. Details: `references/checkpoint-rewind.md`

## Context Management

- **>40% → suggest `/compact`**. Task boundary is the best savings point for `/clear` (5+ min idle = cache TTL expired). After 30 min → suggest `/clear` once in chat.
- **Same problem fails twice in a row → suggest `/clear` + rewrite prompt** (accumulated failure context is the primary failure mode, independent of capacity).
- Continue: "generate next-session mega-prompt" → paste into new session. Uncontaminated question: `/btw`

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
| "API 設計" / "API 設計して" | `/api-design` |
| "バックエンド" / "バックエンド実装" | `/backend-dev` |
| "ブレスト" / "アイデア出し" | `/brainstorm` |

No other natural-language interpretation. Full list: `references/natural-language-triggers.md`

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

Memory write target: Claude Code auto-memory (`~/.claude/projects/.../memory/`) only. Writing to Serena `.serena/memories/` is forbidden (avoid dual management, decided 2026-06-10)

## Pre-write Self-check (except chat)

Before writing any outward-facing text, **read today's commits** (`git log --since=midnight --pretty=format:'%h %s'`). Hook auto-injects before write-type tools (2 sources: working repo + `~/ai-tools` guidelines). Code comments: see `guidelines/writing/code-comment.md`.

## Genshijin Boundary

genshijin (体言止め / 助詞最小) は **chat 応答のみ**。外向き prose (PR / commit / Issue / Slack / Notion / DD / PRD / RCA / comments) と `/plan` `/design-doc` `/prd` `/post-comment` `/git-push --pr` `/docs` ドラフトは plain JP (〜する / 〜した、主語明示、指示語禁止: 「これ」「それ」「上記」→具体名)。Details: `rules/genshijin.md` + `guidelines/writing/PRINCIPLES.md`

**AI定型語 hook block**: 外向き text に AI定型語 (NG-DICTIONARY.md canonical) が含まれると `hooks/pre-tool-use.sh` が exit 2 でブロック。削除・置換して再実行 (`~/.claude/logs/jp-quality-block.log`)。

**Commit message pre-draft sweep** (top-6 over 7d, `[[retrospective-2026-06-12]]` P1): avoid `鑑みる` `踏襲` `喫緊` `leverage` `utilize` `mitigate` — **check before writing**. Alternatives: `踏まえる` / `引き継ぐ` / `直近` / `使う` / `活かす` / `緩和する` etc. 787 blocks/week is the main cause of retry loops.

## Default Readability (全出力 baseline、/jp-writing 不要)

prose 出力に下記を proactive 適用する (hook block 待ちの retry を減らす = token 節約)。
- 結論を冒頭に書く / 抽象語は数値・具体例に開く / 1 文を短く (読点 3 個まで)
- AI定型語・カタカナ造語・難読漢語を使わない (canonical: `guidelines/writing/NG-DICTIONARY.md`)
- 外向き prose・docs は 1 文 100 字 (短文 60 字) 上限、chat は genshijin を継続
- 深い書き直し / 全観点 self-check が要る時のみ `/jp-writing`。詳細規範: `guidelines/writing/PRINCIPLES.md`

## References

High-freq: `references/model-selection.md` / `memory-usage.md` / `performance-insights.md` / `multi-repo-workflow.md` / `references/developer-agent-delegation-prompt.md`
Index: `references/INDEX.md` / Writing: `guidelines/writing/README.md` / Tools: `scripts/health-check.sh` / `usage-stats.sh`
