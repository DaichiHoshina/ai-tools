---
allowed-tools: Read, Glob, Grep, Bash, Skill, Agent, AskUserQuestion, mcp__serena__*
description: Full code review (`comprehensive-review` skill + optional external reviewers)
argument-hint: "[scope]"
---

# /review - Full Code Review

> Runs 12-angle review via `comprehensive-review` skill. `--deep`/`--multi` parallelizes external reviewers.
> Noise filter policy: `references/on-demand-rules/review-noise-discard.md` / Finding constraints: `skills/comprehensive-review/SKILL.md` Step -1

## Delegation & Self-Review (required, 2 stages)

**Delegation**: Delegate `comprehensive-review` skill to `reviewer-agent` (Sonnet) via Task. Delegation prompt: `"Run comprehensive-review skill on current diff. focus=${focus}. Return raw findings list with confidence scores."` Parent Opus runs Stage A (per-finding); Stage B aggregate delegates back to reviewer-agent.

**Always** run the following 2-stage self-review before outputting `/review` results. Applied uniformly to all modes (`--dry-run` / `--codex` / `--multi` / `--deep` / `--adversarial`) — cannot skip.

### Stage A: Finding Self-Review Gate (per-finding)

Skill Step 4.5 既に 7 angle primary eval 済 (Evidence / Scope / Overreach / Actionability / Severity / Style / Overprescription)。**Parent Opus は safety-net 再 eval を同 7 angle で実行する**。propagation incompleteness / cross-ref desync を優先。判定 log は output に含めない。Adversarial mode は Evidence/Scope を緩める (design-challenge 性質)、Stage B dedup は通常通り。

### Stage B: Result Self-Review Pass (overall) — delegate to reviewer-agent

Stage A findings を JSON list で `reviewer-agent --stage-b` へ渡す (fresh context aggregate が post-impl bias を抑える)。Delegate: `Task(subagent_type: "reviewer-agent")`。Prompt: `"Stage B aggregate review. Input: Stage A filtered findings (JSON list). Apply: (1) phase consolidation, (2) detail-level alignment, (3) convention alignment, (4) Zero-phase valid (no padding). Return: confirmed findings as JSON {p0/p1/p2}. Filter only — no new findings. Noise policy: references/on-demand-rules/review-noise-discard.md (confidence <80 / style nitpick / hypothetical edge / scope-out は discard)。"`。Parent は Stage A のみ担当、Stage B 結果を `/review-fix-push` Step 3 へ渡す。判定 log は plan file / chat に出さず Stage B 結果のみ表示する。

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

## Flow details (Adversarial / Deep / Multi)

- **Adversarial**: design correctness / assumptions / real-world failure points を challenge する。`--base <ref>` / `--scope auto|working-tree|branch` / `--background` → `/codex:status` `/codex:result <id>`。用途: design review / pre-PR self-challenge。Implementation defects は `/review` default を使う
- **Deep**: `pr-review-toolkit` 6 agents 並列。**Cost warning**: 数十秒〜数分 × 6 並列。Daily は default を使う
- **Multi**: PR 必須。4 methods 並列 ((a) `comprehensive-review` skill / (b) codex plugin / (c) `/code-review:code-review` / (d) `coderabbit:code-review`) → merge + dedup → `gh pr comment` auto-post。Aggregation: 3+ agree = Critical confirmed。用途: pre-merge / security patch、daily 非推奨

## Output Format

Same format as skill.md. Labels: `🔴 Critical (fix required, confidence ≥80)` / `🟡 Warning (improve, confidence 25-79)` / `Total: Critical N / Warning N`. Fallback: zero findings → `Critical/Warning 0, Total no findings (N files)` / Multi/Deep partial fail → `### Degrade factors`.

## Critical/Warning ↔ P0/P1

`/review` solo = `Critical→P0` / `Warning→P1` / else `P2/P3`. Team path = report only. Details: [`reviewer-agent.md`](../agents/reviewer-agent.md).

## Review Policy & Scope

- **policy**: evidence-first (false positives are review debt), diff-only, Critical → Warning, 12 parallel
- **scope**: changed files (git diff). exclude: auto-gen / vendor / node_modules / lock
- **difit**: local only, background after review (require `npm i -g difit`, suppress: `--no-difit`)

## Panel modes (--panel / --verifier-panel)

Fan-out `reviewer-agent` × N in parallel; each lens blind to others. Source: [claudefa.st — Multi-Lens Panel Review](https://claudefa.st/blog/guide/agents/sub-agent-best-practices). `--panel` = 3 fixed lens (style/security/test-coverage) integrated by `comp-review` skill. `--verifier-panel=N` = N lens (correctness/consistency/boundary, fresh context, majority-confirmed only promoted). Orthogonal to `--multi` (engine-diverse).

### Lens config

| mode | lens | focus | ignores |
|---|---|---|---|
| `--panel` | style | naming / readability / convention / cognitive complexity | logic / security |
| `--panel` | security | authn/authz / injection / secrets / data boundary / unsafe logging | style / coverage |
| `--panel` | test-coverage | test adequacy / missing edge cases / silent-failure paths | style / security |
| `--verifier-panel` | correctness | logic validity / spec conformance / unexpected input / race conditions | style / typo / naming |
| `--verifier-panel` | consistency | existing convention / cross-file naming / propagation / import order | logic / new findings |
| `--verifier-panel` | boundary | input validation / edge case / error path / secrets / data boundary | general logic / style |

Delegation prompt per lens: `agents/reviewer-agent.md` `## Lens-specific mode`.

**Common rules**: pass diff + assigned focus only / fire N lens in **1 message bundle** (`Task(reviewer-agent)` × N, peak_concurrency=N、sequential 禁止) / aggregation by `file:line` key (2/N+ → max severity → Stage A / 1/N → P3 silent / all miss → clean) / **default OFF**, large PR pre-merge final check に限定 / `--verifier-panel` token cost = N×、`--multi --verifier-panel=3` = 12× cost なので 1 つを選ぶ / CLAUDE.md `1 dev = 1 file` + parent oversight 適用。
