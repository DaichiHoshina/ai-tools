---
allowed-tools: Read
name: session-mode
description: "Switch modes (strict/normal/fast): guard strength for prod/dev/proto. mode 切替時に使用。"
---

# session-mode - Session Mode Switching

Switch Claude Code behavior mode per-session. Operation guard behavior, loaded specs, confirm flow vary by mode.

## Mode Definitions

### strict Mode

| Item | Content |
|------|------|
| Load | `session-modes.md` + `guardrails.md` |
| git commit/push | Always confirm |
| Config change | Always confirm |
| npm install | Always confirm |
| Use case | Prod work, critical refactoring |

### normal Mode (Default)

| Item | Content |
|------|------|
| Load | CLAUDE.md (8 principles) only |
| git commit/push | Confirm |
| Config change | Confirm |
| npm install (safe) | Auto-approve |
| Use case | Normal dev work |

### fast Mode

| Item | Content |
|------|------|
| Load | Minimal |
| git commit | Auto-approve (local only) |
| git push | Feature branch auto-approve, main/master confirm |
| npm install (safe) | Auto-approve |
| File edit | Auto-approve (delete only confirm) |
| Use case | Prototyping, exploratory dev, daily exploratory use |

**SafeBoundary (auto-approved in fast)**:
git commit (local), git push (feature branch), npm install (safe), format(code), file_edit (existing)

**Reduce confirms in fast mode**:
- `/flow` run: Skip post-type-detect confirm
- `/dev` run: Skip Plan confirm
- AskUserQuestion: Single option = auto-select
- Mid confirms: Skip all (except /prd Phase 1)
- Error fix: Obvious errors = instant fix, no confirm

## Failure Behavior

| Situation | Action |
|------|------|
| Mode switch not in enum (e.g. `extreme`) | Fallback to normal, warn |
| `session-modes.md` load fail (strict) | Downgrade to normal, warning log. Guide user to reinstall strict config |
| Old hook config after switch | Guide to reload hooks (Claude Code restart) |

## Output Format (Mode Switch)

```
🔄 Mode switch: {old_mode} → {new_mode}
- Load: {file list}
- Auto-approve: {SafeBoundary list (if fast)}
- Use case: {description}

⚠️ {fast only} Recommend `/session-mode strict` for prod
```

## Related

- `/protection-mode` - Load categorical thinking method
