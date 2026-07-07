---
name: incident-response
description: Use when responding to a production incident — assess error and impact, identify the cause, create a tracking ticket, and write the incident doc. This is a thin Codex bridge to the Claude Code incident-response skill.
---

# Incident Response

Use this skill during and after a live incident to move from error to impact to cause to record.

This skill stays thin. It reuses the Claude Code canonical definition and shared guidelines.

## Load Order

1. Read the canonical skill body: `~/ai-tools/claude-code/skills/incident-response/SKILL.md`.
2. Read the shared guidelines you need from `~/.codex/guidelines/`:
   - operations and incident practice: `operations/`
   - writing the incident doc: `writing/` (choose the RCA or long-form guide)

## Operating Rules

- Sequence the work: error, impact, cause, ticket, doc.
- State user-facing impact first (who, how many, since when).
- Stabilize before you deep-dive; production rollback goes through a revert PR, not a force operation.
- Open a tracking ticket early so the timeline is captured as it happens.
- Do not treat a local reproduction as a confirmed root cause.

## Output Check

Before finalizing, confirm:

- Impact is quantified, not vague.
- The timeline records detection, mitigation, and resolution times.
- The doc names a concrete recurrence-prevention action with an owner.
