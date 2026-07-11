# Go Test Stability Guidelines

> **Purpose**: Patterns to prevent flaky tests.

## Dynamic Data Validation

```go
// ❌ Bad: auto-generated IDを期待値に含める
assert.Equal(t, entity.Order{Id: 1, BuyerId: 101}, actual)
// ✅ Good: 動的フィールドは個別検証
assert.Greater(t, actual.Id, 0); assert.Equal(t, 101, actual.BuyerId)
```

## Parallel Safety for Shared Data

```go
// ❌ Bad: 並列テストで共有スライスをsort → race condition
// ✅ Good: deep copyしてから操作
cp := make([]map[string]any, len(tt.expected))
copy(cp, tt.expected)
sort.Slice(cp, ...) // Safe
```

## Test Types and Build Tags

| Type | Target | DB | Build tag |
|------|--------|----|-----------|
| Unit Test | pure functions without DB access | not needed | `parallel` |
| Repository Test | Repository layer CRUD | real DB | `serial` |
| Usecase Test | business logic | gomock | `parallel` |
| Integration Test | full API (HTTP response) | real DB | `integration` |

## Test Rules

| Rule | Detail |
|------|--------|
| Table-driven tests | `map[string]struct{}` required |
| Parallelization | `t.Parallel()` required (except Repository Test) |
| Struct comparison | use `go-cmp` |
| Test data | Repository Test uses `testfixtures` (YAML) |
| Mocks | Usecase Test uses `gomock` |

## Log-only Branch Testing

グローバル `var logger *zap.Logger` パターン (`Setup()` 経由で初期化) は、テスト差し替えフックがないと log 出力内容をアサートできない。log-only な分岐 (抑制条件 / 重複排除 / rate limit) の PR では以下の落とし所を採る。

- 判定軸: setter フックの有無 / `zaptest` `zap/zaptest/observer` の使用例が codebase に 0 件なら観測フック未整備
- log 分岐そのものはテストしない。PR body に「log-only 分岐なのでユニットテスト対象外」と明記する
- 代わりに、その分岐に入ったときの他の副作用 (metric / return 値 / DB 状態) で挙動を担保する
- observer 注入フックの新設は scope 超過 + over-edit 指摘対象になりやすい。「logger テストフック整備 + 該当分岐テスト追加」を follow-up issue に切り出す

## Flaky Test Prevention Checklist

- [ ] No auto-generated IDs (DB auto_increment etc.) in expected values
- [ ] DB foreign key errors handled appropriately
- [ ] Shared data deep-copied in parallel tests
- [ ] Test fixtures standardized and unified
- [ ] Time-dependent tests use `clock` interface
- [ ] Test DB data initialized for each test
