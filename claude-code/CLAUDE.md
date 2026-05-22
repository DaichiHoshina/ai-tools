# claude-code Directory Config

**Respond in genshijin mode (normal).** No keigo, taigen-dome, minimal particles, preserve technical terms. Plain JP only for destructive-action confirmations.

`~/ai-tools/claude-code/` manages Claude Code config (commands / skills / hooks / agents / rules / guidelines / references). Synced to `~/.claude/` via `sync.sh`.

## Editing Rule (data-loss guard)

- **Always edit source `~/ai-tools/claude-code/`. `~/.claude/` direct edits are wiped by `sync.sh to-local`** (applies to CLAUDE.md / commands / skills / hooks / agents / rules / guidelines / config / references)
- 🔒 PROTECTED SECTION in CLAUDE.md must not be modified. YAML frontmatter must remain valid
- `VERSION` / `SERENA_VERSION` bumped only on CLI / Serena release intake (`/claude-update-fix` / `/serena-update-fix`)

## Definition File Token Saving

`.md` in commands/, skills/, agents/ consume tokens every session. Keep: decision tables, workflow defs, operation guards, prohibitions, 1 example. Remove: sample impl, duplicate explanations, detailed usage. Target: agent ≤300 / command ≤150 / skill 100-130 lines.

## Discovery / Investigation Routing (anti-overuse)

Agent startup is the biggest cost source (dozens of seconds to minutes).

| Scope | Tool |
|---|---|
| 1-2 files / specific symbol | Bash grep/find or `mcp__serena__find_symbol` |
| 3-4 query broad search | `Task(explore-agent)` parallel (2 if ambiguous, all 4 for 3+ domains) |
| Claude Code CLI/SDK/API spec | `claude-code-guide` agent |
| Other genuinely broad analysis | Explore (built-in, last resort) |

**Avoid `general-purpose` agent** (measured highest cost source, max 501s). Metrics: `references/performance-insights.md`

## Session Efficiency

- Simple fix (1-2 files) → `/dev --quick` or direct. Complex (3+) → `/flow` Agent hierarchy. Mass (20+) → `claude -p` fan-out (`references/fanout-recipes.md`)
- **Design decisions**: light → `Shift+Tab` Plan Mode / large → `/plan` (PO agent). **Long brainstorm → haiku separate session (`claude --model haiku`), handoff to Opus for impl**
- **Long tasks**: `/rename {type}-{scope}`, `claude --resume` (`references/session-management.md`)
- **Success-criteria principle**: "what defines success" over procedural steps
- **Verify first**: post-impl run test/lint/typecheck (DoD below)
- **MCP tool args は仕様確認してから定義に書く**: `ToolSearch select:<tool>` で param 名確認、LLM 補正に依存しない (2026-05-17: `memory_file_name` / `path=` で発覚)
- **regex 置換後は `git diff --stat` で削除規模即確認**: serena `replace_content` regex は DOTALL/MULTILINE 強制で `.*\n` greedy 食い→全消去事故。1 行は **literal + 行末 `\n`**、複数行は **非貪欲 `.*?` + 明示終端 anchor** (2026-05-18 事故、詳細 `[[serena-replace-regex-dotall-pitfall]]` memory)
- **Minimize confirmation / choice**: safe ops は無確認実行、minor choice は推奨を直接実行。確認は file deletion / deploy / external send / 重要決定 (architecture / cost / 不可逆) のみ
- **ROI gate**: 「全部やって」指示でも ultrathink で「効果小」なら**個別再確認** (2026-05-07 低 ROI 一括実装事故)
- **pwd check**: Read/Bash 前に存在確認、`cd` 前に `pwd`
- **/memory-save**: 3+ file 変更 / 非自明 refactor / incident のみ

## Rewind

- **Esc**: pause (context 保持) / **Esc x2** or `/rewind`: 会話・コード・両方を過去 checkpoint へ復元
- Details: `references/checkpoint-rewind.md`

## Context Management

- **>50% → `/compact` 提案** (auto 実行不可)。task boundary で `/clear` が最良節約点 (5+ min idle = prompt cache TTL 切れ→full cache miss)
- 継続: 「next-session mega-prompt 生成」依頼→新 session に paste
- 汚染なし質問: `/btw` (overlay、history 未保存)

## Natural Language Triggers (major only)

| Input | Action |
|---|---|
| "push" / "pushして" | `/git-push --pr` |
| "全自動で" / "autoで" / "おまかせ" | `/flow-auto` |
| "レビュー" / "レビューして" | `/review` |
| "{strict\|fast\|normal} mode" | `/session-mode {strength}` |
| "並列実行で" / "wt 分けて" | `/flow --parallel` |
| "team で" / "agent team で" / "分担で" / "本格的に" | `/flow` (PO/Manager/Dev 階層 強制) |
| "Slack に投げて" / "Slack に送って" | `mcp__claude_ai_Slack__slack_send_message` |
| "Notion に書いて" / "Notion メモして" | `mcp__claude_ai_Notion__notion-create-pages` |

No other natural-language interpretation. Full list: `references/natural-language-triggers.md`

## Git Merge Prohibition

| Operation | Rule |
|---|---|
| PR branch merge (`gh pr merge` 等) | **Strictly forbidden**. Output PR URL, direct browser |
| git merge / rebase / branch delete | User confirmation required |

## Definition of Done (DoD)

Apply only relevant items, skip N/A. Scale by change size (typo→#6 のみ / 新機能→全部)。

1. Types: 0 errors (typed only)
2. Tests: 関連 Pass、coverage ≥80% (project standard 優先)
3. Lint: 0 violations
4. Security: audit clean
5. Build: success
6. **Actual behavior: 1 manual or smoke test** (必須)

Bundle: `/lint-test` (CI 同等) / `/verify-once` (structural)。未達なら完了報告不可。

## Root Cause Analysis

Structural fix over symptomatic。**Reproduce → identify → design → verify** 4 steps 必須。Details: `/root-cause` skill / `/protection-mode`.

## Compounding Engineering

Claude misbehavior / non-obvious success = config 未反映シグナル。即文書化→次 session 自動回避 (Boris 流)。

- Misbehavior → CLAUDE.md / skill / hook へ記録
- Non-obvious success → ルール化
- fix 指示に「CLAUDE.md or 関連 skill 更新で再現性確保」追記 → config 更新トリガ
- Details: `references/compounding-engineering-cycle.md` / `memory-usage.md`

## Genshijin Boundary

genshijin (体言止め / 助詞最小) は **chat 応答のみ**。外向き prose (PR / commit / Issue / Slack / Notion / DD / PRD / RCA / comments) と `/plan` `/design-doc` `/prd` `/post-comment` `/git-push --pr` `/docs` ドラフトは plain JP (〜する / 〜した、主語明示、指示語禁止: 「これ」「それ」「上記」→具体名)。Details: `rules/genshijin.md` + `guidelines/writing/PRINCIPLES.md`

## References

High freq: `references/model-selection.md` / `natural-language-triggers.md` / `memory-usage.md` / `performance-insights.md` / `multi-repo-workflow.md`
Index: `references/INDEX.md`、Writing entry: `guidelines/writing/README.md`
Tools: `scripts/health-check.sh` (monthly) / `usage-stats.sh` / `hook-bench.sh`
