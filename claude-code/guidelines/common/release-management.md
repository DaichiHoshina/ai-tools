# Release Management Guidelines

> **Purpose**: Responsibility split between PR author and release owner, and the release flow. Reference after PR merge / when executing a production release.

## Roles

| Role | Responsibility |
|------|----------------|
| PR author | Merge → confirm own changes after release → report completion |
| Release owner | Wait for CI → execute release → notify → monitor → report completion |

## Release Flow

```text
PR merge → wait for main CI completion (no release before completion) → confirm no prior incidents
→ execute release (GitHub Releases/CD) → wait for deploy completion
→ request confirmation in release channel → monitor dashboard 10-15 min → report completion
```

## When Release Verification Is Not Required

Judge by: "Does this release change behavior in production?"

| Case | Check | Reason |
|------|-------|--------|
| Unused model/usecase added (parts for next PR) | Not needed | Not called yet |
| Fixture/test data/refactor | Not needed | No user impact |
| API change (response changes etc.) | **Required** | User impact |
| Migration | **Required** | Must release alone |
| Screen change | **Required** | User impact |

## main Branch Lock Strategy

### Why Locking Is Needed

If another merge lands while CI is running, CI restarts and the release cannot proceed.

### Steps

1. Merge PR to main (complete merge before locking)
2. Lock main immediately after merge
3. Notify team that main is locked
4. CI completes → execute release → deploy → confirm
5. Unlock + notify team

### Cases Where Lock Is Required

| Case | Reason |
|------|--------|
| Migration | Risk of execution order conflict with other PRs' migrations |
| Hotfix / Revert | Other changes mixed in make root cause identification and rollback difficult |
| Payment-related | High impact on failure |
| Search-related | Wide impact scope |

## Revert Steps

1. Re-run the previous deploy in the CD pipeline
2. Share in team channel (attach Re-run URL)
3. Create a Revert PR
4. No additional release needed once the Revert PR is merged to main

**Note**: Always consult before reverting a release that includes DB changes.

## Emergency Release

1. Notify tech lead
2. Cancel all CI currently running on main
3. Execute release immediately

## Rules

| Rule | Reason |
|------|--------|
| No Friday releases | Risk of incident response spilling into the weekend |
| Migration releases must be solo | Enables easy rollback |
| main sync with `git merge --no-ff` | Rebase forbidden (destroys review comment positions) |
| Release merged code same day | Prevents unreleased code accumulation |

## Release Timing

| Condition | Release Owner |
|-----------|---------------|
| Merged during business hours | Release owner (on rotation) |
| Merged outside business hours | The person who merged (OK to defer to next time if parts-only) |
