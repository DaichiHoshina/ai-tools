---
allowed-tools: Read, Glob, Grep, Bash, Skill, Agent, AskUserQuestion, mcp__serena__*
description: Comprehensive code review (comprehensive-review 11 angles + official plugin/codex/coderabbit/pr-review-toolkit integration)
---

## /review - Comprehensive Code Review

> comprehensive-review skill integrates 11 angles (architecture/quality/readability/security/docs/test-coverage/root-cause/logging/writing/silent-failure/type-design). `--deep`/`--multi` parallelizes external reviewers.

## Constraints & Lenses

Constraints (Stage A/B でも適用):
- Hypothesis 系は "hypothesis:" prefix で notes 行きへ
- No unsolicited issue/ticket/task/TODO auto-gen、TODO は current blocker のみ
- "for confirmation" / "best to check" 系は action task に格上げしない

Lenses (Stage A/B 通過の前提):
- Language/FW best practices (idioms / lifecycle / type-safety / local pattern)
- Code design (DDD / Clean Architecture / module boundary / coupling)
- Permanent/root fix (workaround / 互換残 / 再発パッチでないこと)
- Security (authn/authz / injection / secret / tenant isolation / unsafe logging)

## Self-Review (必須、2 段階)

`/review` 系コマンドの出力前に **必ず** 以下 2 段階のセルフレビューを実行する。skip 不可、`--dry-run` / `--codex` / `--multi` / `--deep` / `--adversarial` 全モードで一律実行 (adversarial は design challenge 性質ゆえ Stage A の Evidence/Scope 判定基準は緩めつつ、Stage B の重複統合・トーン整合は通常通り適用)。

### Stage A: Finding Self-Review Gate (per-finding)

`comprehensive-review` skill 内の Self-Filter Gate (Step 4.5 + Pre-emission sanity check) が Evidence / Scope / No-invented-framing / Actionability / Severity の 7 観点でカバー済み。Stage A では skill 結果を信頼し、再評価不要。skill 未通過項目が明らかに混入していた場合のみ手動再判定。

### Stage B: Result Self-Review Pass (全体)

Stage A 通過後の finding 群を **集合として** もう一度見直す。以下 4 観点:

1. **重複 / 類似統合**: 同一 root cause を複数 lens が別 finding として出してないか? 統合して 1 件に。
2. **トーン整合**: Critical / Warning 比率が偏ってないか? Critical 多発時は本当に全部 Critical か再評価 (false alarm 警戒)。
3. **Project convention 整合**: CLAUDE.md / guidelines / 既存コード規約に照らして妥当か? 規約外の好み指摘は破棄。
4. **Zero-finding 判定**: 結果として finding 0 件は valid 出力。出すこと自体に意義はないので、padding (無理に何か出す) は禁止。

Stage B の判断ログは出力に含めない (verdict が変わったときのみ反映)。両 stage を通過した finding のみが Output Format に進む。

## Step 0: Auto-infer Mode (no flags)

When started without `--xxx`, auto-infer recommended mode **after user confirms** (no heavy mode without consent).

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
| `--focus=<angle>` | narrow 11 angles |
| `--no-difit` | suppress difit (local only) |

| Mode | Delegate | PR | Cost |
|--------|--------|----|--------|
| (default) | `comprehensive-review` skill | any | mid |
| `--codex` | comprehensive + codex plugin parallel, common findings = Critical | any | mid |
| `--adversarial` | codex plugin `adversarial-review` (plugin required) | any | mid |
| `--deep` | pr-review-toolkit 6 agents parallel (5-10min) | any | large |
| `--multi` | comprehensive + codex + code-review + coderabbit parallel → auto-post to PR | **required** | max |

cloud large: see `/ultrareview` (separate).

### CI Integration

Non-interactive `claude ultrareview <PR_or_path> --json` for machine-readable output, gated via exit code. Split slash (interactive) vs subcommand (CI).

## Codex Invocation (--codex / --adversarial)

Via plugin runtime: `node "${CODEX_PLUGIN_ROOT}/scripts/codex-companion.mjs" <review|adversarial-review> --wait`. `${CODEX_PLUGIN_ROOT}` = `ls -1d ~/.claude/plugins/cache/openai-codex/codex/* | tail -1`. Fallback if plugin missing: `--codex` only uses `codex review` direct (adversarial-review plugin-only).

## Adversarial Flow

**Challenge design correctness, assumptions, real-world failure points**. `$ARGUMENTS` can add `--base <ref>`, `--scope auto|working-tree|branch`, focus text. Long-running? use `--background` → `/codex:status`/`/codex:result <id>`.

Use: design review, surface tradeoffs, pre-PR self-challenge. Complement to `/review` (implementation defects).

## Deep Flow

Spin 6 agents from `pr-review-toolkit` in parallel. Detail & aggregation: [`references/review-modes-advanced.md`](../references/review-modes-advanced.md). **Cost warning**: tens of seconds ~ minutes × 6 parallel. Daily = default.

## Multi Flow

PR required. **Fetch PR locally first**, then 4-method parallel.

```text
0. PR fetch:
   - gh pr diff <PR> > /tmp/review-multi-<PR>.diff
   - PR_BASE=$(gh pr view <PR> --json baseRefName --jq .baseRefName)
1. Parallel:
   a. Skill("comprehensive-review") with --diff-source=/tmp/review-multi-<PR>.diff
   b. codex plugin runtime --base "${PR_BASE}" (or codex review --pr <PR> if missing)
   c. /code-review:code-review <PR>
   d. coderabbit:code-review skill
2. merge 4 outputs, deduplicate
3. gh pr comment <PR> --body-file - auto-post
```

Aggregation strategy (3+ = Critical confirmed, etc): [`references/review-modes-advanced.md`](../references/review-modes-advanced.md).

Use: pre-merge PR, release-critical, security patch. Not daily.

## Output Format

```markdown
## Comprehensive Review Results
### Angles Executed
✅ architecture / quality / readability / security / docs / test-coverage / root-cause / logging / writing / silent-failure / type-design

### 🔴 Critical (fix required, confidence ≥80)
- [security] SQLi (src/api/user.ts:120) confidence 95

### 🟡 Warning (improve, confidence 25-79)
- [quality] legacy pattern (pkg/sort.go:15) confidence 65

Total: Critical N / Warning N
```

Fallback: zero findings → `Critical/Warning 0, Total no findings (N files)` / Multi/Deep partial fail → warn at end + `### Degrade factors`.

## Critical/Warning ↔ P0/P1

`/review` solo = `Critical→P0` / `Warning→P1` / else `P2/P3` (Team path = report only). Detail: [`reviewer-agent.md`](../agents/reviewer-agent.md).

## Review Policy, Scope, Difit

- **policy**: evidence-first (false positives are review debt), diff-only, Critical → Warning, 11 parallel
- **scope**: changed files (git diff), new. exclude: auto-gen, vendor/node_modules, lock
- **difit**: local only, background after review (require `npm i -g difit`, suppress via `--no-difit`)

detail map: [`references/command-resource-map.md`](../references/command-resource-map.md) / [`references/review-modes-advanced.md`](../references/review-modes-advanced.md)
