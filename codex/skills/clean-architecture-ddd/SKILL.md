---
name: clean-architecture-ddd
description: Use when making design decisions about layer separation, domain modeling, and dependency direction — Clean Architecture boundaries and DDD tactical patterns. This is a thin Codex bridge to the Claude Code clean-architecture-ddd skill.
---

# Clean Architecture & DDD

Use this skill when the task is about structure and dependencies rather than a single function.

This skill stays thin. It reuses the Claude Code canonical definition and shared guidelines.

## Load Order

1. Read the canonical skill body: `~/ai-tools/claude-code/skills/clean-architecture-ddd/SKILL.md`.
2. Read the shared guidelines you need from `~/.codex/guidelines/`:
   - cross-cutting: `common/`
   - architecture: `design/`

## Operating Rules

- Point dependencies inward: domain depends on nothing; infrastructure depends on domain via interfaces.
- Keep business rules in the domain layer, free of framework and I/O concerns.
- Model the domain with entities, value objects, and aggregates that enforce their own invariants.
- Cross layer boundaries through explicit ports, not by leaking framework types.

## Output Check

Before finalizing, confirm:

- No inward layer imports an outer layer.
- Domain invariants live in the domain, not in controllers or repositories.
- Boundaries are crossed through interfaces, not concrete framework types.
