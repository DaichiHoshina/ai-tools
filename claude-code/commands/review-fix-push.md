---
allowed-tools: Read, Glob, Grep, Bash, Skill, AskUserQuestion, mcp__serena__*, mcp__context7__*
description: Review→fix→regression check→push in 1 command. /review + /dev all fixes + re-review + /git-push --pr
---

## /review-fix-push - Review, Fix, Regression, Push

Find issues via review → fix → **verify no regression via re-review** → push → create PR. Fix doesn't introduce new Critical issues.

> **vs `/flow`**: `/flow` は「タスク記述からの新規実装 → PR」までを担う全工程経路、`/review-fix-push` は「既に書いたコードのレビューループ保証 → PR」専用。新規実装中は `/flow` の末尾 (`/review` + review-fix loop + `/git-push`) で `/review-fix-push` 相当を内包するため二重起動不要。既存変更を後追いで仕上げたい時のみ `/review-fix-push` を直接呼ぶ。

## Flow

### Step 1: Initial Review

```text
Skill("comprehensive-review")
```

12 angles + confidence-80 filter. Categorize by Critical/Warning. On finish, show diff in browser (`--no-difit` suppresses).

### Step 1.5: Self-Review Pass (必須)

Step 1 の出力をそのまま fix にかけず、**必ず** 2 段階の Self-Review を通す。詳細: `commands/review.md` `## Self-Review (必須、2 段階)` 参照。noise discard 方針: `rules/review-noise-discard.md`。Critical 0 + Warning 0 → Step 2 で push へ skip。判断ログは user 提示に含めない。

### Step 2: Decide

| State | Behavior |
|------|------|
| Critical 0 & Warning 0 | skip to Step 5 (push only) |
| any findings | proceed to Step 3 |

### Step 3: Fix

| Type | Policy |
|------|------|
| Critical | fix all (required) |
| Warning | fix all (`--critical-only` skips) |

Critical/Warning fixes は `Task(developer-agent)` へ委譲 (`CLAUDE.md` "Auto-Delegation" セクション準拠)。parent inline 実装は禁止。

### Step 4: Regression Check (loop)

Verify fix didn't create new issues **via re-review**. iteration 2 以降は scope 縮小で再 review を効率化（新規 finding 検出範囲は同等、前 iteration 領域は skip）。

```text
initial_base = git rev-parse HEAD  # Step 1 review 対象の base
prev_iter_commit = initial_base

loop iteration = 1..max_iterations:
    Skill("comprehensive-review", args="--diff-base=<prev_iter_commit> --mode=default")
    apply Self-Review 2-stage gate (必須、`/review` Self-Review section 参照)
    if 0 new Critical:
        if existing Warning ≤ initial count:
            break  # converged, go Step 5
        else:
            warn user, go Step 5 (prevent infinite fix)
    else:
        re-execute Step 3 (fix new Critical only)
        prev_iter_commit = git rev-parse HEAD  # 次 iteration の base に
```

**Loop exit conditions**:

| Condition | Behavior |
|-----------|----------|
| 0 new Critical | converge, proceed to push |
| iteration >= max_iterations (default 3) | show user status, ask to continue |
| same finding appears 2 consecutive iterations | stop loop, ask user for manual fix |

### Step 5: Push

```text
/git-push --pr
```

commit fix → push branch → create PR.

## Options

| Argument | Behavior |
|----------|----------|
| (none) | full pipeline (regression loop included) |
| `--critical-only` | fix Critical only |
| `--dry-run` | review only (no fix/push) |
| `--no-difit` | suppress difit startup |
| `--no-regression` | skip Step 4 (legacy behavior) |
| `--max-iterations <N>` | regression loop limit (default 3) |
| `--from-pr <N>` | restore PR session, review its diff |

With `--from-pr`, Step 0 does context restore like `claude --from-pr <N>`, then review that PR diff.

## Output Format

Loop progress:

```
Iteration 1/3: Critical 3 → 0 / Warning 5 → 2 (converged)
Iteration 2/3: skip (already converged)

Result: PASS → proceed to push
```

Loop unconverged:

```
Iteration 3/3: Critical 1 remains (same finding 2x)
> [WARN] cannot auto-fix, need user intervention
push aborted, Critical list:
  - {file:line} - {finding}
```

## Notes

- Show review results to user before fixing, get confirm
- force push forbidden
- auto-run lint/type-check after fix
- regression loop **guarantees fix doesn't create new issues**. if it doesn't stop, manual intervention

ARGUMENTS: $ARGUMENTS
