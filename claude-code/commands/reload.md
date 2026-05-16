---
allowed-tools: Read, mcp__serena__*
description: Restore context - reload CLAUDE.md after compaction to restore session context
effort: low
---

# /reload - Context Restore

Use after compaction (conversation compression) or when saying "continue". Restore context from both CLAUDE.md + Serena memory.

> **Automation**: `/compact` execution auto-runs `post-compact-reload.sh` (SessionStart compact hook) to execute this restore. Manual `/reload` only needed outside compaction.

**vs session-start.sh**: session-start runs auto at session start with Serena state check + memory load. `/reload` is **post-compaction re-restore** only.

## Usage

```bash
/reload
```

## Task Execution

Execute all steps below **automatically**:

### 1. Load CLAUDE.md

Read `$HOME/.claude/CLAUDE.md`, understand instructions.

### 2. Restore Serena Memory (critical)

```
mcp__serena__list_memories
→ 1. load latest 1 compact-restore-* memory (top priority)
→ 2. if today has work-context-*, load it
→ 3. load project-specific memory (if exists)
→ 4. after review, delete loaded compact-restore-* (prevent accumulation)
```

### 3. Load Project CLAUDE.md

If cwd has `CLAUDE.md` or `.claude/rules/`, load it.

### 4. Restore Summary

Report restored info concisely:
- list of loaded memories
- previous task state (from compact-restore)
- what to do next

## "Continue" Alternative

Instead of saying "continue", use `/reload` to:
- prevent post-compaction context loss
- fully restore work state from Serena memory
- resume prior work uninterrupted

ARGUMENTS: $ARGUMENTS
