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
| **`general-purpose` agent** | **禁止** — 最高コスト源 (実測 max 501s)。`explore-agent` / `claude-code-guide` / `developer-agent` のいずれかで必ず代替する |

## Auto-Delegation (parent=Opus orchestrates, subagent=Sonnet executes)

*(For impl/edit tasks. Investigation phase → Discovery Routing)*

**Default = delegate to `developer-agent` (Sonnet)**. "If told to do it, Sonnet does it" principle (per user direction 2026-05-22). Inline execution only for exceptions below.

**Delegate threshold**: 2+ files / 10+ lines / 2+ symbols / new file / commit-bearing いずれか → `developer-agent` 委譲。違反は feedback memory 記録。

**Inline exception throttle**: 2 consecutive inline exceptions → next edit-class op は mandatory delegation。Investigation phase 累積 ≥5 → `explore-agent` 切替。

| Trigger | Auto-launch |
|---|---|
| **All impl / edit / commit outside exceptions** | `developer-agent` auto (`Task` tool) |
| broad search (3+ query / 3+ domain) | `explore-agent` parallel auto |
| review request / PR check | `reviewer-agent` auto (or `/review`) |
| unknown bug cause / recurring bug | `root-cause-analyzer` auto |
| design decision / large plan / multi-phase | `po-agent` auto (or `/plan`) |
| multi-stage task (investigate→design→impl→verify) | `/flow` hierarchy (PO→Manager→Dev→Reviewer) |
| 10+ file bulk processing | `claude -p` fan-out (`references/fanout-recipes.md`) |
| **網羅 / 全件 / 一斉 / bulk / 大量 file readonly** | `explore-agent` (read-only) or `developer-agent` (edit) Sonnet 委譲必須 |

詳細 (decision principle / 並列発火書式 / 束ね禁止 / parent 事前準備 / inline exceptions): `references/auto-delegation-detailed.md`

## Session Efficiency

詳細: `references/session-efficiency-detailed.md`。Key: **推奨自走 mode ON** (確認は破壊操作 / external 送信 / 大規模設計分岐 / flow stage で次 stage 前提変える場合のみ、詳細 ref 参照) / **長文 = 冒頭結論 + PREP 法** / **decision 要求 = 冒頭 `要決定:` 枠**

## 派生値禁止 (no derived literals)

canonical source から導出可能な派生値 (count / sum / list 長さ) を別 file に literal で書かない。参照のみ。例外: 不変 magic number / test fixture expected count。(`[[feedback-no-derived-literals]]`)

## Public-repo private-data block

**ai-tools repo は public**。社内 product 名 / 社内識別子 (`snkrdunk` `oripa` `@batch_name` `@feature_tag` `recovery-runbook` `pm-consultation-draft` 等) を `~/ai-tools/` 配下に書き込み禁止。`pre-tool-use.sh` が hard block。詳細 + social-hit term list: `rules/public-repo-private-data-block.md` (`[[public-repo-social-hit-incident]]`)。

**Hook block / NG-DICTIONARY.md**: AI 定型語 / カタカナ造語禁止 / 難読漢語 / 非日常英語を hook block。`**<name> (block|warn-only)**: <terms>` 形式 canonical。**既存 key (`AI定型語` / `カタカナ造語禁止` / `断定語 (warn-only)`) の name 変更禁止** — hook が exact match 参照。

## Rewind

**Esc**: pause / **Esc x2** or `/rewind`: restore to checkpoint. Details: `references/checkpoint-rewind.md`

## Context Management

- **>40% → suggest `/compact`**。task 境界で `/clear` が最大節約点 (5+ min idle = cache TTL 切れ)。30 min 経過 → chat で 1 回 `/clear` 提案。
- **同一問題 2 回連続失敗 → `/clear` + prompt 書き直し提案** (失敗 context 蓄積が主要 failure mode、容量起因とは別軸)。
- Continue: "generate next-session mega-prompt" → 新 session に貼り付け。Uncontaminated question: `/btw`

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

Apply relevant items only. Scale by change size (typo → #6 / new feature → all): (1) Types 0 errors (2) Tests pass ≥80% (3) Lint 0 (4) Security clean (5) Build success (6) **1 smoke test** (required). Bundle: `/lint-test` / `/verify-once`.

## Root Cause Analysis

Structural fix over symptomatic. **Reproduce → identify → design → verify** 4 steps required. Details: `/root-cause` skill.

## Compounding Engineering

Misbehavior / non-obvious success → document immediately → auto-avoid next session. Misbehavior → CLAUDE.md / skill / hook 記録。Fix 指示に "update CLAUDE.md or related skill" 追記。Details: `references/compounding-engineering-cycle.md`

## 書く前の自己確認 (chat 除く)

外向き文章は **今日の commit を read してから書く** (`git log --since=midnight --pretty=format:'%h %s'`)。hook が書く系 tool 直前に自動 inject (2 source: 作業 repo + `~/ai-tools` guidelines)。コードコメント: `guidelines/writing/code-comment.md` 参照。

## Genshijin Boundary

genshijin (体言止め / 助詞最小) は **chat 応答のみ**。外向き prose (PR / commit / Issue / Slack / Notion / DD / PRD / RCA / comments) と `/plan` `/design-doc` `/prd` `/post-comment` `/git-push --pr` `/docs` ドラフトは plain JP (〜する / 〜した、主語明示、指示語禁止: 「これ」「それ」「上記」→具体名)。Details: `rules/genshijin.md` + `guidelines/writing/PRINCIPLES.md`

**AI定型語 hook block**: 外向き text に AI定型語 (NG-DICTIONARY.md canonical) が含まれると `hooks/pre-tool-use.sh` が exit 2 でブロック。削除・置換して再実行 (`~/.claude/logs/jp-quality-block.log`)。

## References

High freq: `references/model-selection.md` / `memory-usage.md` / `performance-insights.md` / `multi-repo-workflow.md` / `references/developer-agent-delegation-prompt.md`
Index: `references/INDEX.md` / Writing: `guidelines/writing/README.md` / Tools: `scripts/health-check.sh` / `usage-stats.sh`
