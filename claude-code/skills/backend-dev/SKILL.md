---
allowed-tools: Read, Glob, Grep, Bash, Edit, Write, MultiEdit
name: backend-dev
description: Backend dev (Go/TS/Python/Rust). Auto-detect lang. Use for backend impl.
requires-guidelines:
  - common
  - clean-architecture
  - ddd
  - golang
  - typescript
  - python
  - rust
parameters:
  lang:
    type: enum
    values: [auto, go, typescript, python, rust]
    default: auto
    description: "Programming language (auto: detect from file extensions)"
---

# backend-dev

Multi-language backend skill. Use `--lang` to specify (default: auto-detect from file extensions).

## Auto-detection (lang=auto)

| Case | Behavior |
|------|----------|
| Single language detected | Apply that language's conventions |
| Multiple languages | Primary: lang with most changes, others: Critical only |
| No extension match (.md / config files) | Apply common + clean-architecture + ddd only, skip lang-specific |
| Zero files detected | Infer from `go.mod` / `package.json` / `pyproject.toml` / `Cargo.toml`. Absent: request explicit `--lang` |

## External resources

| Resource | When | On failure |
|----------|------|-----------|
| Context7 | Verify lang spec (deprecated API / new features) | Skip, use knowledge cutoff, warn |
| Serena memory | Confirm project conventions (session start) | Skip, warn, use guideline defaults |

## Common best practices

### Critical (all languages)

| Category | Rule |
|----------|------|
| Error handling | Don't ignore errors. Provide clear messages. Type-safe error handling |
| Security | Parameterized queries required. No secrets in logs. Proper auth/authz |
| Testing | Unit tests for happy & sad paths. Use mocks appropriately |

### Warning (all languages)

| Category | Rule |
|----------|------|
| Performance | Avoid N+1 queries. Prevent unnecessary allocations. Avoid inefficient algorithms |
| Maintainability | One responsibility per function. Const-ify magic numbers |

## Language-specific rules

### Go

| Severity | Rule |
|----------|------|
| Critical | Always handle errors with `if err != nil`. Don't suppress with `_` |
| Critical | Prevent goroutine leaks: control cancellation via `context.Context` |
| Critical | Accept interfaces, return structs (define interfaces only where needed) |
| Warning | Pass `context.Context` to all external calls |
| Warning | Use table-driven tests |

### TypeScript

| Severity | Rule |
|----------|------|
| Critical | Forbid `any`. Strict types (Branded Types recommended) |
| Critical | Use Result pattern (`{ ok: true; value: T } \| { ok: false; error: E }`) |
| Critical | Forbid non-null assertions (`!`). Explicit null checks |
| Warning | Leverage dependency injection (constructor injection) |

### Python

| Severity | Rule |
|----------|------|
| Critical | Type hints on all functions |
| Critical | Forbid `except Exception`. Catch specific exceptions |
| Warning | Define data models with `@dataclass` |

### Rust

| Severity | Rule |
|----------|------|
| Critical | Use `Result<T, E>` for error handling. Leverage `?` operator |
| Critical | Explicit ownership & borrowing. Avoid unnecessary `clone()` |

## Checklist

- [ ] All errors handled appropriately (type-safe error handling)
- [ ] SQL injection protected (parameterized queries)
- [ ] No secrets in logs
- [ ] Unit tests for happy & sad paths
- [ ] No N+1 queries
- [ ] Proper concurrency use & no memory leaks

## Resources

- **Context7**: Lang-specific docs (see "External resources" table above)
- **Serena memory**: Project conventions & patterns (see "External resources" table above)
