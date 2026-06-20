---
allowed-tools: Read, Glob, Grep, Bash, Skill, Agent, AskUserQuestion, mcp__serena__*
description: Comprehensive code review (comprehensive-review skill + optional external reviewers)
---

# /review - Comprehensive Code Review

> Runs 12-angle review via `comprehensive-review` skill. `--deep`/`--multi` parallelizes external reviewers.
> Noise filter policy: `rules/review-noise-discard.md` / Finding constraints: `skills/comprehensive-review/skill.md` Step -1

## Delegation & Self-Review (required, 2 stages)

**Delegation**: Delegate `comprehensive-review` skill to `reviewer-agent` (Sonnet) via Task. Delegation prompt: `"Run comprehensive-review skill on current diff. focus=${focus}. Return raw findings list with confidence scores."` Parent Opus runs Stage A (per-finding); Stage B aggregate は reviewer-agent に再委譲する。

**Always** run the following 2-stage self-review before outputting `/review` results. Applied uniformly to all modes (`--dry-run` / `--codex` / `--multi` / `--deep` / `--adversarial`) — cannot skip.

### Stage A: Finding Self-Review Gate (per-finding)

Skill Step 4.5 has already done primary eval on 7 angles: Evidence / Scope / Overreach / Actionability / Severity / Style / Overprescription. **Parent Opus must run safety-net re-eval on the same 7 angles**. Prioritize propagation incompleteness / cross-ref desync. Do not include judgment log in output.

Adversarial mode: relax Evidence/Scope criteria (design-challenge nature); Stage B dedup proceeds as normal.

### Stage B: Result Self-Review Pass (overall) — reviewer-agent 委譲

Stage A を通過した finding を JSON list として渡し、`reviewer-agent --stage-b` に委譲する。fresh context での集約判定で、実装直後のバイアスを抑止する。

- 委譲先: `Task(subagent_type: "reviewer-agent")`
- prompt 雛形: `"Stage B aggregate review. Input: Stage A filtered findings (JSON list, below). Apply: (1) phase consolidation (same root cause → 1 finding), (2) granularity alignment, (3) convention alignment, (4) Zero-phase valid (no padding). Return: confirmed findings as JSON {p0: [...], p1: [...], p2: [...]}. Do NOT add new findings — filter only. Noise discard policy: rules/review-noise-discard.md (confidence <80 / style nitpick / hypothetical edge case / scope-out suggestions are discard targets)."`
- parent 側の責務: Stage A (per-finding) のみ。Stage B の出力をそのまま `/review-fix-push` Step 3 に渡す
- 判定ログは plan file / chat に出さない。Stage B 結果のみを表示する

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
