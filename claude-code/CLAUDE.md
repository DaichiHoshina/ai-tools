# claude-code Directory Config

**Respond in genshijin mode (normal).** No keigo, taigen-dome, minimal particles, preserve technical terms. Switch back to plain JP only for destructive-action confirmations.

This directory manages Claude Code config, skills, hooks.

## Structure

```
claude-code/
├── commands/      Slash command definitions
├── skills/        Skill definitions
├── hooks/         Event hooks
├── guidelines/    Language / design guidelines
├── agents/        Agent definitions
├── references/    Reference docs (load on demand)
└── _archive/      Quarantine (excluded from SYNC_ITEMS, not synced to ~/.claude/)
```

Health check:
- `scripts/health-check.sh [--bench-skip]` — usage-stats + hook-bench combined, markdown output (run monthly)
- `scripts/usage-stats.sh [--days N] [--zero]` — extract commands/skills not called in last N days
- `scripts/hook-bench.sh [--hook NAME]` — hook median/p95 measurement (side-effect hooks skipped)

## Editing Notes

- After `install.sh`/`sync.sh` changes → sync to `~/.claude/` required
- 🔒 PROTECTED SECTION (in CLAUDE.md) must not be modified
- frontmatter (between `---`) must remain valid YAML
- **`claude-code/VERSION` tracks Claude Code CLI release**. Bump only on CLI release intake (`/claude-update-fix` owns it)
- **`claude-code/SERENA_VERSION` tracks Serena MCP release**. Bump only on Serena release intake (`/serena-update-fix` owns it)

## Definition File Token Saving

commands/, skills/, agents/ `.md` files consume tokens every session.

**Keep**: decision tables, workflow defs, operation guards, prohibitions, I/O format (1 example only)
**Remove**: sample impl code, duplicate explanations, detailed usage examples, content duplicated elsewhere
**Target**: agent def ≤300 lines, command def ≤150 lines, skill 100-130 lines

## Discovery / Investigation Routing (anti-overuse)

Agent startup cost (median: dozens of seconds to minutes) is the biggest cost source.

| Scope | Tool |
|---|---|
| 1-2 files / specific symbol | Bash grep/find or `mcp__serena__find_symbol` |
| 3-4 query broad search | `/explore` (2 parallel if ambiguous, all 4 parallel for 3+ domains) |
| Claude Code CLI/SDK/API spec questions | claude-code-guide agent |
| Other genuinely broad analysis | Explore (built-in, last resort) |

**Avoid `general-purpose` agent** (measured highest cost source). Metrics: `references/performance-insights.md`

## Session Efficiency

- Simple fix (1-2 files) → `/dev --quick` or direct
- Complex impl (3+ files) → `/flow` with Agent hierarchy
- Mass file processing (20+) → `claude -p` fan-out (`references/fanout-recipes.md`)
- **Design decisions**: lightweight → `Shift+Tab` native Plan Mode; large-scale strategy → `/plan` (PO agent). **Long brainstorm/design → recommended haiku separate session (`claude --model haiku`), then handoff to Opus for impl** (planning in Opus wastes tokens)
- **Long tasks**: `/rename {type}-{scope}` to identify, `claude --resume` to resume (`references/session-management.md`)
- **Light investigation: no agent startup**: 1-2 queries → grep/find/serena direct
- **Success-criteria principle**: give "what defines success" over procedural steps
- **Verify first**: after impl, always run test/lint/typecheck (DoD below)
- **Minimize confirmation questions**: safe operations → execute without approval. Confirm only for file deletion, deploy, external send
- **Minimize choice presentation**: minor choices → execute recommended directly. Important decisions (architecture, destructive, cost, external send, irreversible) → 2-3 options
- **ROI gate**: even on "do all" instructions, if ultrathink judges "small benefit" → **individually re-confirm** adoption. Don't run all impl on literal instructions (e.g., wasted tokens on low-impact backward-compat hook integration triggered by "all" instruction, 2026-05-07)
- **No hardcoded paths / pwd check**: existence check before Read/Bash, `pwd` check before `cd`
- **Task Diary**: suggest `/memory-save` only on 3+ file changes, non-trivial refactor, or incident response

## Rewind / Checkpoint

- **Esc**: pause (context retained)
- **Esc + Esc** or `/rewind`: restore conversation/code/both to past checkpoint
- Details: `references/checkpoint-rewind.md`

## Context Management

- **Context over 50% → suggest `/compact` at next response start** (do not auto-run)
- Reset context between unrelated tasks with `/clear` (**task boundary = best saving point**. Long chats resend cumulative context every turn → cost grows monotonically per message. 5+ min idle → prompt cache TTL expires → full history cache miss amplifies cost)
- To continue a session: ask "generate next-session mega-prompt" → paste in new session for lightweight resume
- For questions without context pollution: `/btw` (overlay display, not saved to history)

## Natural Language Triggers (major only)

| Input | Action |
|---|---|
| "push", "pushして" | `/git-push --pr` |
| "全自動で", "autoで", "おまかせ" | `/flow-auto` |
| "レビュー", "レビューして" | `/review` (mode auto-inferred) |
| "{strict\|fast\|normal} mode" | `/session-mode {strength}` |
| "並列実行で", "wt 分けて" | `/flow --parallel` |

No other natural-language interpretation (avoid misdetection / token waste). Full list: `references/natural-language-triggers.md`

## Git Merge Prohibition

| Operation | Rule |
|---|---|
| PR branch merge (`gh pr merge` etc) | **Strictly forbidden**. Output PR URL, direct to browser |
| git merge / rebase / branch delete | User confirmation required |

## Definition of Done (DoD)

Concrete form of "verify first". **Apply only relevant items, skip N/A**. Scale by change size (typo → only item 6, new feature → all items).

1. Types: 0 errors (typed languages only)
2. Tests: all related Pass. Coverage ≥ 80% (project standard prioritized)
3. Lint: 0 violations
4. Security: audit clean
5. Build: success
6. **Actual behavior: 1 manual or smoke test confirmation** (mandatory)

Bundle: `/lint-test` (CI-equivalent) / `/verify-once` (structural changes). No completion report if not met.

## Root Cause Analysis

Structural fix over symptomatic. **Reproduce → identify cause → design decision → verify** 4 steps mandatory. Details: `/root-cause` skill, `/protection-mode`.

## Compounding Engineering

Claude misbehavior / non-obvious success = signal that judgment is not yet reflected in config (CLAUDE.md / skill / hook). Immediate documentation → auto-avoidance in next session (Boris-style). 1 documentation removes N future fix iterations → improvements compound.

- **Misbehavior**: document in CLAUDE.md / skill / hook to prevent recurrence
- **Non-obvious success**: rule-ify for reproducibility
- Append "update CLAUDE.md or relevant skill for reproducibility" to fix instructions → triggers config update
- Details: `references/compounding-engineering-cycle.md`, `references/memory-usage.md`

## Detailed References

High frequency: `references/model-selection.md` / `natural-language-triggers.md` / `memory-usage.md` / `performance-insights.md` / `multi-repo-workflow.md`
Topic index: `references/INDEX.md` (others: `ls references/`)

## Writing Guide (PR / commit / Slack / DesignDoc / PRD / RCA)

Before writing or rewriting external-facing prose, consult `guidelines/writing/README.md` as entry point. **Responsibility map + per-medium quick reference** → navigate to relevant file (3-layer structure: rules / guidelines/writing / references).

**genshijin boundary**: genshijin mode (taigen-dome / minimal particles) applies to **chat replies only**. For human-facing prose (PR / commit / Issue / Slack / Notion / DD / PRD / RCA / comments) and draft output from `/plan` `/design-doc` `/prd` `/post-comment` `/git-push --pr` `/docs`, switch to plain JP — full sentences (〜する/〜した), explicit subjects, no demonstratives (「これ」「それ」「上記」→ concrete names). Details: `rules/genshijin.md` 適用範囲 section + `guidelines/writing/PRINCIPLES.md` L66-71 chat vs document table.
