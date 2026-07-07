---
name: microservices-monorepo
description: Use when designing service boundaries, inter-service communication, or monorepo structure — decomposition, shared code, and dependency management across services. This is a thin Codex bridge to the Claude Code microservices-monorepo skill.
---

# Microservices & Monorepo

Use this skill for architecture decisions about service split and repository structure.

This skill stays thin. It reuses the Claude Code canonical definition and shared guidelines.

## Load Order

1. Read the canonical skill body: `~/ai-tools/claude-code/skills/microservices-monorepo/SKILL.md`.
2. Read the shared guidelines you need from `~/.codex/guidelines/`:
   - cross-cutting: `common/`
   - architecture: `design/`

## Operating Rules

- Split services along business capabilities and data ownership, not along technical layers.
- Keep each service's data private; communicate through explicit contracts, not shared tables.
- In a monorepo, make shared code an intentional package with a clear owner, not an accidental import.
- Prefer async messaging for cross-service workflows where coupling and latency allow.

## Output Check

Before finalizing, confirm:

- Each service owns its data and exposes a stable contract.
- Shared code is a versioned, owned package, not a leaked internal.
- Cross-service coupling is justified, not incidental.
