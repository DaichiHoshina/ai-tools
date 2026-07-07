---
name: grpc-protobuf
description: Use when designing Protobuf schemas or implementing gRPC services — message and service design, backward-compatible field evolution, code generation, and backend wiring. This is a thin Codex bridge to the Claude Code grpc-protobuf skill.
---

# gRPC / Protobuf

Use this skill for `.proto` design and gRPC service implementation.

This skill stays thin. It reuses the Claude Code canonical definition and shared guidelines.

## Load Order

1. Read the canonical skill body: `~/ai-tools/claude-code/skills/grpc-protobuf/SKILL.md`.
2. Read the shared guidelines you need from `~/.codex/guidelines/`:
   - language rules: `languages/` (Go and others)
   - backend patterns: `backend/`

## Operating Rules

- Never reuse or renumber field tags; reserve removed fields to keep wire compatibility.
- Design messages and services for evolution: additive changes only, no breaking edits.
- Regenerate code from the canonical `.proto`; do not hand-edit generated files.
- Handle deadlines, cancellation, and status codes explicitly on both client and server.

## Output Check

Before finalizing, confirm:

- No field tag is reused or renumbered; removed fields are reserved.
- Generated code matches the current `.proto` and is not hand-edited.
- RPCs propagate context, deadlines, and typed status codes.
