# Rustガイドライン

Rust 2024 Edition対応、stable 1.96.0（2026-06時点）。共通ガイドラインは `~/.claude/guidelines/common/` 参照。

---

## 基本原則

- **所有権**: 借用チェッカーに従う
- **ゼロコスト抽象化**: パフォーマンス重視
- **安全性**: `unsafe` は最小限
- **ツール**: `cargo fmt`, `clippy`, `rustfmt` 必須
- **Idiom優先**: 公式ドキュメントパターン

---

## ディレクトリ構成

- `src/` - ソースコード
  - `main.rs` または `lib.rs`
  - `bin/` - 複数バイナリ
- `tests/` - 統合テスト
- `benches/` - ベンチマーク
- `Cargo.toml` - 依存関係

---

## 型システム

### 基本
- `struct` - データ構造
- `enum` - 代数的データ型
- `trait` - インターフェース
- `impl` - 実装ブロック

### ジェネリクス
- `fn process<T: Display>(item: T)` - トレイト境界
- `where T: Clone + Send` - 複雑な境界
- `impl<T> Trait for Type<T>` - blanket impl

---

## 命名規則

- **クレート/モジュール**: `snake_case`
- **型/トレイト**: `PascalCase`
- **関数/変数**: `snake_case`
- **定数**: `SCREAMING_SNAKE_CASE`
- **ライフタイム**: `'a`, `'static`

---

## クイックリファレンス

### エラー処理

| パターン | コード | 用途 |
|---------|--------|------|
| Result | `fn f() -> Result<T, E>` | 回復可能エラー |
| Option | `fn find() -> Option<T>` | 値の有無 |
| ? 演算子 | `let x = try_fn()?;` | エラー伝播 |
| anyhow | `anyhow::Result<T>` | アプリエラー |
| thiserror | `#[derive(Error)]` | ライブラリエラー |

### 所有権

| パターン | コード | 用途 |
|---------|--------|------|
| 所有権移動 | `let b = a;` | 所有権譲渡 |
| 借用 | `&value` | 不変参照 |
| 可変借用 | `&mut value` | 可変参照 |
| Clone | `value.clone()` | 明示的コピー |
| Rc/Arc | `Arc::new(data)` | 共有所有権 |

### 非同期処理

| パターン | コード | 用途 |
|---------|--------|------|
| async fn | `async fn fetch() -> Result<T>` | 非同期定義 |
| await | `result.await?` | 非同期待機 |
| spawn | `tokio::spawn(task)` | タスク生成 |
| join | `tokio::join!(a, b)` | 並行実行 |

### テスト

| パターン | コード | 用途 |
|---------|--------|------|
| 単体 | `#[test] fn test_fn()` | ユニットテスト |
| 非同期 | `#[tokio::test]` | 非同期テスト |
| 失敗期待 | `#[should_panic]` | パニックテスト |
| 無視 | `#[ignore]` | スキップ |

## よくあるミス

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| `.unwrap()` 乱用 | `?` または `expect()` | パニック防止 |
| `.clone()` 乱用 | 借用で解決 | パフォーマンス |
| `unsafe` 多用 | 安全な代替 | メモリ安全性 |
| `String` 返却 | `&str` 借用 | 不要なアロケーション |
| 大きな `enum` | `Box<dyn Trait>` | スタックサイズ |

---

## 古いパターン検出（レビュー/実装時チェック）

`Cargo.toml` の `edition` と `rust-version` を確認してから指摘する。

### 🔴 Critical（必ず指摘）

| ❌ 古い | ✅ モダン | Since |
|---------|----------|-------|
| `#[async_trait]` マクロ（大半のケース） | ネイティブ `async fn` in trait (RPITIT) | Edition 2024 |
| `impl Trait` 返却不可（トレイト内） | `fn f() -> impl Trait` in trait | 1.75 |
| `lazy_static!` マクロ | `std::sync::LazyLock` / `std::cell::LazyCell` | 1.80 |
| `once_cell::sync::Lazy` | `std::sync::LazyLock` | 1.80 |

### 🟡 Warning（積極的に指摘）

| ❌ 古い | ✅ モダン | Since |
|---------|----------|-------|
| `Box<dyn Fn()>` クロージャ返却 | `impl Fn()` 返却（RPITIT） | 1.75 |
| `if let Some(x) = a { if let Some(y) = b { } }` | `let chains`: `if let Some(x) = a && let Some(y) = b` | Edition 2024 |
| 手動イテレータ実装 | `gen` ブロック（ジェネレータ） | Edition 2024 |
| `async move \|\| { }` | `async \|\| { }` （asyncクロージャ安定化） | Edition 2024 |
| `log` クレート | `tracing` クレート（構造化ログ + スパン） | 推奨 |
| `failure` クレート | `thiserror` + `anyhow` | 推奨 |
| `reqwest::blocking` | `reqwest` async + tokio | 推奨 |
| `println!` デバッグ | `tracing::debug!` / `dbg!` | 推奨 |
| `#[derive(Clone, Debug)]` 手動列挙 | `#[diagnostic]` 属性で改善されたエラーメッセージ活用 | 1.80 |

### ℹ️ Info（提案レベル）

| 項目 | 内容 | Since |
|------|------|-------|
| `cargo clippy --fix` | 多くの古いパターンを自動修正 | 常用 |
| Edition 2024移行 | `cargo fix --edition` で自動マイグレーション | 2024 |

---

## クレート推奨

| カテゴリ | クレート |
|---------|---------|
| 非同期 | `tokio`, `futures` |
| Web | `axum`, `reqwest`, `serde` |
| エラー | `thiserror` (ライブラリ), `anyhow` (アプリ) |
| CLI | `clap`, `tracing`, `color-eyre` |
