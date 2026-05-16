# Review Criteria

## Architecture (Design)

### Critical

| Item | Description |
|------|-------------|
| Layer violation | Domain referencing Infrastructure, UseCase with framework-specific logic |
| Dependency inversion broken | Domain depends on Repository impl, missing DI |
| Bypass access | Controller → DB direct, skipping UseCase |
| Business logic in wrong layer | Logic in Controller / Infrastructure |
| Anemic domain model | Entity is getter/setter only |
| Aggregate boundary violation | Direct access outside aggregate root |

### Warning

| Item | Description |
|------|-------------|
| Over-abstraction | Unnecessary interfaces / layers |
| Fat Service | Multiple responsibilities in one Service |
| Ubiquitous language mismatch | Naming diverges from domain terminology |
| OCP-violating conditionals | switch/if for type/carrier → suggest Strategy/Specification |
| Semantic type sharing | Same type for different domain concepts (coupling risk) |

## Quality

### Critical

| Item | Description |
|------|-------------|
| Type safety | `any`, unvalidated `as`, `interface{}` |
| Performance | N+1, memory leaks |
| Outdated patterns | See lang guidelines "detect old patterns" |
| Unused DB features | Can DB-specific SQL complete filtering/transform vs app-side? |

### Warning

| Item | Description |
|------|-------------|
| Code smell | Functions >100 lines, magic numbers |
| Inefficient algorithm | Possible O(n) or O(n log n) for O(n²) |
| Unused code in diff | PR includes unused interface methods / functions |
| HTTP status mismatch | 400 for server issue, BadRequest for not found, etc |

## Readability

### Critical

| Item | Description |
|------|-------------|
| Misleading names | Name ≠ actual behavior |
| Cryptic code | Intent unclear, complex one-liners |

### Warning

| Item | Description |
|------|-------------|
| Cognitive complexity | Deep nesting (3+ levels), long conditionals |
| Naming quality | Over-abbreviated (`usr`, `tmp`), lack of symmetry |
| Function size/arity | >50 lines: split, >4 args: objectify |
| Consistency | Inconsistent naming rules / patterns within project |
| Structure clarity | Missing guard clauses, negation chains, bool flags |
| Over-engineering (YAGNI) | Unused abstractions, helpers called once |
| Redundant shared code | Caller-side branching + internal branching, always-true conditionals |

## Security

### Critical

| Item | Description |
|------|-------------|
| Injection | SQL (string concat), XSS (innerHTML), command injection |
| Auth broken | Plaintext passwords, session leaks |
| Error suppression | Empty catch, ignored errors |
| Secret leaks | password/token/secret in logs |

### Warning

| Item | Description |
|------|-------------|
| Missing headers | CSP, HSTS, X-Frame-Options |
| No rate limit | Public API missing throttling |

## Docs & Testing

### Critical

| Item | Description |
|------|-------------|
| Missing public API docs | Exported types / functions undocumented |
| False comments | Comments diverge from implementation |
| No real assertion | `expect(user).toBeDefined()` only |
| Over-mocking | All mocks, no actual behavior verified |

### Warning

| Item | Description |
|------|-------------|
| Test isolation | Shared state, execution order dependency |
| Coverage gaps | Missing error/boundary case tests |
| Verbose test code | Excessive setup, over-dependency on implementation details |

## Root Cause (Permanent fix)

### Critical

| Item | Description |
|------|-------------|
| Symptomatic fix | Hiding with null checks / try-catch / conditionals |
| Error suppression | Ignoring errors (empty catch, `_ = err`) |
| Same pattern recurs | Issue exists elsewhere in codebase |

### Warning

| Item | Description |
|------|-------------|
| Local-only fix | Fixing 1 spot but pattern exists 3+ places |
| Structural conflict | Fix contradicts existing design patterns |
| Cause unexplained | Can't explain why fix works |

## Logging

See CLAUDE.md "logging design criteria" for details.

### Critical

| Item | Description |
|------|-------------|
| Secret in logs | password/token/Cookie/PII/full request body |
| Missing error context | No error object / stacktrace in logs |
| Unstructured logs | String concatenation (`"user " + id`) |
| Unreachable path wrong level | switch default, unhandled enum as warn/info |

### Warning

| Item | Description |
|------|-------------|
| Wrong log level | warn/error for success, info for errors |
| Rare event as info | Low-probability fallback downgraded to info |
| Missing fields | request_id/trace_id, event, duration_ms |
| NotFound confusion | 0 results as warn, ID lookup not found silent |
| Over-logging | Logs in loops / N+1 queries |
