---
allowed-tools: Read, Glob, Grep, Bash, Skill, Agent, AskUserQuestion, mcp__serena__*
description: Comprehensive code review (comprehensive-review skill + optional external reviewers)
---

# /review - Comprehensive Code Review

> Runs 12-angle review via `comprehensive-review` skill. `--deep`/`--multi` parallelizes external reviewers.
> Noise filter policy: `rules/review-noise-discard.md` / Finding constraints: `skills/comprehensive-review/skill.md` Step -1

## Delegation & Self-Review (required, 2 stages)

**Delegation**: Delegate `comprehensive-review` skill to `reviewer-agent` (Sonnet) via Task. Delegation prompt: `"Run comprehensive-review skill on current diff. focus=${focus}. Return raw findings list with confidence scores."` Parent Opus handles Stage B filter only.

**Always** run the following 2-stage self-review before outputting `/review` results. Applied uniformly to all modes (`--dry-run` / `--codex` / `--multi` / `--deep` / `--adversarial`) — cannot skip.

### Stage A: Finding Self-Review Gate (per-finding)

Skill Step 4.5 has already done primary eval on 7 angles: Evidence / Scope / Overreach / Actionability / Severity / Style / Overprescription. **Parent Opus must run safety-net re-eval on the same 7 angles**. Prioritize propagation incompleteness / cross-ref desync. Do not include judgment log in output.

Adversarial mode: relax Evidence/Scope criteria (design-challenge nature); Stage B dedup proceeds as normal.

### Stage B: Result Self-Review Pass (overall)

1. **Dedup**: multiple lenses producing separate findings from same root cause → consolidate to 1
2. **Tone consistency**: many Criticals → watch for false alarms, re-evaluate
3. **Project convention**: check against CLAUDE.md / guidelines; discard preference-based findings outside conventions
4. **Zero-finding**: 0 is valid — no padding

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
| `--codex` | comprehensive + codex plugin parallel, common findings = Critical | any | mid |
| `--adversarial` | codex plugin `adversarial-review` (plugin required) | any | mid |
| `--deep` | pr-review-toolkit 6 agents parallel (5-10min) | any | large |
| `--multi` | comprehensive + codex + code-review + coderabbit parallel → auto-post to PR | required | max |

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

PR required. Run 4 methods in parallel:

1. Fetch PR diff to `/tmp/review-multi-<PR>.diff`
2. Parallel: (a) `comprehensive-review` skill / (b) codex plugin / (c) `/code-review:code-review` / (d) `coderabbit:code-review`
3. Merge 4 outputs, deduplicate
4. Auto-post via `gh pr comment <PR> --body-file -`

Aggregation (3+ agree = Critical confirmed etc.). Use: pre-merge / release-critical / security patch. Not recommended daily.

## Output Format

Same format as skill.md. Additional labels:

```markdown
### 🔴 Critical (fix required, confidence ≥80)
### 🟡 Warning (improve, confidence 25-79)
Total: Critical N / Warning N
```

Fallback: zero findings → `Critical/Warning 0, Total no findings (N files)` / Multi/Deep partial fail → `### Degrade factors`.

## Critical/Warning ↔ P0/P1

`/review` solo = `Critical→P0` / `Warning→P1` / else `P2/P3`. Team path = report only. Details: [`reviewer-agent.md`](../agents/reviewer-agent.md).

## Review Policy & Scope

- **policy**: evidence-first (false positives are review debt), diff-only, Critical → Warning, 12 parallel
- **scope**: changed files (git diff). exclude: auto-gen / vendor / node_modules / lock
- **difit**: local only, background after review (require `npm i -g difit`, suppress: `--no-difit`)

Details: see review-related files under `references/`.
