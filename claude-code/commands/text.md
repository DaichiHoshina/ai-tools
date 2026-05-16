---
allowed-tools: Read, Glob, Grep, Bash, Edit, Write, mcp__serena__*
description: Human-facing prose quality mode (readability/visibility/clarity focus)
---

## /text - Writing Quality Command

Improve human-facing prose (PR body, Design Doc body, Notion, blog, Slack, email) **readability, visibility, clarity**.

Code body, code comments, docstrings out of scope.

> **Responsibility split**:
> - `/docs` = format/structure/template compliance (Notion post/API docs/README)
> - `/design-doc` = assemble design decision document
> - `/text` = **prose quality itself** (vocab, sentence length, paragraph, signal)

## Subcommand

| sub | purpose | input | output |
|-----|---------|-------|--------|
| `write` (default) | write from scratch | goal/reader/topic | draft |
| `rewrite` | rewrite existing | file or paste | revision + reason (3 line max per change) |
| `review` | proofread (no edit) | file or paste | 5-axis check + finding list |
| `outline` | structure only | goal/reader/topic | heading hierarchy + intent per section |

no arg or `write` → write mode.
**ARGUMENTS parse**: first token vs subcommand match, no match → treat whole arg as write topic.

## Pre-execution (required order)

### 1. Temp Turn OFF genshijin (by output type)

| Output Type | Prose |
|---------|----------|
| write/rewrite body/draft | normal Japanese |
| outline heading/intent | normal Japanese |
| review finding/score | genshijin |
| progress/confirm/error | genshijin |

### 2. 4-Question Checkpoint (pre-write, mandatory)

```
1. Who reads? (reader background/interest)
2. What decide/understand? (target judgment)
3. How act after? (intended behavior)
4. Evidence for claim? (number/case/compare)
```

If any unconfirmed, ask **top 1 only** (priority: reader > judgment > action > evidence).
Post-answer, if still unconfirmed, continue with design-memo default:

- reader = same-role engineer / judgment = boost understanding / action = reader optional / evidence = optional

**Mark in design memo: `estimated: {Q}={value}`**.

### 3. Load Resources (heading anchor extract)

Main: `guidelines/writing/PRINCIPLES.md` (~180 line) full load OK. Detailed pattern: need? load `references/writing-patterns.md` heading anchor only.

PRINCIPLES.md main sections:

- `## Top Priority — Lower Reader Cognition Load` / `## Pre-write 4 Questions` / `## Keep (7 principles)` / `## Avoid Patterns`
- `## Kill AI Smell 3 Transform` + nested `### NG Dictionary (delete targets)`
- `## Avoid Patterns` / `## Pre-output Self-Check (6 items, 5+ pass)`

### 4. Dynamic Load by Type

| Detect Keyword | Extra Load |
|---------|-----------|
| Notion / page | `guidelines/common/notion-writing.md` |
| Design Doc / ADR / RCA | `guidelines/writing/design-doc-protocol.md` |
| PR / pull request | `guidelines/writing/pr-description.md` |
| rewrite | `references/document-iteration-patterns.md` + `references/writing-patterns.md` "Rewrite Phase 1-8" |

## 5-Axis Check (review/rewrite required)

```
[A] readability: 1 sentence ≤60 chars / paragraph 3-5 sentences / explicit subject
[B] visibility: heading hierarchy / bullet use / tables for types
[C] signal: PREP or TL;DR+detail / conclusion first
[D] evidence: praise word + number/case (AI smell 3-transform)
[E] coherence: term consistency / no duplication / NG dict hit 0
```

Each 0-3 pts, total 11/15+ pass (= avg 2.2, all ≥2 + 1 full assumed practical threshold). Below: cite specific point.

> **5-axis vs 6-item pre-output**:
> - 5-axis = **evaluate** output quality (review/rewrite output score)
> - 6-item pre-output = **gate** just-before-output (PRINCIPLES.md derived, 5+ pass)
> Both pass = done.

## Output Format

### write / rewrite

```
## Draft
(body)

## Design Memo (≤3 line)
- reader: ...
- argument order: ...
- dropped topic: ...
```

### review

```
## 5-Axis Score
A:_/3 B:_/3 C:_/3 D:_/3 E:_/3  total _/15

## Findings (priority order, max 5)
1. [axis] location → fix direction
...
```

### outline

```
## Structure
1. (heading) — intent 1 line
   - subheading — contain what
...
```

## Forbidden

- generate AI-smell prose ("important" "effectively" "seamlessly" etc unsupported)
- verbose boilerplate ("below shows" "you can" etc)
- execute write without 4-question pass
- full load writing-patterns (token waste, PRINCIPLES focus enough)
- apply to code body/comment/docstring (out of scope)
- **run Edit/Write in `review` submode** (output = findings only, no file change)

## Completion (per sub)

| Condition | write | rewrite | review | outline |
|-----------|:---:|:---:|:---:|:---:|
| 4-question pass | ✓ | ✓ | – | ✓ |
| 5-axis score 11/15+ | ✓ | ✓ | ✓ | – |
| 6-item pre-output 5+ | ✓ | ✓ | – | – |
| NG dict hit 0 | ✓ | ✓ | – | – |

ARGUMENTS: $ARGUMENTS
