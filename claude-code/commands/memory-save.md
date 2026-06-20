---
allowed-tools: Write, Read, Bash
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

> Open consecutive kanji of 5+ chars with a particle (e.g. 「並列実装可能」→「並列で実装できる」).

## Options

| Arg | Description | Example |
|-----|-------------|---------|
| (none) | auto-name (`work-context-YYYYMMDD-<topic>`) | `/memory-save` |
| `<name>` | specify memory name | `/memory-save auth-refactor-progress` |
| `clear` | save (auto-name) + prep for `/clear`: copy `/reload <name>` to clipboard after save, ready for next session | `/memory-save clear` |
| `exit` | save (auto-name) + task-end notice: show saved path + "restore with `/reload <name>` in next session" only. No clipboard copy (assumes CLI `exit` to separate task) | `/memory-save exit` |

## `clear` argument post-processing

Only when `$ARGUMENTS == "clear"`, after save:

1. Store the saved memory name (slug including auto-name topic)
2. Run `printf '/reload %s' "<name>" | pbcopy` (no newline, paste-to-run)
3. Report "`/reload <name>` copied to clipboard. Paste after `/clear` to resume"
4. User runs `/clear` manually (do not auto-fire)

Fallback if `pbcopy` absent (Linux): try `xclip -selection clipboard` → `wl-copy`; if neither, output literal to chat and guide manual copy.

## `exit` argument post-processing

Only when `$ARGUMENTS == "exit"`, after save. Assumes clean task exit via CLI `exit` — no clipboard / next-session prep needed.

1. Output absolute path of saved memory file
2. Show "to restore in next session, run `/reload <name>`" only (do not execute)
3. User runs CLI `exit` manually (do not auto-fire)
4. Report in 1-2 lines; do not pollute systemMessage / additionalContext

## When to use

- Mid-point save for long tasks
- Manual backup before compact (`/compact`)
- Hand-off to next session

## Fallback

| Scenario | Action |
|----------|--------|
| memory dir missing | create with `mkdir -p` |
| Write permission fail | output content to chat, guide manual save |
| name collision | auto-suffix `-2`, `-3` |

ARGUMENTS: $ARGUMENTS
