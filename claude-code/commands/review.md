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
| `--panel` | 3-lens parallel fan-out (style/security/test-coverage) → integrated by comprehensive-review | any | mid×3 |
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

## Multi-lens panel (--panel)

`/review --panel` で 3 つの lens を `reviewer-agent` × 3 並列で fan-out する。各 lens は他 lens の出力を見ない (blind diversity)。Source: [claudefa.st — Multi-Lens Panel Review](https://claudefa.st/blog/guide/agents/sub-agent-best-practices)

### lens 構成

| lens | focus | 無視するもの |
|---|---|---|
| style | naming / readability / convention / cognitive complexity | logic / security |
| security | authn/authz / injection / secrets / data boundary / unsafe logging | style / coverage |
| test-coverage | test adequacy / missing edge cases / silent-failure paths | style / security |

- 各 lens には diff + 担当 focus のみを渡す (他 lens の出力は含めない)
- 3 lens を **1 message に bundle して並列発火** (`Task(reviewer-agent)` × 3、peak_concurrency=3)

### 関係表

| component | 役割 |
|---|---|
| `--panel` lens × 3 | blind diversity → 各 lens が独立 verdict を返す |
| `comprehensive-review` skill | lens 3 verdict を input に取り、12 観点 review と統合 (詳細: `skills/comprehensive-review/SKILL.md` §Multi-lens panel mode) |
| Stage A self-review | panel 統合後の finding に適用 (既存挙動変化なし) |

### 集計 rule

parent が 3 lens の verdict を file:line key で集約する。

- 2/3 以上で hit → severity 最大値を採用して Stage A へ渡す
- 1/3 のみ hit → P3 (Info) に降格、verbose mode でのみ表示
- 全 lens が miss → clean (high confidence)

**default は panel なし** (`--panel` opt-in)。通常 diff には `/review` 標準で十分。大規模 PR の pre-merge 最終確認に限定を推奨。

## Verifier panel (--verifier-panel)

`/review --verifier-panel=N` (N=3 推奨、default OFF) で reviewer-agent を N 体 fan-out する。同 engine だが各エージェントが fresh context で異なる lens を担当し、多数決で confirmed finding のみ昇格する。Claude Code 公式 best practices の perspective-diverse verify を実装する。既存 `--multi` (engine 別 = comprehensive / codex / coderabbit / code-review 並列) とは直交の軸。

### lens 仕様 (N=3 default)

| lens | focus | 無視するもの |
|---|---|---|
| correctness | logic の正当性 / 仕様との一致 / 想定外の入力での挙動 / 競合状態 | style / typo / 命名 |
| consistency | 既存の convention / cross-file naming / propagation の完全性 / import 順 | logic / 新規発見 |
| boundary | input validation / edge case / error path / secrets handling / data 境界 | logic 全般 / style |

各 lens に渡す delegation prompt の雛形は `agents/reviewer-agent.md` `## Lens-specific mode` 参照。

### 集計 rule

parent 側で N 個の lens 結果を file:line key で集約する。

- 2/N 以上の lens で hit → P0 (Critical) or P1 (Warning)、severity は最大値を採用
- 1/N のみ hit → P3 (Info) に降格、最終 report からは silent (verbose mode で表示)
- 全 lens が miss → 真の clean (high confidence)

**token cost**: panel は **N 倍の token** を消費する。default OFF を維持し、大規模 PR の pre-merge 最終確認に限定して使う。短時間 / 小 diff には `/review` 標準で十分。

**既存 flag との直交**: `--multi --verifier-panel=3` で 4 engine × 3 lens = 12 並列も可能。token が 12 倍になるため推奨せず、どちらか一方に絞ること。

### fan-out 制約

CLAUDE.md の `1 dev = 1 file 原則` / parent 監視責任は panel にも適用する。`Task(reviewer-agent)` ×N は 1 message に bundle して並列発火する (peak_concurrency=N、逐次での発火禁止)。
