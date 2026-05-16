---
name: root-cause
description: Root cause analysis (5 Why). Identify bug causes, prevent recurrence, structural fix strategy. Use when analyzing root causes.
allowed-tools: Read, Glob, Grep, Bash, Task, AskUserQuestion, mcp__serena__*
model: sonnet
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

Save to Serena Memory: `mcp__serena__write_memory("rca-{date}-{summary}", content)`

## Serena MCP Priority Use

- `mcp__serena__find_symbol` - Symbol search
- `mcp__serena__find_referencing_symbols` - Trace usage
- `mcp__serena__search_for_pattern` - Pattern detection
- `mcp__serena__get_symbols_overview` - File structure

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
