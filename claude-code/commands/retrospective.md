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

| Source | Command |
|--------|---------|
| usage stats | `ccusage daily --since 7` |
| JP quality blocks | `awk -F' \| ' '$1 >= "2026-06-29T11:21:24+0900" { print }' ~/.claude/logs/jp-quality-block.log \| tail -n 50` |
| hook bench logs | `tail -n 20 ~/.claude/logs/bench-*.log` (glob) |
| /flow baseline TSV | `~/.claude/scripts/flow-baseline.sh --since 7d` (generates `~/.claude/logs/flow-baseline-$(date +%Y%m%d).tsv`) |

> log は a9ebeb5 (2026-06-29) 以降のみ集計する (それ以前は bats test 由来の汚染あり)。

### Phase 2: Signal Extraction (≤500 token output, parent inline only)

| Analysis Target | Extract |
|----------------|---------|
| failure patterns | high-error tasks, retry spikes, dropped tasks |
| inefficiency patterns | churn keywords hit, each-session config explain |
| success patterns | efficient workflows, what-worked approaches |

For each Serena memory name matching a detected signal: `mcp__serena__read_memory(name)` on-demand only.

### Phase 3: Generate Improvements (parallel delegation)

Group signals by domain. ≥2 signals in a domain → `developer-agent` parallel delegation. <2 signals → skip.

| Domain | Content |
|--------|---------|
| new skill | common patterns → skill-ify |
| existing skill | related Qs common → add feature |
| CLAUDE.md addition | recurring confirms → define once |
| hook automation | manual repetition → auto-run |

Delegation rule: 1 domain = 1 agent call. Never bundle multiple domains into 1 prompt.

### Phase 3.5: Accumulate Writing Failure Examples (Compounding Engineering)

If writing failures detected (user feedback "hard to read" / "AI-smelling" / "so what?"), accumulate examples to memory for next session's hook reference.

**Save destination follows Phase 0 selection** (private / public).

Save to: `~/.claude/projects/{project}/memory/writing_failure_{topic}.md` (frontmatter: `name` / `description` / `metadata.type: writing-failure` / `metadata.date`). Sections: What Happened / Relevant Location / Root Cause / Prevention (cite PRINCIPLES.md axis).

Memories injected via `~/.claude/CLAUDE.md` at session start → next session avoids same failure.

### Phase 4: Adopt & Apply

AskUserQuestion → select proposals → implement (new skill / edit existing / add to CLAUDE.md / save memory)

### Phase 5: pending-improvements memory auto-update

Read then re-write `~/.claude/projects/{project}/memory/pending-improvements.md` via `Write` (Serena `write_memory` forbidden — 2026-06-10 decision; avoid dual management; use read-modify-write on auto-memory file):
- Append today's session results to completed list
- Remove consumed items from pending; record unadopted proposals under "remaining"
- Retain on-hold items (tech barrier / trigger unmet)
- Add today's learnings to knowledge section

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

Report for Notion/md for others. Apply `guidelines/writing/long-form-doc.md` principles:

- conclusion (main learnings) first
- "improved" / "efficient" → numbers: frequency / count / time
- "recommend" + 1-line reason
- end with next action (when/who/what)

## Failure Handling

| Situation | Behavior |
|-----------|----------|
| `~/.claude/history.jsonl` missing | skip, continue with Serena memory alone, warn |
| `ccusage` not installed | skip, append "ccusage unavailable" to report |
| log path missing | skip, append "log path missing: {path}" to report |
| Serena memory connect fail | skip, continue with history.jsonl alone, note precision loss |
| recent sessions < 10 | insufficient data, report "accumulating" → done |
| all data fetch fail | cannot generate proposals, guide user to manual review |

## Notes

- History may contain sensitive data. Never send externally
- Always get user approval before applying improvements
- Weekly execution recommended
