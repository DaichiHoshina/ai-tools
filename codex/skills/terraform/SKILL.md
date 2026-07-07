---
name: terraform
description: Use when writing or reviewing Terraform IaC — module design, state management, provider and variable hygiene, and security best practices for plan and apply. This is a thin Codex bridge to the Claude Code terraform skill.
---

# Terraform

Use this skill for Terraform module design and plan/apply review.

This skill stays thin. It reuses the Claude Code canonical definition and shared guidelines.

## Load Order

1. Read the canonical skill body: `~/ai-tools/claude-code/skills/terraform/SKILL.md`. It covers state locking recovery and IaC patterns.
2. Read the shared guidelines you need from `~/.codex/guidelines/`:
   - infrastructure: `infrastructure/`
   - operations: `operations/`

## Operating Rules

- Design reusable modules with explicit inputs and outputs; avoid hardcoded values.
- Keep state remote and locked; never commit state or secrets.
- Pin provider and module versions.
- Review `plan` before `apply`; treat destructive changes as requiring explicit confirmation.
- If a lock remains after a crashed run, diagnose before force-unlocking.

## Output Check

Before finalizing, confirm:

- No secrets or state files are committed.
- Provider and module versions are pinned.
- The plan output has no unexpected destroy or replace actions.
