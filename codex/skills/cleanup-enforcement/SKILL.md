---
name: cleanup-enforcement
description: Use when removing backward-compat remnants, dead code, unused exports, or feature-flag leftovers after a change lands — enforce full cleanup instead of leaving transitional cruft. This is a thin Codex bridge to the Claude Code cleanup-enforcement skill.
---

# Cleanup Enforcement

Use this skill when a migration or refactor is done and transitional code must be removed.

This skill stays thin. It reuses the Claude Code canonical definition and shared guidelines.

## Load Order

1. Read the canonical skill body: `~/ai-tools/claude-code/skills/cleanup-enforcement/SKILL.md`.
2. Read the shared guidelines you need from `~/.codex/guidelines/`:
   - cross-cutting: `common/`

## Operating Rules

- Remove compatibility shims once every caller has moved to the new path.
- Delete dead code, unused exports, and stale flags rather than commenting them out.
- Verify with a reference search that a symbol is truly unused before deleting it.
- Do not leave a change half-migrated: finish the cutover or do not start it.

## Output Check

Before finalizing, confirm:

- No compatibility shim survives past its last caller.
- No commented-out or dead code is left behind.
- Every deletion is backed by a reference search showing zero remaining uses.
