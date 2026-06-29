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
/reload                                          # fallback chain (compact-restore → today work-context)
/reload work-context-20260629-foo                # 名指し fast path (~/ai-tools/memory/<name>.md)
/reload foo                                      # prefix match (work-context-*-foo を 1 件)
```

`/memory-save clear` が pbcopy する `/reload <name>` が paste されると名指し経路で確実復元する。

## Task Execution

Auto-execute the following:

### 1. Load CLAUDE.md

Read `$HOME/.claude/CLAUDE.md` and internalize instructions.

### 2. Restore auto-memory

`$ARGUMENTS` (topic / name) が指定された場合は**それを最優先 Read**、未指定時のみ fallback chain。

```text
If $ARGUMENTS non-empty:
  1. Read ~/ai-tools/memory/<arg>.md (拡張子なし指定でも .md 補完)
  2. file 不在なら ~/ai-tools/memory/ から prefix match で 1 件 Read
  3. それでも不在なら fallback chain に降りる
Else (fallback chain):
  1. ls ~/.claude/projects/-Users-daichi-hoshina-ai-tools/memory/compact-restore-*.md
     → Read the latest mtime (top priority)
  2. Read ~/ai-tools/memory/work-context-$(date +%Y%m%d)-*.md (today 分全件)
  3. Read project-specific memory (style_and_conventions.md etc.) if present
  4. rm loaded compact-restore-* (prevent accumulation)
```

`$ARGUMENTS` 経路は `/memory-save clear` が pbcopy した `/reload <name>` を確実に拾うための fast path。

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
