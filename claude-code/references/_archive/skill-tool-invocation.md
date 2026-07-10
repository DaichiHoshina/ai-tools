# Skill Tool Invocation Pattern (forked execution)

`Skill("comprehensive-review")` and similar Skill tool launches run as a separate process (forked execution). The parent workspace's `git status` / `git diff` are not visible; launching without arguments fails with:

```
Diff target not provided. Cannot run review without scope.
```

## Required args

When launching review / analysis type Skills, always specify one of:

| arg | Format | Purpose |
|-----|--------|---------|
| `--files=` | Comma-separated absolute paths | Target specific files |
| `--diff-base=` | git ref | Target commit diff |
| `--mode=` | `default` / `codex` / `adversarial` / `deep` | Review intensity (optional) |

## Examples

```
# Specific files
Skill(skill="comprehensive-review", args="--files=/abs/path/a.md,/abs/path/b.md --mode=default")

# Commit diff
Skill(skill="comprehensive-review", args="--diff-base=HEAD --mode=default")

# Branch comparison
Skill(skill="comprehensive-review", args="--diff-base=main..HEAD --mode=adversarial")

# One commit before
Skill(skill="comprehensive-review", args="--diff-base=e5f32ed~1")
```

## Applicable Skills

- `comprehensive-review`
- `security-review`
- All other review / analysis type skills

## Discovery

Confirmed 2026-05-23 via `/review-fix-push` smoke test: launching without args fails with "Diff target not provided."

## Related

- `references/review-commands.md`
- `references/review-patterns-universal.md`
