---
allowed-tools: Read, Glob, Grep, Bash, Skill, Agent, AskUserQuestion, mcp__serena__*
description: Comprehensive code review (comprehensive-review skill + optional external reviewers)
---

# /review - Comprehensive Code Review

> `comprehensive-review` skill で 12 観点レビュー実行。`--deep`/`--multi` で外部レビュアー並列化。
> Noise filter 方針: `rules/review-noise-discard.md` / Finding constraints: `skills/comprehensive-review/SKILL.md` Step -1

## Delegation & Self-Review (必須、2 段階)

**Delegation**: `comprehensive-review` skill を `reviewer-agent` (Sonnet) に Task 委譲。委譲 prompt: `"Run comprehensive-review skill on current diff. focus=${focus}. Return raw findings list with confidence scores."` Parent Opus は Stage B filter のみ担当。

`/review` 系コマンド出力前に **必ず** 以下 2 段階のセルフレビューを実行する。`--dry-run` / `--codex` / `--multi` / `--deep` / `--adversarial` 全モードで一律適用、skip 不可。

### Stage A: Finding Self-Review Gate (per-finding)

skill の Step 4.5 が Evidence / Scope / Overreach / Actionability / Severity / Style / Overprescription の 7 観点で一次評価済。**parent Opus が同 7 観点で safety net 再評価を必ず実行**。propagation incompleteness / cross-ref desync 系は重点確認。判断ログは出力に含めない。

adversarial モード: Evidence/Scope 判定基準は緩め (design challenge 性質)、Stage B の重複統合は通常通り。

### Stage B: Result Self-Review Pass (全体)

1. **重複統合**: 同一 root cause を複数 lens が別 finding にしていないか → 1 件に統合
2. **トーン整合**: Critical 多発時は false alarm 警戒、再評価
3. **Project convention**: CLAUDE.md / guidelines に照らして妥当か、規約外の好み指摘は破棄
4. **Zero-finding**: 0 件は valid、padding 禁止

## Step 0: Auto-infer Mode (no flags)

起動時 flags なし → 推奨モードを提示しユーザ確認後実行 (heavy モードは同意なし自動実行禁止)。

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
| `--focus=<angle>` | narrow 12 angles (see SKILL.md) |
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

Design correctness / assumptions / real-world failure points を challenge。`--base <ref>` / `--scope auto|working-tree|branch` / `--background` → `/codex:status`/`/codex:result <id>`. 用途: design review / pre-PR self-challenge。実装欠陥は `/review` default。

## Deep Flow

`pr-review-toolkit` 6 agents を並列実行。詳細: [`references/review-modes-advanced.md`](../references/review-modes-advanced.md)。**Cost warning**: tens of seconds ~ minutes × 6 parallel。Daily = default。

## Multi Flow

PR required。4 メソッド並列実行:

1. PR diff を `/tmp/review-multi-<PR>.diff` に取得
2. 並列: (a) `comprehensive-review` skill / (b) codex plugin / (c) `/code-review:code-review` / (d) `coderabbit:code-review`
3. 4 出力をマージ・重複排除
4. `gh pr comment <PR> --body-file -` で auto-post

Aggregation (3+一致 = Critical confirmed 等): [`references/review-modes-advanced.md`](../references/review-modes-advanced.md)。用途: pre-merge / release-critical / security patch。Daily 不推奨。

## Output Format

SKILL.md と同一フォーマット。追加ラベル:

```markdown
### 🔴 Critical (fix required, confidence ≥80)
### 🟡 Warning (improve, confidence 25-79)
Total: Critical N / Warning N
```

Fallback: zero findings → `Critical/Warning 0, Total no findings (N files)` / Multi/Deep partial fail → `### Degrade factors`。

## Critical/Warning ↔ P0/P1

`/review` solo = `Critical→P0` / `Warning→P1` / else `P2/P3`。Team path = report only。詳細: [`reviewer-agent.md`](../agents/reviewer-agent.md)。

## Review Policy & Scope

- **policy**: evidence-first (false positives are review debt), diff-only, Critical → Warning, 12 parallel
- **scope**: changed files (git diff). exclude: auto-gen / vendor / node_modules / lock
- **difit**: local only, background after review (require `npm i -g difit`, suppress: `--no-difit`)

detail: [`references/command-resource-map.md`](../references/command-resource-map.md) / [`references/review-modes-advanced.md`](../references/review-modes-advanced.md)
