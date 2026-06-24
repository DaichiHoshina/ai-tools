---
allowed-tools: Read, Bash
description: Restore context - reload CLAUDE.md + auto-memory after compaction
argument-hint: "[topic]"
effort: low
---

# /reload - Context Restore

Use after compaction (conversation compression) or when saying "continue". Restore context from CLAUDE.md + Claude Code auto-memory.

> **Automation**: `/compact` triggers `post-compact-reload.sh` (PostCompact hook) automatically. Manual `/reload` needed only for non-compact context restore.

> **vs session-start.sh**: session-start runs auto at session start with memory load. `/reload` is **post-compaction re-restore** only.

> **CLAUDE.md compliance**: Serena `.serena/memories/` is read/write forbidden. Use auto-memory (`~/.claude/projects/.../memory/`) only.

## Usage

```bash
/reload
```

## Task Execution

Auto-execute the following:

### 1. Load CLAUDE.md

Read `$HOME/.claude/CLAUDE.md` and internalize instructions.

### 2. Restore auto-memory

```text
1. ls ~/.claude/projects/-Users-daichi-hoshina-ai-tools/memory/compact-restore-*.md
   → Read the latest mtime (top priority)
2. Read work-context-*.md for today if present
3. Read project-specific memory (style_and_conventions.md etc.) if present
4. rm loaded compact-restore-* (prevent accumulation)
```

### 3. Load Project CLAUDE.md

If cwd has `CLAUDE.md` / `.claude/rules/`, Read them.

### 4. Restore Summary

Report summary to chat:
- Loaded memory list
- Previous task state (from compact-restore)
- Next actions

## "Continue" Alternative

Use `/reload` instead of "continue":
- Prevents post-compaction context loss
- Full restore from auto-memory
- Immediate resume of interrupted work

ARGUMENTS: $ARGUMENTS
