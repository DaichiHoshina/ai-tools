---
allowed-tools: Read, Glob, Grep, Bash, Skill, Agent, AskUserQuestion, mcp__serena__*
description: Comprehensive code review (comprehensive-review 11 angles + official plugin/codex/coderabbit/pr-review-toolkit integration)
---

## /review - Comprehensive Code Review

> comprehensive-review skill integrates 11 angles (architecture/quality/readability/security/docs/test-coverage/root-cause/logging/writing/silent-failure/type-design). `--deep`/`--multi` parallelizes external reviewers.

## Common Review Constraints

- Only evidence-based findings on real diff/code/docs. Flag hypothesis with "hypothesis:"
- exclude style preference, opinions, general wisdom, out-of-scope design debate
- limit findings to actionable items, modifiable items
- don't invent a problem statement and then review against it. A finding needs an observed violation/regression/risk in the requested scope.
- speculative "this could be an issue" belongs in questions/notes, not Critical/Warning.
- no unsolicited issue/ticket/task/TODO auto-generation
- don't escalate "for confirmation" or "best to check" items to action tasks
- TODO only if blocker for current work

## Default Evidence-Backed Lenses

Apply these lenses to code reviews, but only promote issues that satisfy the common constraints above:

- **Language/FW best practices**: language idioms, framework contracts, lifecycle rules, type-safety conventions, and local project patterns.
- **Code design**: DDD boundaries, Clean Architecture dependency direction, modular monolith module boundaries, ownership, and coupling.
- **Permanent/root fix**: whether the change fixes the root cause instead of adding a workaround, compatibility remnant, or recurrence-prone patch.
- **Security**: authn/authz, injection, secret handling, tenant/data isolation, unsafe logging, and dependency/config exposure.

## Finding Self-Review Gate

Before outputting any Critical/Warning, self-review each candidate finding:

1. **Evidence**: Is the claim anchored to observed diff/code/docs/tests/tool output?
2. **Scope**: Is the claim inside the user request or changed behavior?
3. **No invented framing**: Did the review create a new problem statement not present in evidence?
4. **Actionability**: Can the author change code/docs/tests now to address it?
5. **Severity**: Is the Critical/Warning level proportional to actual impact?

If any answer is "no", discard it or move it to a short question/note. Do not include self-review notes in the final output unless they affect the verdict.

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

## Pre-Emit Step (required, all modes)

Before producing the Output Format block below, run the **Finding Self-Review Gate** (L30-40) against every candidate Critical/Warning. Discard or downgrade any finding that fails Evidence/Scope/No-invented-framing/Actionability/Severity. Style-only or aesthetic-preference findings without a documented rule violation are discarded. Zero findings is a valid output — do not pad.

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
