---
allowed-tools: Read, Glob, Grep, Bash, mcp__serena__*
description: Retrospective - analyze past sessions, auto-propose skill/config improvements
---

# /retrospective - Session Review & Self-improvement

Analyze past session history and work records, auto-generate improvement proposals.

## Execution Flow

### Phase 1: Data Collection

- Session history: `~/.claude/history.jsonl` (recent 100)
- past TODOs: `~/.claude/todos/`
- Serena memory: `mcp__serena__list_memories` → load each

### Phase 2: Pattern Analysis

| Analysis Target | Extract |
|---------|---------|
| failure patterns | high-error tasks, retry spikes, dropped tasks |
| inefficiency patterns | repeated questions, each-session config explain, manual iteration churn |
| success patterns | efficient workflows, what-worked approaches |

### Phase 3: Generate Improvements

| Category | Content |
|---------|------|
| new skill proposal | common patterns → skill-ify |
| existing skill improvement | related Qs common → add feature |
| CLAUDE.md addition | recurring confirms → define once |
| hook automation | manual repetition → auto-run |

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

Accumulated memories injected via `~/.claude/CLAUDE.md` at session start, so next session avoids same failure.

### Phase 4: Adopt & Apply

AskUserQuestion → select proposals → implement (new skill / edit existing / add to CLAUDE.md / save memory)

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
| `~/.claude/history.jsonl` missing | continue with Serena memory alone, warn |
| Serena memory connect fail | continue with history.jsonl alone, note precision loss |
| recent sessions < 10 | insufficient data, report "accumulating" → done |
| all data fetch fail | cannot generate proposals, guide user to manual review |

## Notes

- History may contain sensitive data. Never send externally
- Always get user approval before applying improvements
- weekly execution recommended
