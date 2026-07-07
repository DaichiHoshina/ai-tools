---
name: code-comment
description: Use when adding, editing, or reviewing code comments (//, #, --, /* */, <!-- -->) — enforce WHY-only comments, remove the nine noise categories, avoid anthropomorphism, and drop AI markers. This is a thin Codex bridge to the Claude Code code-comment skill.
---

# Code Comment

Use this skill whenever the change involves comments inside code.

This skill stays thin. It reuses the Claude Code canonical definition and shared guidelines.

## Load Order

1. Read the canonical skill body: `~/ai-tools/claude-code/skills/code-comment/SKILL.md`.
2. Read the canonical guideline: `~/.codex/guidelines/writing/code-comment.md`.

## Operating Rules

- Comment the WHY, not the WHAT. Well-named identifiers already explain what the code does.
- Keep only comments that record a hidden constraint, workaround, or subtle invariant.
- Remove noise: restating code, commented-out code, changelog notes, task or PR references, and decorative banners.
- Do not anthropomorphize the code and do not add AI-generated markers.

## Output Check

Before finalizing, confirm:

- Every remaining comment explains a reason a reader could not infer from the code.
- No comment narrates the current task, PR, or process.
- No AI footer or decorative wording remains.
