# Compounding Engineering Cycle

> Boris-style Compounding Engineering. Structurally fix recurring review findings to eliminate them permanently.

## Core Proposition

**"Same-location finding occurring N=3 consecutive commits = structural problem signal. Fix structurally via config (CLAUDE.md / skill / hook)."**

Manual fixes repeat the same mistake N times. One structural fix (hook, etc.) drops the count to 0 permanently. Investment 1, return N — compound relationship.

## Cycle: 4 Steps

### Step 1: Detect

Extract same file:line±3 + same focus findings from past review history (`.claude/review-history.jsonl` or commit series). Threshold:

| N | Judgment |
|---|----------|
| 1 | One-off, fix only |
| 2 | Watch, consider structural fix |
| 3+ | **Structural problem confirmed**, root-cause target |

`comprehensive-review` skill Step 0 auto-runs history cross-check. 3+ occurrences are highlighted as `🔁 Recurring finding (Nth time)`.

### Step 2: Structural Problem Assessment

Determine if the recurrence is structural:

| Signal | Structural problem likelihood |
|--------|------------------------------|
| Same location + same focus 3× | High |
| Same focus, different locations, frequent | Medium (guideline-side issue) |
| Same location, different focus | Low (location-specific) |

If structural → Step 3. Otherwise → standard fix.

### Step 3: Root-Cause Strategy (priority order)

| Priority | Strategy | Example |
|----------|----------|---------|
| 1 | **Hook auto-detection** | Writing self-check hook (pre-commit), PostToolUse format |
| 2 | **Skill rule addition** | Add NG examples to `comprehensive-review` writing perspective table |
| 3 | **CLAUDE.md / guidelines addition** | Document "X is prohibited" / "X is required" |
| 4 | **Auto-memory save** | Save successful pattern for reproduction |

Hook is highest priority: zero cognitive load for user/Claude, detects before commit. Skill / CLAUDE.md have load cost + interpretation variance.

**CLAUDE.md 自己約束の hook 昇格基準**: 「〜を避ける」型の自己約束を CLAUDE.md に足しても、1 週間 (または同種 block ≥50 件/週) で効果が出なければ user-prompt-submit の additionalContext inject (`_inject_*_if_trigger` パターン) に昇格する。自己 restraint は反復タスクで破綻し、pre-tool-use の後段 block は retry loop で token と makespan を浪費する。生成前の文脈に置くのが構造解 (実例: commit-ng-pre-sweep `d921fc0`、追記当日 603 件 block → inject 化)。list は log / canonical file から動的抽出し literal 直書きしない。

### Step 4: Measure Effectiveness

Verify same-type findings don't recur after fix:

- Short-term: Did hit count decrease in next 1-2 commits?
- Mid-term: Zero same-location findings for 1 week?
- Long-term: Same-type mistakes reduced in other files too (generalization)?

## Example (2026-04-29)

| commit | Phase | Finding | Response |
|--------|-------|---------|----------|
| `427733a` series | Detect | "最優先" evaluation word without evidence, 3 consecutive commits | Structural problem confirmed |
| `04503f5` | Root-cause | Added writing self-check to post-tool-use hook | Pre-commit detection via hook |
| `71f690f` | Reinforce | Consolidated NG dictionary SoT to `lib/writing-self-check.sh` | Prevented three-way drift |
| `a2bc297`–`61b27ef` | Measure + improve | Dogfood: hits 36→24 (33% reduction), 4 exclusions for false positive suppression | Productionized |

**Result**: Same-location "最優先" finding = 0 since `04503f5`. Investment 4 commits / return N (ongoing).

## Reproduction Steps

On discovering a new recurring finding:

1. Check history in `.claude/review-history.jsonl`; apply this cycle if 3+ occurrences
2. Plan implementation via priority order (hook → skill → guidelines → memory)
3. Design with `/plan`, optionally run through codex review
4. Implement → add unit tests → dogfood measurement → commit
5. Save to auto-memory as success pattern (reference for next similar problem)

## Case Studies

### awk regex bug immediate fix (2026-04-30)

While implementing context-aware logic in PR #12, broken awk regex parentheses caused over-exclusion of `例:` / `詳細:` / `参考:` single occurrences as false negatives. reviewer-agent detected with 3 evidence cases; 1-line regex fix + 3 bats negative cases added, root-cause in under 5 minutes. Short lead time from Critical detection to fix worked as compounding effect.

### Pass-by-coincidence test structural fix (2026-04-30)

In PR #11, 3 of 6 bats tests reconstructed behavior manually (mkdir/cp/ln) without calling the actual function — tests passed even with the implementation fully deleted. Rewrote 17 tests to fix. Established standard bats patterns:

- Call real functions with `run bash -c "source <lib> && <function> <args>"`
- Save PATH in `setup` as `ORIG_PATH="$PATH"`, restore in `teardown` with `export PATH="$ORIG_PATH"` (never `unset PATH`)
- Don't suppress status with `|| true`
- Prohibit two-outcome asserts (`status -eq 0 || status -eq 1`)

## Memory write target

Write only to Claude Code auto-memory (`~/.claude/projects/.../memory/`). Writing to Serena `.serena/memories/` is forbidden to avoid dual management (decided 2026-06-10).

## Related

- `claude-code/CLAUDE.global.md` §Compounding Engineering — core rule
- `claude-code/lib/writing-self-check.sh` — implementation SoT
- `claude-code/skills/comprehensive-review/SKILL.md` — `🔁 recurring finding` detection logic
- `claude-code/references/memory-usage.md` §Recording targets — success pattern storage
- Reference: [howborisusesclaudecode.com](https://howborisusesclaudecode.com/)
