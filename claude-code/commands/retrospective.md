---
allowed-tools: Read, Write, Glob, Grep, Bash, mcp__serena__*
argument-hint: "[--days N] [--scope <topic>]"
description: Retrospective - analyze past sessions, auto-propose skill/config improvements
---

# /retrospective - Session Review & Self-improvement

Analyze past session history and work records; auto-generate improvement proposals.

## Execution Flow

### Phase 0: Save destination (before investigation)

Ask user via AskUserQuestion.

- question: "retrospective 保存先を選んでください"
- options:
  1. `private` (default): `~/.claude/references-private/retrospective/YYYY-MM-DD_<slug>.md`
  2. `public`: `docs/reports/retrospective/YYYY-MM-DD_<slug>.md`

**Default = private**. Select `public` only when explicitly chosen (prevents private data leak).

**On public selection**:

- Echo `rules/public-repo-private-data-block.md` reference at top of doc
- Verify no social-hit terms in analyzed sessions before saving

### Phase 1: Data Collection

**history.jsonl** — timestamp filter (last 7 days), then grep churn signals:

```bash
jq 'select(.timestamp > ((now - 604800) * 1000))' ~/.claude/history.jsonl \
  | grep -E '再度|もう一度|やり直|違う|stop|cancel|wrong'
```

**Serena memory** — `mcp__serena__list_memories` (name + description only); full body loaded on-demand in Phase 2.

**Additional sources** (skip with 1-line note if missing):

| Source             | Command                                                                                                        |
| ------------------ | -------------------------------------------------------------------------------------------------------------- |
| usage stats        | `ccusage daily --since 7` (未 install なら `npm install -g ccusage` を user へ案内、AI は auto install しない)     |
| JP quality blocks  | `awk -F' \| ' '$1 >= "2026-06-29T11:21:24+0900" { print }' ~/.claude/logs/jp-quality-block.log \| tail -n 50`  |
| session split logs | `tail -n 20 ~/.claude/logs/session-split-warn.log`                                                             |
| /flow baseline TSV | `~/.claude/scripts/flow-baseline.sh --since 7d` (generates `~/.claude/logs/flow-baseline-$(date +%Y%m%d).tsv`) |
| sleep harvest digest | `~/ai-tools/claude-code/scripts/sleep-harvest.sh --days 7` (churn / logs / skill-eval を一括集計する。上記個別 command の代替に使ってよい) |
| sleep proposals | `Glob ~/ai-tools/memory/sleep-proposals-*.md` — staged は `/sleep-review` へ誘導し、`.rejected.md` は reject 理由を signal として読む |

**Cursor sources** (skip with 1-line note if missing):

| Source | Command |
|--------|---------|
| settings drift | `cd ~/ai-tools/cursor && ./sync.sh diff` |
| global rules | `Glob ~/ai-tools/cursor/rules/*.mdc` → Read |
| project memories | `Glob .cursor/memories/*.md` → Read (ai-tools: `~/ai-tools/.cursor/memories/`) |
| project rules | `Glob .cursor/rules/*.mdc` (if present) |
| maintenance checklist | Read `~/ai-tools/cursor/MAINTENANCE.md` — list items still marked `- [ ]` |

> log は a9ebeb5 (2026-06-29) 以降のみ集計する (a9ebeb5 (2026-06-29) 以前は bats test 由来の汚染あり)。

### Phase 2: Signal Extraction (≤500 token output, parent inline only)

| Analysis Target       | Extract                                         |
| --------------------- | ----------------------------------------------- |
| failure patterns      | high-error tasks, retry spikes, dropped tasks   |
| inefficiency patterns | churn keywords hit, each-session config explain |
| success patterns      | efficient workflows, what-worked approaches     |
| Cursor friction       | settings drift (sync diff), rules/memory contradiction, Cursor-only retries |
| Cursor staleness      | old `更新:` dates, dead paths in `.cursor/memories/` |

For each Serena memory name matching a detected signal: `mcp__serena__read_memory(name)` on-demand only.

### Phase 3: Generate Improvements (parallel delegation)

Group signals by domain. ≥2 signals in a domain → `developer-agent` parallel delegation. <2 signals → skip.

| Domain             | Content                          |
| ------------------ | -------------------------------- |
| new skill          | common patterns → skill-ify      |
| existing skill     | related Qs common → add feature  |
| CLAUDE.md addition | recurring confirms → define once |
| hook automation    | manual repetition → auto-run     |
| cursor config      | settings/rules/memories drift → edit `cursor/` or `/cursor-review` |
| cursor rule        | recurring Cursor agent behavior → update `ai-tools-agent.mdc` or `.cursor/rules/` |

Delegation rule: 1 domain = 1 agent call. Never bundle multiple domains into 1 prompt.

追加系の提案 (new skill / hook / command) は lifecycle gate (摩擦 evidence + cap、`references/on-demand-rules/toolchain-lifecycle.md`) を通る前提で書く。

### Phase 3.5: Accumulate Writing Failure Examples (Compounding Engineering)

If writing failures detected (user feedback "hard to read" / "AI-smelling" / "so what?"), accumulate examples to memory for next session's hook reference.

Save to: `~/ai-tools/memory/writing_failure_{topic}.md` (frontmatter: `name` / `description` / `metadata.type: writing-failure` / `metadata.date`). Sections: What Happened / Relevant Location / Root Cause / Prevention (cite PRINCIPLES.md axis).

### Phase 4: Adopt & Apply

AskUserQuestion → select proposals → implement (new skill / edit existing / add to CLAUDE.md / save memory)

### Phase 5: pending-improvements memory auto-update

Read then re-write `~/ai-tools/memory/pending-improvements.md` via `Write` (Serena `write_memory` forbidden — 2026-06-10 decision; avoid dual management; use read-modify-write on auto-memory file):

- Append today's session results to completed list
- Remove consumed items from pending; record unadopted proposals under "remaining"
- Retain on-hold items (tech barrier / trigger unmet)
- Add today's learnings to knowledge section
- Cursor improvements: tag `[cursor]` in pending; link `cursor/MAINTENANCE.md` item when applicable

## Output Format

```markdown
# Retrospective Report

## Analysis Period: YYYY-MM-DD ~ YYYY-MM-DD (recent N)

## Problem Patterns (frequency: high/mid/low)

## Success Patterns

## Improvement Proposals (new skill / existing / auto-run) each: name, why, priority

## Next Steps
```

## Output Prose

Notion/md 向け prose は canonical `guidelines/writing/long-form-doc.md` に従う (conclusion-first / 数値化 / 推奨 + 理由 / next action)。

## Failure Handling

| Situation                         | Behavior                                                     |
| --------------------------------- | ------------------------------------------------------------ |
| `~/.claude/history.jsonl` missing | skip, continue with Serena memory alone, warn                |
| `ccusage` not installed           | skip, append "ccusage unavailable" to report                 |
| log path missing                  | skip, append "log path missing: {path}" to report            |
| Serena memory connect fail        | skip, continue with history.jsonl alone, note precision loss |
| recent sessions < 10              | insufficient data, report "accumulating" → done              |
| all data fetch fail               | cannot generate proposals, guide user to manual review       |

## Notes

- History may contain sensitive data. Never send externally
- Always get user approval before applying improvements
- Weekly execution recommended
