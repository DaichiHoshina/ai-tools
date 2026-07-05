---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, AskUserQuestion
description: Cursor IDE config audit — settings/rules/memories consistency, redundancy, drift
argument-hint: "[--dry|--apply|--scope <path>]"
---

# /cursor-review - Cursor Config Audit

Inspect `~/ai-tools/cursor/` and project `.cursor/` via **3 axes**. Auto-apply safe fixes only with `--apply` + user confirm.

Canonical checklist: `cursor/MAINTENANCE.md`

## Usage

```
/cursor-review                    # full scan, report only
/cursor-review --dry              # same as default
/cursor-review --apply            # apply safe fixes after confirm
/cursor-review --scope cursor/    # ai-tools cursor dir only
/cursor-review --scope .cursor/   # project memories/rules only
```

## Scope (default: both)

| Path | Content |
|------|---------|
| `~/ai-tools/cursor/User/` | settings.json, keybindings.json |
| `~/ai-tools/cursor/rules/` | global Agent rules (*.mdc) |
| `~/ai-tools/cursor/recommendations/` | extensions.json |
| `{project}/.cursor/memories/` | project-specific agent memos |
| `{project}/.cursor/rules/` | project-specific rules (if present) |

## Axes

| Axis | Target | Severity examples |
|------|--------|-------------------|
| consistency | rules ↔ memories ↔ CLAUDE.md / ai-tools-agent policy | Critical: commit-without-ask mismatch |
| redundancy | duplicate guidance across rules and memories | Warning: same rule in 2+ files |
| drift | stale paths, deprecated keys, sync diff | Warning: `sync.sh diff` non-empty; Info: old `更新:` date |

## Flow

| Step | Action |
|------|--------|
| 1. collect | Read scope files; run `cd ~/ai-tools/cursor && ./sync.sh diff` (skip note if missing) |
| 2. scan (parallel) | 3 axes: extract findings with file:line |
| 3. classify | Critical / Warning / Info; map each to fix type |
| 4. report | Summary table + per-finding recommendation |
| 5. apply (`--apply` only) | AskUserQuestion → edit files → `sync.sh diff` → suggest commit |

## Auto-fix policy

| Judgment | Auto-fix (`--apply`) | Manual |
|----------|---------------------|--------|
| stale path in memory | replace path | - |
| duplicate paragraph (same meaning) | merge into canonical file, delete duplicate | - |
| deprecated VS Code key | remove or replace (Context7/WebSearch if unsure) | ask |
| policy contradiction | - | user decides canonical source |
| sync diff (local ahead) | - | `./sync.sh from-local` or discard local |
| new rule content | - | user drafts |

**Never auto-fix**: secrets, machine-specific values, policy contradictions without user pick.

## Output format

```markdown
# Cursor Review — YYYY-MM-DD
## Scope: cursor/ + .cursor/
## Sync diff: (none | N lines in settings.json)
## Critical (N)
## Warning (N)
## Info (N)
## Suggested next steps
```

## Safety

- `--apply` requires AskUserQuestion before any Write/Edit
- public-repo: no personal names / tokens in report (`rules/public-repo-private-data-block.md`)
- symlink mode: edit repo files under `~/ai-tools/cursor/` (not `~/Library/...` directly)
- after apply: remind `./sync.sh diff` and commit only on user request

## Related

- `cursor/MAINTENANCE.md` — monthly manual checklist
- `/retrospective` — session-based Cursor friction analysis
- `cursor/sync.sh` — to-local / from-local / diff
