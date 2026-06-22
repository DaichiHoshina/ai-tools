# Markdown anchor sync rule

Commits that rename / EN-ify / reword markdown headings under `claude-code/` risk breaking bats test exact-match anchors, cross-reference slugs in other files, and `PARALLEL-PATTERNS.md` literals.

## Sources of breakage

| Change type | Breaks |
|---------|---------|
| heading rename / EN conversion | `require_anchor` / `grep -qF` expectations in `tests/` |
| slug change | `#anchor-slug` cross-references in other files |
| `PARALLEL-PATTERNS.md` rewrite | `allowed_summaries` / `forbidden_phrases` exact-match in `parallel-consistency.bats` |

## Required steps (run before changing any heading)

Check old `<heading>` and old slug `<slug>` with:

```bash
# bats 期待値に使われているか確認
grep -rn '"<heading>"' claude-code/tests/
grep -rn "'<heading>'" claude-code/tests/

# cross-reference anchor として使われているか確認
grep -rn '#<slug>\b' claude-code/
```

If there are hits, update bats and cross-refs in the same commit as the heading change.

### Bulk scan one-liner

Before creating a commit that changes headings, extract old headings from `git diff` and scan bats / cross-refs at once.

```bash
git diff HEAD -- '*.md' | grep -E '^-#' | sed 's/^-//' | while read h; do
  slug=$(echo "$h" | sed -E 's/^#+ //' | tr 'A-Z' 'a-z' | sed -E 's/[^a-z0-9 -]//g; s/ +/-/g')
  echo "=== $h (slug: $slug) ==="
  grep -rn -F "\"$h\"" claude-code/tests/ 2>/dev/null
  grep -rn -F "'$h'" claude-code/tests/ 2>/dev/null
  grep -rn -F "#$slug" claude-code/ 2>/dev/null
done
```

On hits, sync in the same commit. On 0 hits, still append "heading rename / anchor confirmed clean" to the commit message so future reviewers know it was checked.

## Required `/review` option

Run reviews for PRs that change markdown headings with:

```
/review --focus=consistency
```

Run at least 2 iterations (bats anchor breakage is sometimes missed in the first pass).

## Past incident (2026-05-23, commit `c67ade1`)

An EN-ify commit renamed 3 headings, breaking 4 bats tests (`parallel-consistency.bats` / `agent-frontmatter.bats` exact-match anchors) plus stale `#worktree-applicability-flow` slug callers in `manager-agent.md` / `po-agent.md`. First detected in review iter 2, missed in iter 1 — hence the 2-iteration rule above.

## Scope

- All markdown rename PRs under `claude-code/`
- When delegating to developer-agent and the change includes markdown heading renames, explicitly state this rule in the delegation prompt
