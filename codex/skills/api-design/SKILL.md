---
name: api-design
description: Use when designing or reviewing REST or GraphQL APIs — versioning strategy, error models, resource naming, pagination, and documentation. This is a thin Codex bridge to the Claude Code api-design skill.
---

# API Design

Use this skill when the task is about the shape of an API that other services or clients consume.

This skill stays thin. It reuses the Claude Code canonical definition and shared guidelines.

## Load Order

1. Read the canonical skill body: `~/ai-tools/claude-code/skills/api-design/SKILL.md`.
2. Read the shared guidelines you need from `~/.codex/guidelines/`:
   - cross-cutting: `common/`
   - backend and API patterns: `backend/`

## Operating Rules

- Choose a versioning strategy explicitly (URI path, header, or media type) and state the migration path.
- Return a consistent error model: stable machine-readable code, human message, and correlation id.
- Name resources as nouns; keep verbs out of paths for REST.
- Design pagination, filtering, and sorting before shipping list endpoints.
- Document each endpoint with request, response, and failure cases.

## Output Check

Before finalizing, confirm:

- Breaking changes are versioned, not silently altered.
- Error responses share one schema across the API.
- Every endpoint documents its failure modes, not just the happy path.
