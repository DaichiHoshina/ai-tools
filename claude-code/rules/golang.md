---
paths:
  - "**/*.go"
---
# Golang Rules

## Error Handling

- Always handle errors (no `_` ignoring)
- Add context with errors.Wrap/Wrapf
- Compare sentinel errors with errors.Is

## Naming

- Package names: lowercase single words
- Exported: PascalCase
- Unexported: camelCase
- Acronyms: all caps (HTTP, ID, URL)

## Concurrency

- Prevent goroutine leaks (use context)
- Channel creator closes channel
- Manage lifecycle with sync.WaitGroup/errgroup

## Logging

- Log **once at error origin**. If returning err, caller must not re-log
- ErrNotFound needs no log (normal case). Repository returns as-is
- UseCase layer decides if NotFound is exceptional

## Testing

- table-driven tests recommended
- Helpers call t.Helper()
- Flakiness details: `guidelines/languages/go-test-stability.md`

## Detailed Guidelines

Patterns, generics, architecture → `guidelines/languages/golang.md` (auto-load via `/load-guidelines full`)
