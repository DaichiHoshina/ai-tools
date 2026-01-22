# Rust ガイドライン

Rust 2024 Edition対応。共通ガイドラインは `~/.claude/guidelines/common/` 参照。

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

| 避ける | 使う | 理由 |
|-------|------|------|
| `.unwrap()` 乱用 | `?` または `expect()` | パニック防止 |
| `.clone()` 乱用 | 借用で解決 | パフォーマンス |
| `unsafe` 多用 | 安全な代替 | メモリ安全性 |
| `String` 返却 | `&str` 借用 | 不要なアロケーション |
| 大きな `enum` | `Box<dyn Trait>` | スタックサイズ |

---

## バージョン別新機能

**Edition 2024**:
- `gen` ブロック (ジェネレータ)
- `async` クロージャ安定化
- RPITIT (impl Trait in Trait)
- `let chains` in if/while

**1.80+**:
- `LazyCell`, `LazyLock` 安定化
- `Box::leak` 改善
- `#[diagnostic]` 属性

---

## クレート推奨

### 非同期
- `tokio` - ランタイム
- `async-trait` - 非同期トレイト
- `futures` - ユーティリティ

### Web
- `axum` - Webフレームワーク
- `reqwest` - HTTPクライアント
- `serde` - シリアライズ

### CLI
- `clap` - 引数パーサ
- `tracing` - ロギング
- `color-eyre` - エラー表示

---

## パターン例

### Builder
```rust
#[derive(Default)]
pub struct ConfigBuilder {
    timeout: Option<Duration>,
}

impl ConfigBuilder {
    pub fn timeout(mut self, t: Duration) -> Self {
        self.timeout = Some(t);
        self
    }

    pub fn build(self) -> Config {
        Config {
            timeout: self.timeout.unwrap_or(Duration::from_secs(30)),
        }
    }
}
```

### Error型
```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AppError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("Not found: {0}")]
    NotFound(String),
}
```
