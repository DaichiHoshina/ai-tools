---
allowed-tools: Bash, Read, Glob, Grep, mcp__serena__*
description: Verify hook/agent changes 1-shot - syntax → unit → integration → invariants → behavior → install
argument-hint: "[scope]"
---

# /verify-once - 1-shot Final Verify

Confirm hook/agent/lib changes execute correctly. No re-verify after.

## When to Use

| Change Target | Use | Don't Use |
|---------|------|---------|
| hooks/*.sh | ✓ | |
| agents/*.md frontmatter | ✓ | |
| lib/*.sh | ✓ | |
| settings.json.template | ✓ | |
| commands/*.md prose | | ✓ (`/dev --quick` enough) |
| skills/*/skill.md prose | | ✓ |

## Flow (sequential, fail = stop)

1. **syntax**: all changed `.sh` → `bash -n`, all `.json` → `jq empty`
2. **unit**: `bats -r tests/` matched test run (filter by changed file)。exit code は `bats ... > /tmp/x.out 2>&1; echo $?` の形で直接見る — `bats | tail` 等の pipe は exit code を隠し、fail を全 pass と誤読する (d73e4e2 regression の見逃し実例)
3. **integration**: `hooks-integration.bats` etc
4. **invariants**: `agent-frontmatter.bats` (agents change only)
5. **behavior**: run changed hook with dummy JSON input, check expected output
6. **install**: `~/.claude/` sync via sync.sh → re-run behavior test (no regression)

## Output

```
1. syntax      : ✓ (3 files)
2. unit        : ✓ (12 tests)
3. integration : ✓ (39 tests)
4. invariants  : ✓ (7 tests)
5. behavior    : ✓ (hook returned expected JSON)
6. install     : ✓ (sync done, re-test PASS)

Result: VERIFIED. Re-verify not needed.
```

Fail = stop at failed step, report root cause (no band-aid).

## Notes

- **1-shot goal**: verify so thoroughly post-execution "want to re-check?" never happen. list verify angles upfront
- vs `/lint-test` (CI batch), `/verify-once` = **behavior verify** structure change specialized
- if integration test missing, first add (ADR 0001 style) before this verify

## Failure Handling

| Situation | Behavior |
|-----------|----------|
| `bash` / `jq` / `bats` missing | skip that step, note "skipped (tool)" in Result |
| integration test missing | ADR 0001 style request test first → stop |
| install post re-test fail | suggest rollback, phase split cause (syntax/unit/integration) |

Failure example:

```
1. syntax      : ✗ (1 file: hooks/foo.sh)
2. unit        : - (syntax failed, skip)
...

Result: FAILED at step 1
Root: hooks/foo.sh:42 - bash syntax error 'unexpected EOF'
```

ARGUMENTS: $ARGUMENTS
