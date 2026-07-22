---
allowed-tools: Read, Glob, Grep, Bash, Skill, AskUserQuestion, mcp__serena__*, mcp__context7__*
description: Review→fix→regression check→push in 1 command. /review + /dev all fixes + re-review + /git-push --pr
argument-hint: "[scope]"
---

## /review-fix-push - Review, Fix, Regression, Push

Find issues via review → fix → **verify no regression via re-review** → push → create PR. Fix must not introduce new Critical issues.

> **vs `/flow`**: `/flow` owns the full path from task description to new implementation → PR. `/review-fix-push` is dedicated to "review-loop guarantee for already-written code → PR". New implementation uses `/flow`'s tail (`/review` + review-fix loop + `/git-push`), which subsumes `/review-fix-push` — no double invocation needed. Use `/review-fix-push` only to finish existing changes after the fact.

## Flow

### Step 1: Initial Review

```text
Skill("comprehensive-review")
```

12 angles + confidence-80 filter. Categorize by Critical/Warning. On finish, show diff in browser (`--no-difit` suppresses).

### Step 1.5: Self-Review Pass (required)

Never feed Step 1 output directly to fix. Always apply 2-stage Self-Review. Details: `commands/review.md` `## Delegation & Self-Review (required, 2 stages)`. Noise discard policy: `references/on-demand-rules/review-noise-discard.md`. Critical 0 + Warning 0 → skip to Step 2 (push). Judgment log: do not surface to user.

### Step 2: Decide

| State | Behavior |
|-------|----------|
| Critical 0 & Warning 0 | skip to Step 5 (push only) |
| any findings | proceed to Step 3 |

### Step 3: Fix

| Type | Policy |
|------|--------|
| Critical | fix all (required) |
| Warning | fix all |

Delegate Critical/Warning fixes to `Task(developer-agent)` (per `CLAUDE.md` "Auto-Delegation" section). Parent inline implementation forbidden.

### Step 4: Regression Check (loop)

Verify fix did not create new issues **via re-review**. From iteration 2 onward, narrow scope for efficiency (same detection range for new findings; skip prior-iteration areas).

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
| `--dry-run` | review only (no fix/push) |
| `--no-difit` | suppress difit startup |

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
- regression loop **guarantees fix does not create new issues**; if it does not stop, manual intervention required

ARGUMENTS: $ARGUMENTS
