---
allowed-tools: Write, Read
description: Quick auto-memory save — record current work state to ~/.claude/projects/.../memory/
effort: low
---

# /memory-save - Quick auto-memory save

Claude Code auto-memory (`~/.claude/projects/<project-key>/memory/`) に作業状態を 1 command で保存する。

> **CLAUDE.md 規約準拠**: Serena `.serena/memories/` への write は禁止 (二重管理回避、2026-06-10 決定)。本 command は auto-memory のみ書く。

## Flow

1. **Auto-generate save content** (7 field: task / progress / files / next-action / project / 直前 3 発言 / skill)
2. **Auto-determine memory name**: arg 指定 or `work-context-YYYYMMDD-<topic>` 自動命名
3. **Save**: Write tool で `~/.claude/projects/-Users-daichi-hoshina-ai-tools/memory/<name>.md`
4. **MEMORY.md 更新**: 1 行 entry を末尾に追記 (`- [Title](file.md) — one-line hook`)
5. **Confirm**: saved path + summary を chat に出力

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

- 長 task の mid-point save
- compact 直前の手動 backup (`/compact` 起動前)
- hand-off to next session

## Fallback

| Scenario | Action |
|----------|--------|
| memory dir 不在 | `mkdir -p` で作成 |
| Write 権限 fail | content を chat 出力、user に手動 save 案内 |
| name 衝突 | auto-suffix `-2`, `-3` |

ARGUMENTS: $ARGUMENTS
