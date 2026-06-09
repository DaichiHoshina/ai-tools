# Golang Guidelines

Go 1.26.4 (2026-06-04時点). Common: `~/.claude/guidelines/common/`.
Related: `languages/go-performance.md` (escape/GC/pprof/PGO) / `languages/go-concurrency.md` (scheduler/channel sizing/leak detection).

## Core Principles

- Simplicity beats complexity
- Official tools REQUIRED: `gofmt`, `goimports`
- Prefer official idioms; custom patterns FORBIDDEN
- Accept interfaces, return structs
- Exported names MUST have comments

## Directory Structure

`domain/` (entities, value objects) / `usecase/` / `interface/` (controllers, presenters) / `infrastructure/` (DB, external APIs).

## Type Definitions

### Generics (1.18+)

`func Map[T, R any](slice []T, fn func(T) R) []R`. Generic Type Aliases (1.24): `type Pair[T any] = struct{ A, B T }`.

### Struct Design

- Fields: lowercase (unexported) by default
- Prefer behavior methods over getters/setters
- Embedding: "is-a" only
- Semantic type separation: different meanings require different types even if structurally identical

### Semantic Type Separation (copy-paste sharing FORBIDDEN)

| Criterion | Same type OK | Separate types |
|-----------|-------------|----------------|
| Lifecycle | Always changed/deleted together | One may change/delete independently |
| Naming | Common concept name is natural | Common name blurs meaning |
| Evolution | Fields guaranteed to stay aligned | One side may gain/lose fields |

Rule: "Would a change/deletion affect an unrelated feature?" → Yes = separate. Use generic names for shared types (e.g. `PaginationParams`, `DateRangeFilter`). FORBIDDEN: reusing feature-specific types in other features.

## Naming Conventions

- Packages: lowercase, singular, short (`user`)
- Interfaces: verb + er (`Reader`)
- Constructors: `New` + type name

## Quick Reference

### Error Handling

| Pattern | Code | Use |
|---------|------|-----|
| Basic | `if err != nil { return err }` | Propagation |
| Wrap | `fmt.Errorf("msg: %w", err)` | Add context (1.13+) |
| Check | `errors.Is(err, ErrNotFound)` | Type check |
| Sentinel | `var ErrNotFound = errors.New("not found")` | Constant error |

### Concurrency

| Pattern | Code | Use |
|---------|------|-----|
| goroutine | `go func() { ... }()` | Concurrent execution |
| context | `ctx, cancel := context.WithTimeout(ctx, 5*time.Second)` | Cancellation |
| channel | `ch := make(chan T, bufSize)` | Data passing |
| Mutex | `defer mu.Unlock()` | Mutual exclusion |
| WaitGroup | `wg.Wait()` | Wait for completion |

### Testing

| Pattern | Code | Use |
|---------|------|-----|
| Basic | `func TestXxx(t *testing.T)` | Unit |
| Table-driven | `tests := map[string]struct{...}` | Multiple cases |
| Benchmark | `for b.Loop() { ... }` | Performance (1.24+) |
| Concurrent | `testing/synctest` | Concurrent code (1.25+) |

## Common Mistakes

| FORBIDDEN | USE | Reason |
|-----------|-----|--------|
| `result, _ := db.Query()` | Check errors | Ignoring errors FORBIDDEN |
| `go doWork()` (unbounded) | `ctx` + `WaitGroup` | Resource management, leak prevention |
| `panic()` for normal errors | `return err` | Standard practice |
| Reuse existing type for new purpose | Define type per purpose | Semantic type separation |
| Mutate fields directly in usecase | `model.SetXxx()` | Centralize mutation logic |
| Input struct with no parameters | Use no-arg instead | Avoid unnecessary types |
| `SELECT *` | Explicit columns only | Performance and safety |
| Return 400 for server inconsistency | 500 (400 = client-caused only) | HTTP status semantics |

## Deprecated Pattern Detection

Check `go.mod` `go` directive for target version before flagging.

### Critical (always flag)

| DEPRECATED | MODERN | Since |
|-----------|--------|-------|
| `ioutil.ReadAll` | `io.ReadAll` | 1.16 |
| `ioutil.ReadFile`/`WriteFile` | `os.ReadFile`/`os.WriteFile` | 1.16 |
| `ioutil.ReadDir` | `os.ReadDir` | 1.16 |
| `ioutil.TempDir`/`TempFile` | `os.MkdirTemp`/`os.CreateTemp` | 1.16 |
| `ioutil.NopCloser`/`Discard` | `io.NopCloser`/`io.Discard` | 1.16 |
| `interface{}` | `any` (or generics) | 1.18 |

### Warning (proactively flag)

| DEPRECATED | MODERN | Since |
|-----------|--------|-------|
| `sort.Slice`/`sort.Ints`/`sort.Strings` | `slices.Sort`/`slices.SortFunc` | 1.21 |
| Manual slice copy | `slices.Clone(src)` | 1.21 |
| Manual slice search | `slices.Contains(s, v)` | 1.21 |
| Manual map copy | `maps.Copy(dst, src)` | 1.21 |
| Custom `min`/`max` functions | Built-in `min()`/`max()` | 1.21 |
| `log.Printf` (unstructured) | `slog.Info` etc. | 1.21 |
| `for i := 0; i < n; i++` | `for i := range n` | 1.22 |
| Loop variable `v := v` shadow | Not needed (per-iteration scope) | 1.22 |
| Return `[]T` | `iter.Seq[T]` | 1.23 |
| `for i := 0; i < b.N; i++` | `for b.Loop()` | 1.24 |

### Info

- `go fix ./...` auto-fixes many patterns; RECOMMENDED for bulk detections (1.26)
- `new(T, val)` new with initial value (1.26)

## Best Practices

`defer` for resource cleanup / early return to reduce nesting / concrete types or generics over `any` / nil-check thoroughly.

## Testing Details

### Build Tags

| Tag | `t.Parallel()` | DB/Fixtures | Use |
|-----|----------------|-------------|-----|
| `parallel` | REQUIRED | FORBIDDEN (use mock) | Unit |
| `serial` | FORBIDDEN | Allowed | Repository impl |
| `integration` | FORBIDDEN | Allowed | Full-stack |

### Table-Driven / Flaky Test Prevention

- Use **map** not slice (forces subtest names, randomizes order for isolation)
- Assertions: `cmp.Diff(expected, actual)`
- Names: underscore-separated (`TestXxx_returns_error`)
- Auto-generated IDs: check existence only, not exact value
- Parallel tests: do not mutate shared data (deep copy before operation)
- `parallel` tag: `t.Parallel()` REQUIRED on both top-level and subtests

## Database

### Naming

| Element | Pattern | Example |
|---------|---------|---------|
| Table/Column | snake_case | `user_orders`, `created_at` |
| Index | `idx_table_column` | `idx_users_email` |
| FK | `fkey_table_column` | `fkey_orders_user_id` |
| Unique | `ukey_table_column` | `ukey_users_email` |

### Query Rules

- Placeholders: named (`:var_name`) only; `?` FORBIDDEN
- Always use `WithContext(ctx)`
- BETWEEN FORBIDDEN for datetime (use `>=` and `<`)
- INSERT/UPDATE via ORM Insert/Update; raw SQL FORBIDDEN
- Table alias `AS` FORBIDDEN (except self-join)
- `SELECT *` FORBIDDEN
- Raw SQL bulk INSERT exception: `LastInsertId() + i` numbering limited to simple inserts only (FORBIDDEN: `INSERT...SELECT` / `ON DUPLICATE KEY UPDATE` / mixed / dynamic row count / migration backfill). Details: [backend/mysql-performance.md §12](../backend/mysql-performance.md)

## Entity / Nullable

| Layer | Recommended | FORBIDDEN |
|-------|-------------|-----------|
| Entity (DB mapping) | `sql.Null[T]` (1.22+) | `sql.NullInt64` etc., `*T` |
| Domain/Service | Custom `Nullable[T]` | `*T` (semantic distinction) |
| Handler/Adapter | `*T` | `Nullable[T]` (Swagger compatibility) |

Value access: `.V` field or after `.Valid` check.

## API Design

- URLs: no trailing slash (`/users/123` OK, `/users/123/` FORBIDDEN)
- JSON keys: lowerCamelCase, hyphens FORBIDDEN
- Empty arrays: return `[]` (`null` FORBIDDEN)
- `omitempty` tag FORBIDDEN (prevents client parse issues)
- Timezone: DB/API in UTC, convert to local time on display

## Migrations

- Editing existing files FORBIDDEN (causes inconsistency in applied environments)
- Schema changes always in new files (`ALTER TABLE`)
- Both up/down files REQUIRED
- Assign numbers after checking latest on main (re-check before merge)
- `MODIFY COLUMN` in down migration: explicit `DEFAULT` clause REQUIRED

## Security

- Random: `crypto/rand` (`math/rand` FORBIDDEN)
- Secret comparison: `subtle.ConstantTimeCompare` (`==` FORBIDDEN — timing attack)
- Minimum 32 bytes generated
- Auth: validate session/token first; get user ID from session/token (request parameters FORBIDDEN)

## CQRS

- Separate layers for Command (write) and Query (read)
- Command: transaction management via Unit of Work pattern
- Command usecase signature: `Do(ctx, in *Input) (*Output, *Result)` (`*Result` = operation success/failure, replaces `error`)
- Mock generation: `go generate` (manual FORBIDDEN)
