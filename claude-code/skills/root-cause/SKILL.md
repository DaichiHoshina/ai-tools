---
name: root-cause
description: Root cause analysis (5 Why): bugs to recurrence prevention. Use for RCA.
allowed-tools: Read, Write, Glob, Grep, Bash, Task, AskUserQuestion, mcp__serena__*
model: claude-sonnet-4-6
requires-guidelines:
  - common
  - clean-architecture
parameters:
  depth:
    type: enum
    values: [quick, standard, deep]
    default: standard
  focus:
    type: enum
    values: [all, architecture, logic, data, integration, assumption, environment]
    default: all
---

# root-cause - Root Cause Analysis

Systematically analyze bug/error root causes, propose structural fix strategy.

## Execution Flow

### Step 1: Symptom Documentation

Collect from user: error message, repro steps, impact scope, frequency.

症状 endpoint に視野を閉じない。同時刻に他 endpoint / service でも同一 error signature が出ていないか、および infra メトリクス (DB lock / CPU / write_latency 等) を横断で確認する。canonical: `rules/incident-local-repro-not-root-cause.md`

### Step 2: 5 Why Analysis

Question "why" at each level, gather evidence.

### Step 3: Root Cause Classification

| Category | Description | Typical Complexity |
|---------|------|--------------|
| **Architecture** | Layer violation, component missing | High |
| **Logic** | Algorithm bug, condition error | Medium |
| **Data** | Schema mismatch, migration issue | Medium-High |
| **Integration** | API contract violation, external dep | Medium |
| **Assumption** | Incorrect behavior assumption | Low-Medium |
| **Environment** | Config, infra | Low-Medium |

### Step 4: Fix Strategy Proposal

| Strategy | Recurrence Risk | Recommended |
|------|-----------|------|
| L1: Symptomatic | High | Emergency only |
| L2: Partial | Medium | Time-constrained |
| L3: Root treatment | Low | Recommended |

### Step 5: Detect Similar Issues

Use Serena MCP to search codebase for same pattern.

### Step 6: Report Generation

Save via `Write` to the working repo's `memory/` dir (for ai-tools repo → `~/ai-tools/memory/rca-{date}-{summary}.md`). `~/.claude/projects/<project-key>/memory/` への write は禁止 (CLAUDE.md `## Compounding Engineering`)。Serena `write_memory` も forbidden (2026-06-10 decision, avoid dual management)

## Serena MCP Priority Use

- `mcp__serena__find_symbol` - Symbol search
- `mcp__serena__find_referencing_symbols` - Trace usage
- `mcp__serena__find_implementations` - Detect if a broken interface has multiple impls sharing the root cause (systemic vs local)
- `mcp__serena__search_for_pattern` - Pattern detection
- `mcp__serena__get_symbols_overview` - File structure
- `mcp__serena__get_diagnostics_for_file` - Verify type-safety of the fix post-RCA

## Output Example

```text
## Root Cause Analysis: User Profile Null Error

### 5 Why
1. Why null error? → user.profile is null
2. Why profile null? → API fetch fails, no default value
3. Why no default? → fetchResult type is any
4. Why any type? → No type check at boundary
5. Why no check? → Input validation layer missing (ROOT CAUSE)

### Root Cause: Architecture - Input Validation Layer Missing
Confidence: 92%

### Recommended: L3 Root Treatment
Add Zod validation layer to all API endpoints
Affected: 23 endpoints
```

ARGUMENTS: $ARGUMENTS
