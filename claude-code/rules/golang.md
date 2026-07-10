---
paths:
  - "**/*.go"
---
# Golang Rules

## Error Handling

詳細: `guidelines/languages/golang.md` §Quick Reference 参照。

## Naming

- Package names: lowercase single words
- Exported: PascalCase
- Unexported: camelCase
- Acronyms: all caps (HTTP, ID, URL)

## Concurrency

詳細: `guidelines/languages/golang.md` §Quick Reference 参照。

## Logging

詳細: `guidelines/languages/golang.md` §Quick Reference 参照。ErrNotFound は log 不要 (Repository は as-is 返却、UseCase 層で判定) の絶対禁止事項のみ本 rule で強制する。

## Testing

- table-driven tests recommended
- Helpers call t.Helper()
- Flakiness details: `guidelines/languages/go-test-stability.md`

## Detailed Guidelines

Patterns, generics, architecture → `guidelines/languages/golang.md` (auto-load via `/load-guidelines full`)

## 失敗パターンカタログ

頻出の落とし穴 10 件の self-check table は `guidelines/languages/golang.md` §失敗パターンカタログ に移設した。実装前と review 時に参照する。
