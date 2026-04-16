# Go テスト安定性ガイドライン

Flakyテスト防止のためのパターン集。

## 動的データの検証

```go
// Bad -- auto-generated IDを期待値に含める
expected := entity.Order{Id: 1, BuyerId: 101}
assert.Equal(t, expected, actual)

// Good -- 動的フィールドは個別検証
assert.Greater(t, actual.Id, 0)
assert.Equal(t, 101, actual.BuyerId)
```

## 共有データの並列安全性

```go
// Bad -- 並列テストで共有データを変更
expectedOrders := []map[string]any{...}
for name, tt := range tests {
    t.Run(name, func(t *testing.T) {
        t.Parallel()
        sort.Slice(expectedOrders, ...) // Race condition
    })
}

// Good -- deep copyで安全に
for name, tt := range tests {
    t.Run(name, func(t *testing.T) {
        t.Parallel()
        cp := make([]map[string]any, len(tt.expected))
        copy(cp, tt.expected)
        sort.Slice(cp, ...) // Safe
    })
}
```

## テスト種別とビルドタグ

| 種別 | 対象 | DB | ビルドタグ例 |
|------|------|----|------------|
| Unit Test | DBアクセスなしの純粋関数 | 不要 | `parallel` |
| Repository Test | Repository層のCRUD | 実DB | `serial` |
| Usecase Test | ビジネスロジック | gomock | `parallel` |
| Integration Test | API全体（HTTP-レスポンス） | 実DB | `integration` |

## テスト規約

| ルール | 詳細 |
|--------|------|
| テーブル駆動テスト | `map[string]struct{}` 必須 |
| 並列化 | `t.Parallel()` 必須（Repository Testは除く） |
| 構造体比較 | `go-cmp` を使用 |
| テストデータ | Repository Testは `testfixtures`（YAML） |
| モック | Usecase Testは `gomock` |

## Flakyテスト防止チェックリスト

- [ ] auto-generated ID（DB auto_increment等）を期待値に含めていないか
- [ ] DB外部キーエラーを適切にハンドリングしているか
- [ ] 並列テストで共有データをdeep copyしているか
- [ ] テストフィクスチャが標準化・統一されているか
- [ ] 時刻依存のテストに `clock` インターフェースを使っているか
- [ ] テストDBのデータを各テストで初期化しているか
