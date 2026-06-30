---
allowed-tools: Read, Glob, Grep, Edit, MultiEdit, Write, Bash, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*, mcp__context7__*
argument-hint: "<target-file-or-symbol>"
description: Test creation mode - write tests for existing code
---

## /test - Test Creation Mode

## protection-mode

Auto-apply via `/flow`. Single run: recommend `/protection-mode` if changing files.

## Step 0: Auto-load Guidelines (required)

Load required guidelines before test:

### A. Common Guidelines (required)
```
requires-guidelines:
  - common/testing-guidelines.md
```

**Load from:**
- `~/.claude/guidelines/common/testing-guidelines.md` - testing principles, patterns

### B. Language Guidelines
Auto-detect via `load-guidelines`:
- TypeScript → `typescript.md` (test types)
- Go → `golang.md` (table-driven tests)
- Next.js → `nextjs-react.md` (React Testing Library)

### C. Skill Coordination
Auto-load:
- `comprehensive-review --focus=docs` - test/doc quality (Phase 2-5 built-in, legacy names work)
- `comprehensive-review --focus=quality` - test type safety/structure quality (Phase 2-5 built-in, legacy names work)

**Auto-review after:**
Post-creation, auto-run `comprehensive-review --focus=docs` Skill:
- test meaning check
- coverage analysis
- mock appropriateness
- testability eval

## Flow

1. **Load guidelines** - execute Step 0
2. **Analyze target** - Serena MCP: function sig, dependencies, edge cases
3. **Design test** - normal path, error path, boundaries, edge cases
4. **Implement** - AAA pattern (Arrange-Act-Assert)
5. **Quality review** - auto-run `test-quality-review` Skill
6. **Run & report** - show coverage

## AAA Pattern (required)

```typescript
test('should do something', () => {
  // Arrange
  const input = createTestData();
  // Act
  const result = targetFunction(input);
  // Assert
  expect(result).toBe(expected);
});
```

## Coverage Target

- minimum: 70% / recommended: 80% / ideal: 90%+

## Next Steps

```
/test complete
  → /review (code review)
  → /git-push (git ops)
  → test fail: /diagnose
  → coverage gap: add more tests
```

## --tdd Mode (Test-Driven Development)

`/test --tdd` enforce TDD cycle:

```
RED (write failing test) → GREEN (min implementation) → REFACTOR (improve) → repeat
```

- test-first enforced: no impl code before test
- min impl: only code to pass test
- post-complete: `/lint-test` for end-to-end check

## Related Commands

| Command | Relation |
|---------|------|
| `/dev` | implement then write test |
| `/lint-test` | CI equivalent. includes test run |

## Failure Handling

| Situation | Behavior |
|-----------|----------|
| test framework not detected (no package.json/go.mod etc) | ask user for framework → stop |
| coverage < 70% | show gap analysis, user decide continue/stop |
| Serena MCP fail | use grep/Read for func sig, lower edge-case detection precision, warn |
| existing test damage detected (impl change side-effect) | stop immediately, ask user for fix |

Use Serena MCP for code analysis. Mocks minimal.
