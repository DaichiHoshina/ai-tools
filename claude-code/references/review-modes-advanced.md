# `/review` Advanced Reference

Detailed spec extracted from `commands/review.md` (agent table / aggregation policy / comment JSON format / review policy). Command body holds summary only; refer here for details.

## Deep flow details (agent table)

Launch `pr-review-toolkit`'s 6 agents as **6 simultaneous Agent tool calls in 1 message**.

| subagent_type | Perspective |
|---------------|------|
| `pr-review-toolkit:code-reviewer` | CLAUDE.md compliance / best practices |
| `pr-review-toolkit:silent-failure-hunter` | Swallowed errors / empty catch |
| `pr-review-toolkit:type-design-analyzer` | Expressing invariants with types |
| `pr-review-toolkit:comment-analyzer` | Comment accuracy / comment rot |
| `pr-review-toolkit:pr-test-analyzer` | Test coverage / edge cases |
| `pr-review-toolkit:code-simplifier` | Code simplification / readability |

Embed target diff (`git diff` or `gh pr diff <N>`) in each agent prompt. **Cost warning**: agent launch cost is significant (tens of seconds to minutes × 6 parallel). Daily use: `/review` is sufficient.

Aggregation: confidence <80 → downgrade to Warning; same file:line with different perspectives → merge.

## Multi flow aggregation policy

| State | Handling |
|------|------|
| 3+ methods flagged | Critical confirmed |
| 2 methods flagged | Critical |
| 1 method only | Warning |
| Confidence <80 (comprehensive side) | Downgrade to Warning |

**Deduplication**: same file:line ±3 lines same-type → merge to 1 finding, annotate source method as `[plugin][codex]` etc.

`/review --plugin` standalone post feature merged into `--multi`. To use plugin alone: call `/code-review:code-review <PR>` directly.

## Review policy

- **Strict**: over-detection preferred over miss
- **Diff only**: do not flag existing code outside the change
- **Large diffs**: process 1 file at a time
- **Priority**: Critical → Warning
- **Concrete fix proposals**: finding + improvement method
- **Parallel execution**: 11 perspectives in parallel

Include: changed files (git diff), newly added. Exclude: auto-generated, vendor/node_modules, lock files.

## difit integration: comment JSON format

```json
{
  "type": "thread",
  "filePath": "src/domain/user.ts",
  "position": { "side": "new", "line": 45 },
  "body": "🔴 Critical: [design] ...\n\nFix proposal: ..."
}
```

- body prefix: Critical → `🔴 Critical:` / Warning → `🟡 Warning:`
- When line number unknown: `line: 1`
- Pass all findings as single `--comment '<JSON array>'` to `difit staged` or `difit .`
