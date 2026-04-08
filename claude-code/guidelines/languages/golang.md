# Golang ガイドライン

Go 1.26対応（2026年2月リリース）。共通ガイドラインは `~/.claude/guidelines/common/` 参照。

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
| テーブル駆動 | `tests := map[string]struct{...}` | 複数ケース（詳細は「テスト詳細」参照） |
| ベンチマーク | `for b.Loop() { ... }` | 性能測定 (1.24+) |
| 並行テスト | `testing/synctest` | 並行コード (1.25+) |

## よくあるミス

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| `result, _ := db.Query()` | エラーチェック必須 | エラー無視禁止 |
| `go doWork()` (無制限) | `ctx` + `WaitGroup` でリーク防止 | リソース管理 |
| `panic()` で通常エラー | `return err` | エラー処理の原則 |

---

## 古いパターン検出（レビュー/実装時チェック）

`go.mod` の `go` ディレクティブで対象バージョンを確認してから指摘する。

### 🔴 Critical（必ず指摘）

| ❌ 古い | ✅ モダン | Since |
|---------|----------|-------|
| `ioutil.ReadAll` | `io.ReadAll` | 1.16 |
| `ioutil.ReadFile` / `WriteFile` | `os.ReadFile` / `os.WriteFile` | 1.16 |
| `ioutil.ReadDir` | `os.ReadDir` | 1.16 |
| `ioutil.TempDir` / `TempFile` | `os.MkdirTemp` / `os.CreateTemp` | 1.16 |
| `ioutil.NopCloser` / `Discard` | `io.NopCloser` / `io.Discard` | 1.16 |
| `interface{}` | `any`（またはジェネリクスで型安全に） | 1.18 |

### 🟡 Warning（積極的に指摘）

| ❌ 古い | ✅ モダン | Since |
|---------|----------|-------|
| `sort.Slice` / `sort.Ints` / `sort.Strings` | `slices.Sort` / `slices.SortFunc` | 1.21 |
| 手動スライスコピー `copy(dst, src)` | `slices.Clone(src)` | 1.21 |
| 手動スライス検索ループ | `slices.Contains(s, v)` | 1.21 |
| 手動マップコピーループ | `maps.Copy(dst, src)` | 1.21 |
| 自前 `min`/`max` 関数定義 | ビルトイン `min()` / `max()` | 1.21 |
| `log.Printf` (非構造化ログ) | `slog.Info` 等（構造化ログ） | 1.21 |
| `for i := 0; i < n; i++`（単純カウント） | `for i := range n` | 1.22 |
| ループ変数 `v := v` シャドーイング | 不要（イテレーション毎スコープ） | 1.22 |
| カスタムコンテナで `[]T` 返却 | `iter.Seq[T]` でイテレータ提供 | 1.23 |
| `for i := 0; i < b.N; i++` | `for b.Loop()` | 1.24 |

### ℹ️ Info（提案レベル）

| 項目 | 内容 | Since |
|------|------|-------|
| `go fix ./...` | 上記の多くを自動修正。大量検出時は個別修正より推奨 | 1.26 |
| `new(T, val)` | 初期値付きnew | 1.26 |

---

## ベストプラクティス

- **defer** でリソース解放
- **早期リターン** でネスト回避
- **`any`** より具体的な型 or ジェネリクス
- **nil チェック** 徹底

---

## テスト詳細

### ビルドタグ

| タグ | `t.Parallel()` | DB/Fixtures | 用途 |
|-----|--------------|------------|------|
| `parallel` | 必須 | 禁止（mock使用） | ユニットテスト |
| `serial` | 禁止 | 可 | Repository実装テスト |
| `integration` | 禁止 | 可 | フルスタックテスト |

### テーブル駆動テスト

- **sliceでなくmapを使用**（サブテスト名を強制、順序ランダム化でテスト分離）
- アサーション: `cmp.Diff(expected, actual)` で差分表示
- テスト名: アンダースコア区切り（`TestXxx_returns_error`）

### フレーキーテスト防止

- 自動生成IDを期待値に入れない（存在確認のみ）
- parallel テストで共有データを変更しない（deep copyしてから操作）
- parallel タグは `t.Parallel()` 必須（トップレベル＆サブテスト両方）

---

## データベース

### 命名規則

| 要素 | パターン | 例 |
|------|---------|-----|
| テーブル/カラム | snake_case | `user_orders`, `created_at` |
| Index | `idx_table_column` | `idx_users_email` |
| Foreign key | `fkey_table_column` | `fkey_orders_user_id` |
| Unique key | `ukey_table_column` | `ukey_users_email` |

### クエリルール

- プレースホルダ: 名前付き（`:var_name`）のみ、`?` 禁止
- 必ず `WithContext(ctx)` を使用
- BETWEEN は datetime に使わない（`>=` と `<` を使用）
- INSERT/UPDATE は ORM の Insert/Update（生SQL禁止）
- テーブルエイリアスの `AS` 禁止（自己結合除く）

---

## エンティティ・Nullable

| 層 | 推奨型 | 禁止 |
|----|--------|------|
| Entity（DB mapping）| `sql.Null[T]`（Go 1.22+） | `sql.NullInt64` 等の型固有版、`*T` |
| Domain/Service | カスタム `Nullable[T]` 型 | `*T`（意味的な区別のため） |
| Handler/Adapter | `*T` | `Nullable[T]`（Swagger等との互換性） |

値アクセス: `.V` フィールド（`sql.Null[T]` の Go 1.22+ 標準フィールド）、または `.Valid` チェック後に使用。

---

## API 設計

- URL: スラッシュで終わらない（`/users/123` ○、`/users/123/` ✕）
- JSON キー: lowerCamelCase、ハイフン禁止
- 空配列: `[]` を返す（`null` 禁止）
- `omitempty` タグ禁止（クライアントのパース問題を回避）
- タイムゾーン: DB/API は UTC、表示時にローカルタイムに変換

---

## マイグレーション

- **既存ファイルを編集禁止**（適用済み環境に影響なし → 不整合の原因）
- テーブル変更は常に新規ファイルで（`ALTER TABLE`）
- up/down 両ファイル必須

---

## セキュリティ

- 乱数生成: `crypto/rand`（`math/rand` 禁止）
- シークレット比較: `subtle.ConstantTimeCompare`（`==` 禁止 → タイミング攻撃対策）
- 最低32バイト以上生成
- 認証確認: セッション/トークンの有効性を先にチェック、ユーザーIDはセッション/トークンから取得（リクエストパラメータ禁止）

---

## CQRS パターン

- Command（書き込み）と Query（読み取り）でレイヤーを分離
- Command: Work Unit パターンでトランザクション管理
- Command usecase シグネチャ: `Do(ctx, in *Input) (*Output, *Result)`（`*Result`: 操作の成否を示す型、`error` の代替として使用）
- Mock 生成: `go generate` を使用（手動作成禁止）
