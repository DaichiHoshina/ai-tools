---
allowed-tools: Read, Glob, Grep, Bash, Task, AskUserQuestion, mcp__serena__*, Skill
description: Interactive design refinement (Superpowers integration)
---

## /brainstorm - Interactive design refinement

> **Goal**: launch Superpowers brainstorm skill, refine design interactively.

## Overview

Pre-implementation design phase. Refine interactively:

- **Requirement clarification**: concretize vague specs
- **Design options**: compare multiple approaches
- **Tech selection**: choose optimal stack
- **Risk identification**: pre-implement threat assessment

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
3. When design settled, proceed to:
   - `/plan` for impl plan
   - `/dev` for direct impl
   - `/flow` for full workflow

## Relation to protection-mode

- **Superpowers (macro)**: brainstorm → plan → implement workflow control
- **protection-mode (micro)**: safety control per operation (git, file edits)

Complementary; no conflict.

## Invocation

```
/brainstorm
```

Or direct Superpowers call:

```
/superpowers:brainstorm
```

## Adversarial validation (--debate)

`/brainstorm --debate` launches debate pattern:

1. **Proponent Agent**: argue merits + feasibility
2. **Skeptic Agent**: counter w/ risks, alternatives, blind spots
3. **Synthesis**: merge both, remove bias

```
Task("proponent", "argue merits & feasibility of this design: $ARGUMENTS")
Task("skeptic", "counter w/ risks, alternatives, oversights: $ARGUMENTS")
→ synthesize both for final judgment
```

## Fallback behavior

| Scenario | Behavior |
|----------|----------|
| Superpowers plugin not installed | suggest auto-delegate to `/plan`, warn |
| `--debate`: one agent fails | use remaining output, flag one-sided bias |
| both agents fail | downgrade to direct dialogue, no agents |

## Notes

- Superpowers plugin install required
- activate after Claude Code restart
- protection-mode guards still apply to all operations
