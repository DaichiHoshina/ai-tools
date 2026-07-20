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
- **`t.Parallel()` default**: top-level test / subtest 両方の先頭で入れる。loop で subtest を回すときは range 変数 shadow (`tc := tc`) を忘れない。共有可変 state (global var / DB fixture の直接書換 / 環境変数 / `t.Setenv`) を触る test だけ例外、理由を code comment 1 行で残す。既存 file 修正時に周辺 test が Parallel を使っていないなら合わせる (揃えるだけの drive-by 修正はしない)
- Flakiness details: `guidelines/languages/go-test-stability.md`

## Detailed Guidelines

Patterns, generics, architecture → `guidelines/languages/golang.md` (auto-load via `/load-guidelines full`)

## 失敗パターンカタログ

頻出の落とし穴 10 件の self-check table は `guidelines/languages/golang.md` §失敗パターンカタログ に移設した。実装前と review 時に参照する。
