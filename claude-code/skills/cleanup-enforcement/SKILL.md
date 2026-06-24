---
name: cleanup-enforcement
description: Cleanup enforcement: remove compat remnants, unused code. Use for cleanup.
requires-guidelines:
  - common
  - typescript  # if lang=typescript
  - golang  # if lang=go
---

# cleanup-enforcement - Code Cleanup Enforcement

## Purpose

Force "delete" instructions that CLAUDE.md/commands don't enforce.

## Forced Deletion Rules

### 1. Delete Unused Code Immediately

- Unused imports
- Unused vars/constants
- Unused functions/methods
- Unused type defs/interfaces

**Criterion**: Anything IDE/linter warns about → delete

### 2. Forbid Backward Compat Remnants

Absolutely forbidden: Unused old name re-export (`export { newName as oldName }`) / `_` prefix unused mark / backward compat only re-export. Delete on sight, fix usage if any.

### 3. Forbid Progress Comments

Forbidden: `// implemented` `// done` `// TODO: remove later` `// FIXME: temporary` `// 2024-01-15: added this`
Allowed: Reason explanations (`// Workaround for Chrome bug #12345`, `// Required by external API spec`)

### 4. YAGNI Violation Detection & Delete

Below = **over-engineering**, delete:

| Pattern | Criterion | Action |
|---------|---------|-----------|
| Helper called once | Caller at 1 location only | Inline |
| Unused abstraction | interface/abstract class has 1 impl | Delete |
| Over-configuration | Unused option currently | Delete |
| Future prep | Comment has "future", "plan", "future" | Delete |

### 5. Deletion Targets

| Target | Action |
|------|-----------|
| Empty file | Delete |
| Empty function/class | Delete (except stubs) |
| Commented code | Delete |
| console.log / print debug | Delete |
| Unreachable code | Delete |

## Output Format

```
## Cleanup Report

### Deleted
- ✅ Unused import 3 deleted
- ✅ Unused var `oldConfig` deleted
- ✅ Progress comments 2 deleted

### Needs Confirm
- ⚠️ `legacyHandler` may be referenced externally

### Stats
- Lines deleted: -45
- Files deleted: 0
```

## Deletion Flow (Serena Required)

Code file deletion **must use Serena symbolic tools** (grep misses refs).

| Step | Tool | Use |
|---------|-------|------|
| 1. Find candidates | `mcp__serena__get_symbols_overview` / `find_symbol` | Identify deletion targets |
| 2. Confirm refs | `mcp__serena__find_referencing_symbols` | List all refs (grep can miss) |
| 3. Track impls | `mcp__serena__find_implementations` | Check impl when deleting interface |
| 4. Safe delete | `mcp__serena__safe_delete_symbol` | Delete with ref check (auto fail-safe) |
| 5. Check diagnostics | `mcp__serena__get_diagnostics_for_file` | Detect post-delete type errors |

Progress comment deletion in non-code (md/yaml/json) → normal Edit OK.

## Notes

- **When in doubt, delete**: Can restore from git history if needed
- **Run tests**: Always test after delete

## Failure Behavior

| Situation | Action |
|------|------|
| `mcp__serena__find_referencing_symbols` fail | Grep retry, warn precision drop. If undecidable, hold in "Needs Confirm" |
| Zero deletion candidates | Rewrite "Deleted" section to "No deletion candidates", show stats as 0 |
| Post-delete test fail | Git stash the deletion, report failure to user & stop |
