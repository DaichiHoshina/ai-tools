---
allowed-tools: Write, Read
description: Quick auto-memory save — record current work state to ~/.claude/projects/.../memory/
effort: low
---

# /memory-save - Quick auto-memory save

Save current work state to Claude Code auto-memory (`~/.claude/projects/<project-key>/memory/`) in 1 command.

> **CLAUDE.md compliant**: Write to Serena `.serena/memories/` is forbidden (avoid dual management, 2026-06-10 decision). This command writes to auto-memory only.

## Flow

1. **Auto-generate save content** (7 fields: task / progress / files / next-action / project / last 3 messages / skill)
2. **Auto-determine memory name**: from arg or auto-named `work-context-YYYYMMDD-<topic>`
3. **Save**: Write tool to `~/.claude/projects/-Users-daichi-hoshina-ai-tools/memory/<name>.md`
4. **Update MEMORY.md**: append 1-line entry at end (`- [Title](file.md) — one-line hook`)
5. **Confirm**: output saved path + summary to chat

## File format

```yaml
---
name: <kebab-case-slug>
description: <one-line summary>
metadata:
  type: project
---

<body 7 field>
```

## Options

| Arg | Description | Example |
|-----|-------------|---------|
| (none) | auto-name (`work-context-YYYYMMDD-<topic>`) | `/memory-save` |
| `<name>` | specify memory name | `/memory-save auth-refactor-progress` |

## When to use

- Mid-point save for long tasks
- Manual backup before compact (`/compact`)
- Hand-off to next session

## Fallback

| Scenario | Action |
|----------|--------|
| memory dir 不在 | `mkdir -p` で作成 |
| Write 権限 fail | content を chat 出力、user に手動 save 案内 |
| name 衝突 | auto-suffix `-2`, `-3` |

ARGUMENTS: $ARGUMENTS
