---
allowed-tools: Read, Glob, Grep, Bash, Skill, Agent, AskUserQuestion, mcp__serena__*
description: Full code review (`comprehensive-review` skill + optional external reviewers)
argument-hint: "[scope]"
---

# /review - Full Code Review

> Runs 12-angle review via `comprehensive-review` skill. `--deep`/`--multi` parallelizes external reviewers.
> Noise filter policy: `rules/review-noise-discard.md` / Finding constraints: `skills/comprehensive-review/SKILL.md` Step -1

## Delegation & Self-Review (required, 2 stages)

**Delegation**: Delegate `comprehensive-review` skill to `reviewer-agent` (Sonnet) via Task. Delegation prompt: `"Run comprehensive-review skill on current diff. focus=${focus}. Return raw findings list with confidence scores."` Parent Opus runs Stage A (per-finding); Stage B aggregate delegates back to reviewer-agent.

**Always** run the following 2-stage self-review before outputting `/review` results. Applied uniformly to all modes (`--dry-run` / `--codex` / `--multi` / `--deep` / `--adversarial`) — cannot skip.

### Stage A: Finding Self-Review Gate (per-finding)

Skill Step 4.5 has already done primary eval on 7 angles: Evidence / Scope / Overreach / Actionability / Severity / Style / Overprescription. **Parent Opus must run safety-net re-eval on the same 7 angles**. Prioritize propagation incompleteness / cross-ref desync. Do not include judgment log in output.

Adversarial mode: relax Evidence/Scope criteria (design-challenge nature); Stage B dedup proceeds as normal.

### Stage B: Result Self-Review Pass (overall) — delegate to reviewer-agent

Pass Stage A findings as JSON list to `reviewer-agent --stage-b`. Fresh context aggregate suppresses post-impl bias.

- Delegate to: `Task(subagent_type: "reviewer-agent")`
- Prompt template: `"Stage B aggregate review. Input: Stage A filtered findings (JSON list, below). Apply: (1) phase consolidation (same root cause → 1 finding), (2) detail-level alignment, (3) convention alignment, (4) Zero-phase valid (no padding). Return: confirmed findings as JSON {p0: [...], p1: [...], p2: [...]}. Do NOT add new findings — filter only. Noise discard policy: rules/review-noise-discard.md (confidence <80 / style nitpick / hypothetical edge case / scope-out suggestions are discard targets)."`
- Parent responsibility: Stage A (per-finding) only. Pass Stage B output directly to `/review-fix-push` Step 3
- Do not include judgment log in plan file / chat. Display Stage B results only

## Step 0: Auto-infer Mode (no flags)

No flags on launch → present recommended mode, execute after user confirm (heavy modes must not auto-run without consent).

| Situation | Recommend |
|-----------|-----------|
| 1-15 files | default (auto-run) |
| 16+ OR diff has `interface`/`type`/`class` | `--deep` (ask confirm) |
| PR arg present + base is main/master | `--multi` (ask confirm) |
| arg has "design"/"architecture"/"tradeoff" | `--adversarial` (ask confirm) |

material: `git diff --shortstat` / `gh pr diff <PR>` / `gh pr view <PR> --json baseRefName` / `$ARGUMENTS` grep.

## Arguments & Modes

| Argument | Behavior |
|----------|----------|
| none | review local diff |
| URL/number | `gh pr diff` / `glab mr diff` |
| `--focus=<angle>` | narrow 12 angles (see skill.md) |
| `--no-difit` | suppress difit (local only) |

| Mode | Delegate | PR | Cost |
|--------|--------|----|--------|
| (default) | `comprehensive-review` skill | any | mid |
| `--panel` | 3-lens parallel fan-out (style/security/test-coverage) → integrated by `comprehensive-review` | any | mid×3 |
| `--codex` | `comprehensive-review` + codex plugin parallel, common findings = Critical | any | mid |
| `--adversarial` | codex plugin `adversarial-review` (plugin required) | any | mid |
| `--deep` | pr-review-toolkit 6 agents parallel (5-10min) | any | large |
| `--multi` | `comprehensive-review` + codex + code-review + coderabbit parallel → auto-post to PR | required | max |

cloud large: see `/ultrareview`.

### CI Integration

Non-interactive: `claude ultrareview <PR_or_path> --json` for machine-readable output, gated via exit code.

## Codex Invocation (--codex / --adversarial)

Via plugin: `node "${CODEX_PLUGIN_ROOT}/scripts/codex-companion.mjs" <review|adversarial-review> --wait`. `${CODEX_PLUGIN_ROOT}` = `ls -1d ~/.claude/plugins/cache/openai-codex/codex/* | tail -1`. Fallback if missing: `--codex` uses `codex review` direct; adversarial is plugin-only.

## Adversarial Flow

Challenges design correctness / assumptions / real-world failure points. `--base <ref>` / `--scope auto|working-tree|branch` / `--background` → `/codex:status`/`/codex:result <id>`. Use: design review / pre-PR self-challenge. Implementation defects → `/review` default.

## Deep Flow

Run `pr-review-toolkit` 6 agents in parallel. **Cost warning**: tens of seconds ~ minutes × 6 parallel. Daily = default.

## Multi Flow

PR required. 4 methods parallel: (a) `comprehensive-review` skill / (b) codex plugin / (c) `/code-review:code-review` / (d) `coderabbit:code-review` → merge + deduplicate → auto-post `gh pr comment`. Aggregation: 3+ agree = Critical confirmed. Use: pre-merge / security patch. Not recommended daily.

## Output Format

Same format as skill.md. Labels: `🔴 Critical (fix required, confidence ≥80)` / `🟡 Warning (improve, confidence 25-79)` / `Total: Critical N / Warning N`. Fallback: zero findings → `Critical/Warning 0, Total no findings (N files)` / Multi/Deep partial fail → `### Degrade factors`.

## Critical/Warning ↔ P0/P1

`/review` solo = `Critical→P0` / `Warning→P1` / else `P2/P3`. Team path = report only. Details: [`reviewer-agent.md`](../agents/reviewer-agent.md).

## Review Policy & Scope

- **policy**: evidence-first (false positives are review debt), diff-only, Critical → Warning, 12 parallel
- **scope**: changed files (git diff). exclude: auto-gen / vendor / node_modules / lock
- **difit**: local only, background after review (require `npm i -g difit`, suppress: `--no-difit`)

## Multi-lens panel (--panel)

Fan-out `reviewer-agent` × 3 in parallel; each lens is blind to others. Source: [claudefa.st — Multi-Lens Panel Review](https://claudefa.st/blog/guide/agents/sub-agent-best-practices)

### Lens config

| lens | focus | ignores |
|---|---|---|
| style | naming / readability / convention / cognitive complexity | logic / security |
| security | authn/authz / injection / secrets / data boundary / unsafe logging | style / coverage |
| test-coverage | test adequacy / missing edge cases / silent-failure paths | style / security |

- Pass diff + assigned focus only to each lens (no other lens output)
- Fire 3 lens in **1 message bundle** (`Task(reviewer-agent)` × 3, peak_concurrency=3)

Components: `--panel` lens ×3 (blind diversity) → integrated by `comp-review` skill (`skills/comprehensive-review/SKILL.md` §Multi-lens) → Stage A self-review.

Aggregation by file:line key: 2/3+ hit → max severity → Stage A / 1/3 only → P3 / all miss → clean.

**Default: panel off** (`--panel` opt-in). Limit to large PR pre-merge final check.

## Verifier panel (--verifier-panel)

`/review --verifier-panel=N` (N=3 recommended, default OFF): fan-out reviewer-agent × N. Same engine, each agent handles a different lens in fresh context; only majority-confirmed findings are promoted. Implements perspective-diverse verify from Claude Code official best practices. Orthogonal to `--multi` (engine-diverse: comp-review / codex / coderabbit / code-review parallel).

### Lens spec (N=3 default)

| lens | focus | ignores |
|---|---|---|
| correctness | logic validity / spec conformance / unexpected input behavior / race conditions | style / typo / naming |
| consistency | existing convention / cross-file naming / propagation completeness / import order | logic / new findings |
| boundary | input validation / edge case / error path / secrets handling / data boundary | general logic / style |

Delegation prompt template per lens: `agents/reviewer-agent.md` `## Lens-specific mode`.

Aggregation by file:line key: 2/N+ hit → P0/P1 (max severity) / 1/N → P3 silent / all miss → true clean.

**Token cost**: N× tokens. Keep default OFF; limit to large PR pre-merge final check. `--multi --verifier-panel=3` = 12× cost — pick one.

**Fan-out**: fire `Task(reviewer-agent)` ×N in 1 message bundle (peak_concurrency=N; sequential fire forbidden). CLAUDE.md `1 dev = 1 file` / parent oversight applies.
