# Multi-Repo Workflow (parallel work)

Flow when instructed "apply the same fix" across multiple repositories.

## Procedure

1. Confirm target repositories (ask user to enumerate)
2. Apply fix in the first repository
3. After confirming changes, apply the same fix to remaining repositories
4. Run `/git-push --pr` per repository

## PR split strategy

When diff is large, split into multiple PRs:

- **Each PR must not break main when merged independently**
- Split example: migration → model/repository → usecase → handler → frontend
- Unused code may be introduced early (to be used in next PR)
- Migration must be a standalone PR (do not mix with other changes)
- Numeric thresholds (10 files / 500 lines / migration standalone): details in `ticket-to-pr-workflow.md` §4
