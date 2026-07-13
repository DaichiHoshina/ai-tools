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

## 実測に基づく review mode 選択 (2026-06-20 実走、PR #48 同一 target 比較)

| 状況 | 選択 |
|---|---|
| small diff (≤5 file or ≤200 行) | `/review` 単発 1 lens |
| 中規模 doc PR (5-20 file / 200-1000 行) | `/review --verifier-panel=3` (≈214k subagent tokens) |
| 中-大 code PR (≥20 file or ≥1000 行) / 規約違反検出が重要な refactor | `/workflow review` (≈686k = 3.2x、adversarial verify が false positive 27% を提示前に discard し、直叩きの見逃し 5 件を追加で拾った) |
| cost 優先 / 1 shot | Agent 直叩き panel (token 1/3) / 再走 iteration は `/workflow review` + `resumeFromRunId` で cache |

多数決 (2/3 lens hit) が効くのは同一 root cause を複数 lens が捉える重大 logic bug のみで、doc PR では 4 finding 全て lens 単独 hit だった。doc PR は 1-2 lens で足りる。workflow 側は default subagent に reviewer rule (`review-noise-discard.md` 等) が乗らないため、prompt へ明示注入する。

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
