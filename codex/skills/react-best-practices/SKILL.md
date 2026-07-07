---
name: react-best-practices
description: Use when implementing or reviewing React or Next.js code — component structure, hooks correctness, rendering performance, state management, and accessibility. This is a thin Codex bridge to the Claude Code react-best-practices skill.
---

# React Best Practices

Use this skill for React and Next.js implementation and review.

This skill stays thin. It reuses the Claude Code canonical definition and shared guidelines.

## Load Order

1. Read the canonical skill body: `~/ai-tools/claude-code/skills/react-best-practices/SKILL.md`. It holds the full rule set across categories.
2. Read the shared guidelines you need from `~/.codex/guidelines/`:
   - language rules: `languages/` (TypeScript)
   - frontend and React patterns: `design/` or `common/` as relevant

## Operating Rules

- Keep hooks at the top level; respect the rules of hooks and complete dependency arrays.
- Split components by responsibility; lift state only as far as it must go.
- Memoize deliberately, not by default; measure before optimizing render cost.
- Type props and state strictly; forbid `any` and non-null assertions.
- Handle loading, empty, and error states for every async view.

## Output Check

Before finalizing, confirm:

- No hook is called conditionally or inside a loop.
- Effect dependencies are complete and stable.
- Async views render loading, empty, and error states.
