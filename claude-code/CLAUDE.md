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

**Golden workflow (頻出 3 種)**

- 実行 mode 判定 → `/plan` (inline / /dev / /workflow / /flow / /flow --auto の 5 択を Step 2 で判定)
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
- Claude Code runs on **latest channel** (switched from stable 2026-06-14); `/claude-update-fix` TARGET is `dist-tags.latest` (details: `commands/claude-update-fix.md`)

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

> explore-agent / root-cause-analyzer を発火した後は、trailer フィールド (`status` / `confidence` / `issues_blocking`) を必ず読む。詳細: `references/agent-output-schema.md`

## Auto-Delegation (parent=Opus orchestrates, subagent=Sonnet executes)

*(For impl/edit tasks. Investigation phase → Discovery Routing)*

**Default = delegate to `developer-agent` (Sonnet)**. Inline execution only for exceptions listed in detailed.md.

Details (delegate threshold / decision principle / parallel fire format / bundle prohibition / parent prep / inline exceptions / trigger table): `references/auto-delegation-detailed.md`

### Parent 監視責任 / 1 dev = 1 file 原則

- **parent 監視責任**: PO / Manager は subagent に丸投げ禁止。bundle 違反は PO Gate で阻止する責任を持つ
- **1 dev = 1 file 原則**: `bundle_justification` なき複数 file fan-out は禁止。Developer は割り当て file 以外を触らない
- **1 Task scope 上限**: 1 Task call の prompt は file 3-5 / 観点 1-2 まで。超えたら単一 message に N Agent 並列発火に分割する。self-check: "1 pass で全部書ききれる量か" No → 分割 (`[[feedback-no-single-agent-overload]]`)
- 違反パターン: 1 Task に複数 file 指定 / Manager が scope 外 commit を Dev に許可する / PO Gate 前に fan-out 確定
- 実証記録: `references/retrospectives/2026-06-19_agent-oversight.md`

## Tool Call Format (生テキスト呼び出し禁止)

ツール呼び出しは**必ず harness の正規 function-call 機構**で行う。応答本文に `call` / `<invoke ...>` / `<parameter ...>` 等のツール呼び出し XML を**テキストとして書かない**。本文に書いても実行されず、`Your tool call was malformed` エラーになる。

- 本文 = ユーザ向けの説明 (日本語 prose) のみ。tool は別チャネルで発火する
- 同じ malformed を繰り返したら**即停止**し、次の発話で正規 tool call をやり直す (テキスト再掲しない)
- `[[feedback-no-raw-text-tool-call]]`

## Session Efficiency

**Autonomous mode ON by default**. Confirm only for: destructive ops / external sends / large design branches / flow stage changing next-stage assumptions / re-try right after Esc interrupt (`[[feedback-no-retry-after-interrupt]]`). Long output = conclusion-first + PREP. Decision request = leading `要決定:` block. Token budget: Read with `limit`/`offset` (>200-line files), Bash long output via `| head/tail -N`, code via Serena `find_symbol` over full Read, casual chat via `/btw`. Full list: `references/session-efficiency-detailed.md`.

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
| "workflow で" / "pipeline で" / "多数決で" | `/workflow` |

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

Memory write target: Claude Code auto-memory only; Serena `.serena/memories/` forbidden (`references/compounding-engineering-cycle.md` §Memory write target)

## Pre-write Self-check (except chat)

Before writing any outward-facing text, **read today's commits** (`git log --since=midnight --pretty=format:'%h %s'`). Hook auto-injects before write-type tools (2 sources: working repo + `~/ai-tools` guidelines). Code comments: see `guidelines/writing/code-comment.md`.

## Genshijin Boundary

genshijin (体言止め / 助詞最小) は **chat 応答のみ**。外向き prose (PR / commit / Issue / Slack / Notion / DD / PRD / RCA / comments) と `/plan` `/design-doc` `/prd` `/post-comment` `/git-push --pr` `/docs` ドラフトは plain JP (〜する / 〜した、主語明示、指示語禁止: 「これ」「それ」「上記」→具体名)。Details: `rules/genshijin.md` + `guidelines/writing/PRINCIPLES.md`

**AI定型語 hook block**: 外向き text に AI定型語 (NG-DICTIONARY.md canonical) が含まれると `hooks/pre-tool-use.sh` が exit 2 でブロック。削除・置換して再実行 (`~/.claude/logs/jp-quality-block.log`)。

**Commit message pre-draft sweep** (`[[retrospective-2026-06-12]]` P1): draft 生成前に以下を self-check してから出力する。hook block で retry になると 2〜3 往復のトークン損失が発生する。
- 頻出 block 語を含まないか: `leverage` / `utilize` / `mitigate` / `踏襲` / `鑑みる` / `喫緊` / `影響なし`
- 連続漢字≥5 を含まないか (例: `整合性担保` → `整合性を保つ` / `変更対象外` → `変更しない`)
- 置換候補は `guidelines/writing/NG-DICTIONARY.md` の `置換候補 (頻出)` key を参照

## Default Readability (全出力 baseline、/jp-writing 不要)

prose 出力に proactive 適用 (hook block 待ち retry を減らす = token 節約)。
- 結論冒頭 / 抽象語は数値・具体例に開く / 1 文短く (読点 3 個まで) / 連続漢字 4 字まで (助詞で開く) / 冗長圧縮 (〜できる) / 弱い表現は断定 or「未確認」明示 / 形式名詞・副詞はひらがな
- AI定型語・カタカナ造語・難読漢語を使わない (`guidelines/writing/NG-DICTIONARY.md`)
- 外向き prose・docs は 1 文 100 字 (短文 60 字) 上限、chat は genshijin 継続
- 外向き doc は**種別 guideline を on-demand で 1 本だけ読んで書く** (commit→`commit-message.md` / PR→`pr-description.md` / DD・RCA→`design-doc-protocol.md`・`long-form-doc.md` / Notion・短文→`external-post.md` / 一覧: `guidelines/writing/README.md`)。常時全ロード禁止
- 深い書き直し / 全観点 self-check 時のみ `/jp-writing` (`guidelines/writing/PRINCIPLES.md`)

## Boris-style mapping

Boris Cherny 流 + 公式 best practice の主要 12 tip 全反映済 (worktree 並列 / PostCompact reload / Stop hook verify / verifier panel / /workflow ほか)。未取り込みは third-party 命名の `/goal` `/loop` `/schedule` のみ。詳細対応表: `references/boris-style-mapping.md`。

## References

High-freq: `references/model-selection.md` / `memory-usage.md` / `performance-insights.md` / `multi-repo-workflow.md` / `references/developer-agent-delegation-prompt.md`
Index: `references/INDEX.md` / Writing: `guidelines/writing/README.md` / Tools: `scripts/health-check.sh` / `usage-stats.sh`
