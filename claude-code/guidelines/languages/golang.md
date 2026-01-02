# Golang ガイドライン

Go 1.25対応（2025年8月リリース）。共通ガイドラインは `~/.claude/guidelines/common/` 参照。

---

## 基本原則

- **Simplicity beats complexity**: シンプルさを最優先
- **公式ツール必須**: `gofmt`, `goimports`
- **公式 idiom 優先**: 独自パターン禁止
- **Accept interfaces, return structs**
- **ドキュメント**: exported names にコメント必須

---

## ディレクトリ構成

- `domain/` - エンティティ、値オブジェクト
- `usecase/` - ユースケース
- `interface/` - コントローラー、プレゼンター
- `infrastructure/` - DB、外部API

---

## 型定義

### ジェネリクス（1.18+）
- `func Map[T, R any](slice []T, fn func(T) R) []R`
- **Generic Type Aliases（1.24）**: `type Pair[T any] = struct{ A, B T }`

### 構造体設計
- フィールド: 小文字開始（非公開）デフォルト
- getter/setter より振る舞いメソッド優先
- 埋め込み: 「is-a」のみ

---

## 命名規則

- **パッケージ**: 小文字、単数形、短く（`user`）
- **インターフェース**: 動詞+er（`Reader`）
- **コンストラクタ**: `New` + 型名

---

## クイックリファレンス

### エラー処理

| パターン | コード | 用途 |
|---------|--------|------|
| 基本 | `if err != nil { return err }` | エラー伝播 |
| ラップ | `fmt.Errorf("msg: %w", err)` | コンテキスト追加 (1.13+) |
| 判定 | `errors.Is(err, ErrNotFound)` | エラー種別確認 |
| Sentinel | `var ErrNotFound = errors.New("not found")` | 定数エラー定義 |

### 並行処理

| パターン | コード | 用途 |
|---------|--------|------|
| goroutine | `go func() { ... }()` | 並行実行 |
| context | `ctx, cancel := context.WithTimeout(ctx, 5*time.Second)` | キャンセル制御 |
| channel | `ch := make(chan T, bufSize)` | データ受け渡し |
| Mutex | `defer mu.Unlock()` | 排他制御 |
| WaitGroup | `wg.Wait()` | 完了待機 |

### テスト

| パターン | コード | 用途 |
|---------|--------|------|
| 基本 | `func TestXxx(t *testing.T)` | ユニットテスト |
| テーブル駆動 | `tests := []struct{name string; ...}` | 複数ケース |
| ベンチマーク | `for b.Loop() { ... }` | 性能測定 (1.24+) |
| 並行テスト | `testing/synctest` | 並行コード (1.25+) |

## よくあるミス

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| `result, _ := db.Query()` | `result, err := ...; if err != nil { return err }` | エラー無視禁止 |
| `go doWork()` (無制限) | `ctx` + `WaitGroup` でリーク防止 | リソース管理 |
| `interface{}` | `[T any]` (1.18+) | 型安全性 |
| `for i := 0; i < b.N; i++` | `for b.Loop()` (1.24+) | ベンチマーク最適化 |
| `panic()` で通常エラー | `return err` | エラー処理の原則 |



---

## バージョン別新機能

**1.25 (2025/08)**:
- `testing/synctest` - 並行コードテスト（仮想時間）
- JSON v2 (experimental) - パフォーマンス向上
- Green Tea GC - GC 10-40%削減
- Flight Recorder - 軽量トレース
- Core Types削除 - 仕様簡略化
- `unique` パッケージ改善

**1.24**:
- `for b.Loop()` - ベンチマーク高速化
- Generic Type Aliases
- Tool Dependencies - `go.mod`で実行ファイル管理

**1.21**:
- `slog` - 構造化ログ
- `min()`, `max()`, `clear()`

**1.18**:
- ジェネリクス - `[T any]`

---

## Go 1.26 予定機能（2026年2月リリース予定）

| 機能 | 説明 | コード例 |
|------|------|---------|
| **new関数拡張** | 初期値指定可能に | `p := new(int, 42)` |
| **Green Tea GCデフォルト化** | 小オブジェクト性能向上<br>CPU並列性・局所性改善 | 設定不要（自動有効） |
| **go fix改善** | analysis framework使用<br>診断+修正提案を統合 | `go fix ./...` |

### 参考リンク
- [Go 1.26 Release Notes](https://go.dev/doc/go1.26)
- [Release History](https://go.dev/doc/devel/release)

---

## ベストプラクティス

- **defer** でリソース解放
- **早期リターン** でネスト回避
- **`any`** より具体的な型 or ジェネリクス
- **nil チェック** 徹底
