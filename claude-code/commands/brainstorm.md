---
allowed-tools: Read, Glob, Grep, Bash, Task, AskUserQuestion, mcp__serena__*, Skill
description: Interactive design refinement (Superpowers integration)
argument-hint: "[topic]"
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

### Gate 1: subagent_type 指定必須

Task fire 時は必ず `subagent_type: explore-agent` を明示する。
`general-purpose` / 未指定は禁止 (CLAUDE.md Discovery Routing 参照)。
debate-agent など新 agent type の新設も禁止。既存 `explore-agent` を流用する。

```
Task("proponent", subagent_type="explore-agent",
     prompt="argue merits & feasibility of this design: $ARGUMENTS")
Task("skeptic",   subagent_type="explore-agent",
     prompt="counter w/ risks, alternatives, oversights: $ARGUMENTS")
→ synthesize both for final judgment
```

### Gate 2: verdict 受取

各 agent 完了後、出力末尾の trailer を読んで判定する。
trailer literal は `references/agent-output-schema.md` を参照 (二重管理禁止)。
読取対象フィールド: `status` / `confidence` / `issues_blocking`。

### Gate 3: fallback

| Scenario | Behavior |
|----------|----------|
| trailer 欠落 | `status: failure` と同等に扱う |
| 片方 failure | 残り 1 件の出力で続行。一方向偏りを明示してから統合 |
| 両方 failure | 処理を停止し、user にエスカレートする |

### Constraints

- `subagent_type: explore-agent` の literal 明示が必須
- status enum は `references/agent-output-schema.md` canonical、本文に重複定義しない
- debate-agent など新 agent type の新設禁止

## Fallback behavior

| Scenario | Behavior |
|----------|----------|
| Superpowers plugin not installed | suggest auto-delegate to `/plan`, warn |
| `--debate`: one agent fails | use remaining output, flag one-sided bias |
| both agents fail | stop + escalate to user (see Gate 3) |

## Notes

- Superpowers plugin install required
- activate after Claude Code restart
- protection-mode guards still apply to all operations
