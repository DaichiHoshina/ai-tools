---
allowed-tools: Read, Glob, Grep, Bash, Task, AskUserQuestion, mcp__serena__*, Skill
description: Interactive design refinement (Superpowers integration)
argument-hint: "[topic]"
---

## /brainstorm - Interactive design refinement

> **Goal**: launch Superpowers brainstorm skill, refine design interactively.

## When to use

| Command | Use |
|---------|-----|
| `/brainstorm` | design unclear, multiple options exist |
| `/plan` | design settled, create impl plan |
| `/dev` | design+plan done, implement now |

> Full flow (brainstorm → prd → design-doc → plan → dev → docs): `references/design-phase-flow.md`

## Flow

1. `/brainstorm` → launch Superpowers brainstorm skill
2. Interactive refine (requirements, tech, risks)
3. When design settled, proceed to `/plan` / `/dev` / `/flow`

## Relation to protection-mode

- **Superpowers (macro)**: workflow control (brainstorm → plan → implement)
- **protection-mode (micro)**: per-operation safety (git, file edits)

Complementary; no conflict.

## Invocation

```
/brainstorm
/superpowers:brainstorm
```

## Adversarial validation (--debate)

`/brainstorm --debate` launches debate pattern:

1. **Proponent Agent**: argue merits + feasibility
2. **Skeptic Agent**: counter w/ risks, alternatives, blind spots
3. **Synthesis**: merge both, remove bias

### Gate 1: subagent_type required

Always specify `subagent_type: explore-agent` on Task fire.
`general-purpose` / unspecified is forbidden (see CLAUDE.md Discovery Routing).
Do not create new agent types (e.g. debate-agent); reuse `explore-agent`.

```
Task("proponent", subagent_type="explore-agent",
     prompt="argue merits & feasibility of this design: $ARGUMENTS")
Task("skeptic",   subagent_type="explore-agent",
     prompt="counter w/ risks, alternatives, oversights: $ARGUMENTS")
→ synthesize both for final judgment
```

### Gate 2: trailer read

After each agent completes, read trailer from output end.
Trailer literal: `references/agent-output-schema.md` (no duplicate definition here).
Fields: `status` / `confidence` / `issues_blocking`.

### Gate 3: fallback

| Scenario | Behavior |
|----------|----------|
| trailer missing | treat as `status: failure` |
| one agent fails | continue w/ remaining output; flag one-sided bias before synthesis |
| both fail | stop + escalate to user |

### Constraints

- `subagent_type: explore-agent` literal required
- status enum: `references/agent-output-schema.md` canonical (no duplicate here)
- No new agent types

## Fallback behavior

| Scenario | Behavior |
|----------|----------|
| Superpowers plugin not installed | suggest auto-delegate to `/plan`, warn |
| `--debate`: one agent fails | use remaining output, flag one-sided bias |
| both agents fail | stop + escalate to user (see Gate 3) |

## Notes

- Superpowers plugin install required; activate after Claude Code restart
- protection-mode guards apply to all operations
