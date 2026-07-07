---
name: root-cause
description: Use when investigating a bug, incident, or recurring failure to find the structural root cause rather than a symptomatic patch — reproduce, identify, design the fix, and verify with recurrence prevention. This is a thin Codex bridge to the Claude Code root-cause skill.
---

# Root Cause

Use this skill when a problem needs a structural fix, not a symptom patch.

This skill stays thin. It reuses the Claude Code canonical definition and shared guidelines.

## Load Order

1. Read the canonical skill body: `~/ai-tools/claude-code/skills/root-cause/SKILL.md`.
2. Read the shared guidelines you need from `~/.codex/guidelines/`:
   - cross-cutting: `common/`
   - operations and incident practice: `operations/`

## Operating Rules

- Follow four steps: reproduce, identify, design, verify.
- Ask "why" until the cause is structural, not a surface trigger. A local reproduction is not the same as a confirmed root cause.
- Prefer a structural fix that prevents the whole class of failure over a one-off patch.
- Add a recurrence-prevention step (test, guard, alert, or doc) as part of the fix.

## Output Check

Before finalizing, confirm:

- The failure is reproduced, not just described.
- The stated cause explains every observed symptom.
- The fix removes the class of bug and includes a prevention measure.
