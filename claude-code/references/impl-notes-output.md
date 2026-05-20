# IMPL_NOTES Output

Cross-session impl-time decision capture for PR draft material.

## Purpose

Preserve Developer decision-making during Team flow impl. Decisions (Design / Deviations / Tradeoffs / Open questions) are recorded per-task, merged by Manager, surfaced by `/git-push --pr` as PR draft candidate. Complements chat history and `/memory-save` for decisions worth PR visibility.

## Trigger & Storage

- Trigger: `/flow` Team path only (Manager allocation contains `impl_notes.dir`)
- Silent skip: `/dev` / `/dev --parallel` / direct `/git-push` — no `impl_notes.dir`, no notes
- Storage: `~/.claude/plans/impl-notes/YYYY-MM-DD_HHMMSS_<feature-slug>/`
- feature-slug: from `worktree.branch`, sanitized (lowercase → `[a-z0-9-]` → collapse `-` → trim → 60 char)

## Responsibility

| Actor | Output |
|---|---|
| Developer | `dev-<task-id>.md` once at completion, 4 sections (template in [`../agents/developer-agent.md`](../agents/developer-agent.md) § IMPL_NOTES output). Re-fix re-spawn appends `## Re-fix iteration <N>` |
| Manager | MERGED.md *content* returned to parent (read-only). Section-wise concat + `task-id` annotation + `open_questions_pending` flag |
| Parent (`/flow`) | `mkdir -p <impl_notes.dir>` pre-Dev; Write MERGED.md post-Manager |
| Reviewer | none — MERGED.md read-only reference, never edits |

## PR draft consumption

`/git-push --pr` detects `MERGED.md` whose slug matches current branch (sanitized both, latest timestamp wins). Surfaces **Design decisions** + **Open questions** in confirm step. `--no-impl-notes` skips. Cross-Dev semantic conflict detection out of scope.

## References

- [`../agents/developer-agent.md`](../agents/developer-agent.md) / [`../agents/manager-agent.md`](../agents/manager-agent.md) / [`../commands/flow.md`](../commands/flow.md) / [`../commands/git-push.md`](../commands/git-push.md)
