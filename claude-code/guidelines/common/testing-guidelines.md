# Testing Guidelines

> **Purpose**: Basic principles of test design for early bug detection, safe refactoring, etc. Reference when adding tests or reviewing existing ones.

## Core Principles

| Principle | Description | Code Example |
|-----------|-------------|--------------|
| Early bug detection | Detect code problems early | `expect(fn).toThrow(ValidationError)` |
| Refactoring safety | Confirm changes don't break existing features | `beforeEach(() => resetDB())` |
| Documentation | Test code serves as a specification | `it('should handle 404 errors', ...)` |
| Design improvement | Testable code is an indicator of good design | `createUser(deps) // DI` |

## Quick Reference

### Test Types

| Type | Target | Characteristics | Test Pyramid |
|------|--------|-----------------|--------------|
| Unit test | Function/method | Fast, independent, no external deps | Many (base) |
| Integration test | Multi-module interaction | Uses DB/external API | Medium |
| E2E test | Entire system | Slowest, most fragile | Few (top) |

### AAA Pattern

| Phase | Description | Example |
|-------|-------------|---------|
| Arrange | Prepare test data and mocks | `const user = { id: 1 }` |
| Act | Execute the test target | `const result = getUser(1)` |
| Assert | Verify the result | `expect(result).toBe(user)` |

### Naming Conventions

| Pattern | Format | Example |
|---------|--------|---------|
| should-style | `should + expected behavior` | `should return user when valid ID` |
| target-condition-result | `[target] + [condition] + [result]` | `createUser with invalid email throws error` |
| Japanese | Natural language | `有効なIDでユーザーを取得できる` |

**Important**: Name should make it immediately clear what is being tested and the expected behavior.

## Best Practices

| Principle | Description |
|-----------|-------------|
| Independence | Do not share state between tests |
| Fast | Mock external dependencies |
| Deterministic | Same input always produces same result |
| Simple | One behavior per test |
| Test behavior | Test public API, not internal implementation |

## Mocks and Stubs

| Rule | Description |
|------|-------------|
| Mock external dependencies | DB, external APIs, filesystem |
| Do not mock internal logic | Do not depend on implementation internals |

## Common Mistakes

| Avoid | Use | Reason |
|-------|-----|--------|
| Depend on internal implementation (private fields) | Verify via public API | Resilient to implementation changes |
| Use real DB | Mock or in-memory DB | Speed and independence |
| Share state between tests | Initialize in each test | Independence and determinism |
| Verify multiple behaviors in one test | One behavior per test | Easier to locate failures |

## Test Coverage

| Item | Standard | Example Command |
|------|----------|----------------|
| Target | ≥80% | `npm test -- --coverage` |
| Important | Coverage is a means, not an end | — |
| Priority | Business logic > infrastructure layer | — |

**Go example**:
```bash
go test -coverprofile=coverage.out ./...
go tool cover -func=coverage.out
```

**TypeScript example**:
```bash
npm test -- --coverage
# check coverage/lcov-report/index.html
```

## Language-specific Tools

| Language/FW | Test Tool | Characteristics |
|-------------|-----------|-----------------|
| Go | `testing` (stdlib) | Table-driven tests recommended |
| TypeScript | Vitest, Jest | Fast, type-safe |
| React | Testing Library | User-perspective testing |
| E2E | Playwright | Cross-browser support |

### Go: Table-driven Tests

Go details (`map[string]struct{}` required / parallelization / go-cmp): see `guidelines/languages/golang.md` / `guidelines/languages/go-test-stability.md`.
