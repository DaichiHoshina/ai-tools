# Root Cause Analysis Framework

## 5 Why Analysis Template

```text
Level 1: Why [symptom]? → [immediate cause]
  Evidence: [code, logs, config]
  Confidence: {0-100}%

Level 2: Why [immediate cause]? → [intermediate cause]
  Evidence: [code, logs, config]
  Confidence: {0-100}%

Level 3: Why [intermediate cause]? → [deep cause]
  Evidence: [code, logs, config]
  Confidence: {0-100}%

Level 4: Why [deep cause]? → [structural cause]
  Evidence: [code, logs, config]
  Confidence: {0-100}%

Level 5: Why [structural cause]? → [root cause]
  Evidence: [code, logs, config]
  Confidence: {0-100}%
```

**Depth parameter**:
- `quick`: Levels 1-3 (simple bugs)
- `standard`: Levels 1-5 (default)
- `deep`: Levels 1-5 + exhaustive pattern search

**Confidence threshold**: ≥85% = reliable. Below: investigate further.

## Fix Strategy (3 Levels)

### L1: Symptomatic Fix (Not recommended)

| Item | Note |
|------|------|
| Risk | Low |
| Recurrence risk | High |
| Action | Suppress symptom directly |
| Example | Add Number() cast, add null check |
| When | Emergency only, requires TODO |

### L2: Partial Fix

| Item | Note |
|------|------|
| Risk | Medium |
| Recurrence risk | Medium |
| Action | Fix direct cause, similar issues remain |
| Example | Add validation to this endpoint |
| When | Time-constrained situations |

### L3: Root Fix (Recommended)

| Item | Note |
|------|------|
| Risk | High (broad change scope) |
| Recurrence risk | Low |
| Action | Remove structural cause |
| Example | Add Zod validation to all endpoints |
| When | Preferred approach when possible |

Present pros/cons/effort/risk for each, ask user to choose.

## Similar Pattern Detection

Search codebase with Serena MCP:

- `mcp__serena__search_for_pattern`: Find same pattern across codebase
- `mcp__serena__find_symbol`: Find related symbols
- `mcp__serena__find_referencing_symbols`: Find affected locations

Output:
- List of matching locations
- Impact level (high/medium/low) per location
- Fix priority order

## Report Template

```markdown
# Root Cause Analysis Report

## Symptom
{symptom details}

## 5 Why Analysis
{results per level}

## Root Cause
- Category: {Architecture|Logic|Data|Integration|Assumption|Environment}
- Description: {explanation}
- Confidence: {0-100}%

## Fix Strategies
### L1: Symptomatic
{details, pros/cons}

### L2: Partial
{details, pros/cons}

### L3: Root (Recommended)
{details, pros/cons}

## Similar Issues
{detected patterns list}

## Recommended Action
{concrete fix steps}
```

Save to Claude Code auto-memory (Serena `write_memory` forbidden — 2026-06-10 decision):
```text
Write → ~/.claude/projects/<project-key>/memory/rca-{date}-{summary}.md
```
