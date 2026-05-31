---
allowed-tools: Read, Glob, Grep, Bash, mcp__serena__*
description: Retrospective - analyze past sessions, auto-propose skill/config improvements
---

# /retrospective - Session Review & Self-improvement

Analyze past session history and work records, auto-generate improvement proposals.

## Execution Flow

### Phase 1: Data Collection

**history.jsonl** — timestamp filter (last 7 days), then grep churn signals:

```bash
jq 'select(.timestamp > (now - 604800))' ~/.claude/history.jsonl \
  | grep -E '再度|もう一度|やり直|違う|stop|cancel|wrong'
```

**Serena memory** — `mcp__serena__list_memories` (name + description only); full body loaded on-demand in Phase 2.

**Additional sources** (skip with 1-line note if missing):

| Source | Command |
|--------|---------|
| usage stats | `ccusage daily --since 7` |
| JP quality blocks | `tail -n 50 ~/.claude/logs/jp-quality-block.log` |
| hook bench logs | `tail -n 20 ~/.claude/logs/bench-*.log` (glob) |

### Phase 2: Signal Extraction (≤500 token output, parent inline only)

| Analysis Target | Extract |
|----------------|---------|
| failure patterns | high-error tasks, retry spikes, dropped tasks |
| inefficiency patterns | churn keywords hit, each-session config explain |
| success patterns | efficient workflows, what-worked approaches |

For each Serena memory name that matches a detected signal: `mcp__serena__read_memory(name)` on-demand only.

### Phase 3: Generate Improvements (parallel delegation)

Group signals by domain. For each domain with ≥2 signals → `developer-agent` parallel delegation. Domains with <2 signals → skip.

| Domain | Content |
|--------|---------|
| new skill | common patterns → skill-ify |
| existing skill | related Qs common → add feature |
| CLAUDE.md addition | recurring confirms → define once |
| hook automation | manual repetition → auto-run |

Delegation rule: 1 domain = 1 agent call. Never bundle multiple domains into 1 prompt.

### Phase 3.5: Accumulate Writing Failure Examples (Compounding Engineering)

If writing failures detected (user feedback "hard to read" / "AI-smelling" / "so what?"), accumulate examples to memory for next session's hook reference.

Save to: `~/.claude/projects/{project}/memory/writing_failure_{topic}.md`

Format:
```markdown
---
name: writing-failure-{topic}
description: {1-line failure pattern summary}
metadata:
  type: writing-failure
  date: YYYY-MM-DD
---

## What Happened
{user's specific feedback}

## Relevant Location
{file:line or excerpt}

## Root Cause
{AI side root cause. e.g., stacked abstract nouns / implicit knowledge / ambiguous paragraph role}

## Prevention
{how to avoid next time. cite relevant axis from PRINCIPLES.md}
```

Memories injected via `~/.claude/CLAUDE.md` at session start → next session avoids same failure.

### Phase 4: Adopt & Apply

AskUserQuestion → select proposals → implement (new skill / edit existing / add to CLAUDE.md / save memory)

### Phase 5: pending-improvements memory 自動更新

採用結果と本日完了項目を `mcp__serena__write_memory(memory_name="pending-improvements", ...)` で更新。
- 完了済リストに本日のセッション成果を追記
- 残項目から消化分を除外、未採用提案は「残」に記録
- 保留中項目 (技術障壁/発火条件未達) は維持
- 知見セクションに本日学習を追加

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
- "recommend" + 1-line rationale
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
- weekly execution recommended
