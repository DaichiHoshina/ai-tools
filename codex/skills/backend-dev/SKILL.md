---
name: backend-dev
description: Use when implementing or reviewing backend code in Go, TypeScript, Python, or Rust — error handling, security, testing, performance, and language-specific conventions. This is a thin Codex bridge to the Claude Code backend-dev skill.
---

# Backend Dev

Use this skill for backend implementation and review across Go, TypeScript, Python, and Rust. Auto-detect the language from file extensions or manifest files (`go.mod`, `package.json`, `pyproject.toml`, `Cargo.toml`).

This skill stays thin. It keeps `~/.codex/skills` Codex-native while reusing the Claude Code canonical definition and shared guidelines.

## Load Order

1. Read the canonical skill body: `~/ai-tools/claude-code/skills/backend-dev/SKILL.md`. It holds the full per-language rule tables and checklist.
2. Read the shared guidelines you need from `~/.codex/guidelines/`:
   - cross-cutting: `common/`
   - architecture: `design/` (clean architecture, DDD)
   - language rules: `languages/` (Go, TypeScript, Python, Rust)
   - backend patterns: `backend/`

## Operating Rules

- Detect the primary language first. If multiple languages change, apply the primary one fully and flag only Critical issues in the others.
- Never ignore errors. Use type-safe error handling per language (Go `if err != nil`, TS Result pattern, Rust `Result<T, E>`, Python specific exceptions).
- Use parameterized queries. Keep secrets out of logs.
- Write unit tests for both happy and sad paths.
- Avoid N+1 queries and unnecessary allocations.

## Output Check

Before finalizing, confirm:

- All errors are handled with the language's idiomatic mechanism.
- No SQL injection surface and no secrets in logs.
- Tests cover success and failure paths.
- Concurrency is safe (no goroutine or resource leaks).
