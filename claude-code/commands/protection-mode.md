---
allowed-tools: Read, Write
description: Load Protection Mode - apply operation checker and safety classification to session
---

## /protection-mode - Operation Protection Mode

## Execution Logic

1. **Check load flag**: `~/.claude/projects/{project}/memory/protection-mode-loaded.md` exists → skip
2. **First-time file load**: `skill.md` + `guardrails.md` (with `full` arg, also `session-modes.md`)
3. **Apply session mode**: Skill(session-mode) applies strict/normal/fast operation guards
4. **Save flag**: `Write` `~/.claude/projects/{project}/memory/protection-mode-loaded.md` ({loaded_at, summary}) — Serena `write_memory` forbidden (2026-06-10 decision); auto-memory only (warn if save fails, proceed to Step 5)
5. **Report application**: display current constraints (format below)

**Application report format**:

```
✓ Protection Mode loaded (mode=normal)
  Boundary: AskUser (important only)
  Forbidden: Deny (rm -rf /, secrets leak)
  Complexity gate: Simple < 5 files / 300 lines
```

## 3-layer Classification

| Layer | Action | Example |
|---|------|---|
| **Safe** | exec immediately | file read, git status |
| **Boundary** | confirm then exec | git commit/push, config change |
| **Forbidden** | reject | rm -rf /, secrets leak |

## Operation Guard

`operationGuard : Mode × Action → {Allow, AskUser, Deny}`

| Mode | Safe | Boundary | Forbidden |
|------|------|----------|-----------|
| strict | Allow | AskUser (all) | Deny |
| normal | Allow | AskUser (important) | Deny |
| fast | Allow | AskUser/Allow (critical only) | Deny |

## Complexity Judgment

| Condition | Judgment | Action |
|------|------|-----------|
| files<5 AND lines<300 | Simple | direct implementation |
| files≥5 OR independent features≥3 | TaskDecomposition | 5-phase workflow |
| cross-project | AgentHierarchy | PO/Manager/Developer |

**Priority**: AgentHierarchy > TaskDecomposition > Simple (take highest on tie). Boundaries exact as stated (`<5` = up to 4 is Simple, `≥5` = from 5 is TaskDecomposition).

5-phase workflow detail: `references/AI-THINKING-ESSENTIALS.md`

## Quality Guard

`GuardQuality : Implementation → {Accept, ReviewRequired, Reject}`

| Judgment | Example |
|------|-----|
| **Reject** | unmotivated null check, empty catch, unfounded timeout increase |
| **ReviewRequired** | documented workaround with root cause, provisional fix with TODO |
| **Accept** | init guarantee, boundary type validation, structural fix |

Quality guard is **detection** role. Fix strategy delegated to `/root-cause` skill.

ARGUMENTS: $ARGUMENTS
