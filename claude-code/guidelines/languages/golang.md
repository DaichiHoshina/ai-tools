# Golang ガイドライン

Go 1.26.2 対応（2026年4月時点）。共通: `~/.claude/guidelines/common/`。
関連: `languages/go-performance.md`（escape/GC/pprof/PGO）/ `languages/go-concurrency.md`（scheduler/channel sizing/leak 検出）。

## 基本原則

- Simplicity beats complexity
- 公式ツール必須: `gofmt`, `goimports`
- 公式 idiom 優先、独自パターン禁止
- Accept interfaces, return structs
- exported names にコメント必須

## ディレクトリ構成

`domain/`（エンティティ・値オブジェクト）/ `usecase/` / `interface/`（コントローラー・プレゼンター）/ `infrastructure/`（DB・外部 API）。

## 型定義

### ジェネリクス（1.18+）

`func Map[T, R any](slice []T, fn func(T) R) []R`。Generic Type Aliases（1.24）: `type Pair[T any] = struct{ A, B T }`。

### 構造体設計

- フィールド: 小文字開始（非公開）デフォルト
- getter/setter より振る舞いメソッド優先
- 埋め込み: 「is-a」のみ
- 意味的型分離: 構造が同じでも意味が異なれば型を分ける

### 意味的型分離（コピペ型共有禁止）

| 判断軸 | 同じ型でOK | 型を分ける |
|--------|-----------|-----------|
| ライフサイクル | 常に一緒に変更・削除 | 片方だけ変更・削除しうる |
| 命名 | 共通概念名が自然 | 共通名で意味がぼやける |
| 進化方向 | 将来もフィールド揃う保証あり | 片方だけ増減しうる |

判定: 「変更/削除時に無関係な機能に影響するか？」→ Yes なら分ける。共通化時は汎用名（例: `PaginationParams`, `DateRangeFilter`）。特定機能名の型を他機能で流用しない。

## 命名規則

- パッケージ: 小文字、単数形、短く（`user`）
- インターフェース: 動詞+er（`Reader`）
- コンストラクタ: `New` + 型名

## クイックリファレンス

### エラー処理

| パターン | コード | 用途 |
|---------|--------|------|
| 基本 | `if err != nil { return err }` | 伝播 |
| ラップ | `fmt.Errorf("msg: %w", err)` | コンテキスト追加 (1.13+) |
| 判定 | `errors.Is(err, ErrNotFound)` | 種別確認 |
| Sentinel | `var ErrNotFound = errors.New("not found")` | 定数エラー定義 |

### 並行処理

| パターン | コード | 用途 |
|---------|--------|------|
| goroutine | `go func() { ... }()` | 並行実行 |
| context | `ctx, cancel := context.WithTimeout(ctx, 5*time.Second)` | キャンセル |
| channel | `ch := make(chan T, bufSize)` | データ受渡 |
| Mutex | `defer mu.Unlock()` | 排他 |
| WaitGroup | `wg.Wait()` | 完了待機 |

### テスト

| パターン | コード | 用途 |
|---------|--------|------|
| 基本 | `func TestXxx(t *testing.T)` | ユニット |
| テーブル駆動 | `tests := map[string]struct{...}` | 複数ケース |
| ベンチマーク | `for b.Loop() { ... }` | 性能測定 (1.24+) |
| 並行テスト | `testing/synctest` | 並行コード (1.25+) |

## よくあるミス

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| `result, _ := db.Query()` | エラーチェック必須 | エラー無視禁止 |
| `go doWork()`（無制限） | `ctx` + `WaitGroup` | リソース管理・リーク防止 |
| `panic()` で通常エラー | `return err` | 原則 |
| 既存型を別用途に流用 | 用途ごとに型定義 | 意味的型分離 |
| Usecase でフィールド直接書換 | model に `SetXxx()` | 変更ロジック集約 |
| パラメータなし Input 構造体 | 引数なしに | 不要な型を増やさない |
| `SELECT *` | 必要カラムのみ | パフォーマンス・安全性 |
| サーバー不整合に 400 返却 | 500（400 はクライアント起因のみ） | ステータスコード意味 |

## 古いパターン検出

`go.mod` の `go` ディレクティブで対象バージョン確認してから指摘。

### 🔴 Critical（必ず指摘）

| ❌ 古い | ✅ モダン | Since |
|---------|----------|-------|
| `ioutil.ReadAll` | `io.ReadAll` | 1.16 |
| `ioutil.ReadFile`/`WriteFile` | `os.ReadFile`/`os.WriteFile` | 1.16 |
| `ioutil.ReadDir` | `os.ReadDir` | 1.16 |
| `ioutil.TempDir`/`TempFile` | `os.MkdirTemp`/`os.CreateTemp` | 1.16 |
| `ioutil.NopCloser`/`Discard` | `io.NopCloser`/`io.Discard` | 1.16 |
| `interface{}` | `any`（or ジェネリクス） | 1.18 |

### 🟡 Warning（積極的に指摘）

| ❌ 古い | ✅ モダン | Since |
|---------|----------|-------|
| `sort.Slice`/`sort.Ints`/`sort.Strings` | `slices.Sort`/`slices.SortFunc` | 1.21 |
| 手動スライスコピー | `slices.Clone(src)` | 1.21 |
| 手動スライス検索 | `slices.Contains(s, v)` | 1.21 |
| 手動マップコピー | `maps.Copy(dst, src)` | 1.21 |
| 自前 `min`/`max` 関数 | ビルトイン `min()`/`max()` | 1.21 |
| `log.Printf`（非構造化） | `slog.Info` 等 | 1.21 |
| `for i := 0; i < n; i++` | `for i := range n` | 1.22 |
| ループ変数 `v := v` シャドー | 不要（イテレーション毎スコープ） | 1.22 |
| `[]T` 返却 | `iter.Seq[T]` | 1.23 |
| `for i := 0; i < b.N; i++` | `for b.Loop()` | 1.24 |

### ℹ️ Info

- `go fix ./...` で多くを自動修正、大量検出時推奨（1.26）
- `new(T, val)` 初期値付き new（1.26）

## ベストプラクティス

`defer` でリソース解放 / 早期リターンでネスト回避 / `any` より具体型 or ジェネリクス / nil チェック徹底。

## テスト詳細

### ビルドタグ

| タグ | `t.Parallel()` | DB/Fixtures | 用途 |
|-----|--------------|------------|------|
| `parallel` | 必須 | 禁止（mock 使用） | ユニット |
| `serial` | 禁止 | 可 | Repository 実装 |
| `integration` | 禁止 | 可 | フルスタック |

### テーブル駆動 / フレーキー対策

- slice でなく **map** を使用（サブテスト名強制、順序ランダム化で分離）
- アサーション: `cmp.Diff(expected, actual)`
- 名前: アンダースコア区切り（`TestXxx_returns_error`）
- 自動生成 ID は期待値に入れない（存在確認のみ）
- parallel テストで共有データ変更しない（deep copy してから操作）
- parallel タグは `t.Parallel()` 必須（トップ＆サブテスト両方）

## データベース

### 命名

| 要素 | パターン | 例 |
|------|---------|-----|
| テーブル/カラム | snake_case | `user_orders`, `created_at` |
| Index | `idx_table_column` | `idx_users_email` |
| FK | `fkey_table_column` | `fkey_orders_user_id` |
| Unique | `ukey_table_column` | `ukey_users_email` |

### クエリルール

- プレースホルダ: 名前付き（`:var_name`）のみ、`?` 禁止
- 必ず `WithContext(ctx)`
- BETWEEN は datetime 不可（`>=` と `<` 使用）
- INSERT/UPDATE は ORM の Insert/Update（生 SQL 禁止）
- テーブルエイリアスの `AS` 禁止（自己結合除く）
- `SELECT *` 禁止
- 例外的に生 SQL bulk INSERT を書く場合、`LastInsertId() + i` 採番は単純挿入限定（NG: `INSERT...SELECT` / `ON DUPLICATE KEY UPDATE` / 混合 / 動的行数 / migration backfill）。詳細: [backend/mysql-performance.md §12](../backend/mysql-performance.md)

## エンティティ・Nullable

| 層 | 推奨型 | 禁止 |
|----|--------|------|
| Entity（DB mapping）| `sql.Null[T]`（1.22+） | `sql.NullInt64` 等の型固有版、`*T` |
| Domain/Service | カスタム `Nullable[T]` | `*T`（意味的区別のため） |
| Handler/Adapter | `*T` | `Nullable[T]`（Swagger 等互換性） |

値アクセス: `.V` フィールド or `.Valid` チェック後。

## API 設計

- URL: スラッシュで終わらない（`/users/123` ○、`/users/123/` ✕）
- JSON キー: lowerCamelCase、ハイフン禁止
- 空配列: `[]` を返す（`null` 禁止）
- `omitempty` タグ禁止（クライアント パース問題回避）
- タイムゾーン: DB/API は UTC、表示時にローカルタイム変換

## マイグレーション

- 既存ファイル編集禁止（適用済環境に影響なし → 不整合の原因）
- テーブル変更は常に新規ファイル（`ALTER TABLE`）
- up/down 両ファイル必須
- 番号は main の最新確認してから振る（マージ直前にも再確認）
- down の `MODIFY COLUMN` では `DEFAULT` 句を明示

## セキュリティ

- 乱数: `crypto/rand`（`math/rand` 禁止）
- シークレット比較: `subtle.ConstantTimeCompare`（`==` 禁止 → タイミング攻撃対策）
- 最低 32 バイト以上生成
- 認証: セッション/トークン有効性を先にチェック、ユーザー ID はセッション/トークンから取得（リクエストパラメータ禁止）

## CQRS

- Command（書込）と Query（読取）でレイヤー分離
- Command: Work Unit パターンでトランザクション管理
- Command usecase シグネチャ: `Do(ctx, in *Input) (*Output, *Result)`（`*Result` は操作成否、`error` の代替）
- Mock 生成: `go generate`（手動禁止）
