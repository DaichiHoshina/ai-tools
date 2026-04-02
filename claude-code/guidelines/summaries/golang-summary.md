# Go ガイドライン（サマリー版）

## バージョン: Go 1.26（ジェネリクス: 1.18+）

## 基本原則: シンプル・明示的・標準ライブラリ優先

## 型安全性

| NG | OK |
|----|----|
| `func Process(data interface{}) {}` | `func Process[T any](data T) {}` |

## エラーハンドリング: `if err != nil { return fmt.Errorf("context: %w", err) }`

## 命名規則

| 種類 | 規則 | 例 |
|------|------|-----|
| パッケージ | 小文字・短く | `http`, `json` |
| エクスポート | 大文字開始 | `ReadFile` |
| インターフェース | -er接尾辞 | `Reader`, `Writer` |

## 古いパターン検出

### 必ず指摘

| 古い | モダン | Since |
|------|--------|-------|
| `ioutil.ReadAll` 等 | `io.ReadAll`, `os.ReadFile` | 1.16 |
| `interface{}` | `any` | 1.18 |

### 積極的に指摘

| 古い | モダン | Since |
|------|--------|-------|
| `sort.Slice` / `sort.Ints` | `slices.Sort` / `slices.SortFunc` | 1.21 |
| 手動スライス検索 | `slices.Contains` | 1.21 |
| 自前 `min`/`max` | ビルトイン `min()`/`max()` | 1.21 |
| `log.Printf` | `slog.Info`（構造化ログ） | 1.21 |
| `for i := 0; i < n; i++` | `for i := range n` | 1.22 |
| ループ変数 `v := v` | 不要（イテレーション毎スコープ） | 1.22 |
| `for i := 0; i < b.N; i++` | `for b.Loop()` | 1.24 |
| - | `go fix ./...`（自動修正） | 1.26 |
