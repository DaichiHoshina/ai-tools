---
allowed-tools: Read
name: session-mode
description: "Switch modes (strict/normal/fast): guard strength for prod/dev/proto. mode 切替時に使用。"
---

# session-mode - Session Mode Switching

Switch Claude Code behavior mode per-session. Operation guard behavior, loaded specs, confirm flow vary by mode.

## Mode Definitions

mode 定義 canonical: `guidelines/common/session-modes.md` 参照。

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
