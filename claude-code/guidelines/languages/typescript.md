# TypeScript ガイドライン

TypeScript 5.9対応（2026年1月時点、安定版5.9.3）。共通ガイドラインは `~/.claude/guidelines/common/` 参照。

---

## 基本原則

- **strict: true 必須**: 全strictオプション有効化
- **型システム最大活用**: コンパイル時エラー検出
- **ECMAScript最新**: ES2024サポート（5.7+）
- **関数型**: 不変性、純粋関数

---

## ディレクトリ構成

- `domain/` - エンティティ、値オブジェクト
- `application/` - ユースケース
- `infrastructure/` - DB、外部API
- `presentation/` - コントローラー、DTO

---

## 型定義（厳格）

### 禁止事項
- **any禁止**: `unknown` + 型ガード
- **as禁止**: 型ガード関数でナローイング
- **! 禁止**: 明示的nullチェック

### 型の使い分け
- `interface` - オブジェクト形状
- `type` - ユニオン・交差型
- **Branded Type** - ID型安全性
- **const assertion** - `as const`

### Utility Types
`Partial<T>`, `Pick<T,K>`, `Omit<T,K>`, `Record<K,V>`, `Required<T>`

---

## 命名規則

- 変数・関数: camelCase
- 型・クラス: PascalCase
- 定数: UPPER_SNAKE_CASE
- private: # prefix

---

## null/undefined

- `?.` - Optional Chaining
- `??` - Nullish Coalescing
- 型ガード: `function isUser(data: unknown): data is User`

---

## 関数設計

- 純粋関数優先
- 副作用を明示的に分離
- 早期リターン

---

## クイックリファレンス

### 型定義

| 用途 | コード | 説明 |
|------|--------|------|
| 型安全unknown | `unknown` + 型ガード | any の代替 |
| Union | `type Status = "active" \| "inactive"` | いずれか |
| Intersection | `type A & B` | 両方の型 |
| Branded Type | `type UserId = string & { __brand: "UserId" }` | ID型区別 |
| const assertion | `as const` | リテラル型 |

### Utility Types

| 型 | 用途 |
|----|------|
| `Partial<T>` | 全プロパティをオプション化 |
| `Required<T>` | 全プロパティを必須化 |
| `Pick<T, K>` | 特定プロパティ抽出 |
| `Omit<T, K>` | 特定プロパティ除外 |
| `Record<K, V>` | キー・値のマップ |

### エラー処理

| パターン | コード | 用途 |
|---------|--------|------|
| Result型 | `type Result<T, E> = { ok: true; value: T } \| { ok: false; error: E }` | 関数型エラー処理 |
| カスタムエラー | `class NotFoundError extends Error` | 型付きエラー |
| try-catch | `try { ... } catch (error) { ... }` | 例外処理 |

## よくあるミス

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| `function process(data: any)` | `function process<T>(data: T)` | 型安全性 |
| `const user = data as User` | `if (isUser(data))` | ランタイム安全 |
| `user.name!.toUpperCase()` | `user.name?.toUpperCase()` | null安全 |
| `throw new Error()` | `Result<T, E>` 型 | 制御フロー明確化 |
| `interface{}` 多用 | ジェネリクス | 型推論 |

---

## TypeScript 5.7-5.9 新機能

**5.8 (2025)**:
- ビルド高速化 - パス正規化最適化
- `--erasableSyntaxOnly` - ランタイム構文検出
- `--module node18` - Node.js 18固定

**5.7**:
- 未初期化変数検出
- `--target es2024`
- `Object.groupBy()`, `Map.groupBy()`
- `--rewriteRelativeImportExtensions`

**5.6**:
- Disallowed Nullish/Truthy Checks

**5.0**:
- Decorators (Stage 3)

### 5.9（2026年1月時点の安定版）
- **型推論改善**: より正確な型推論、特に条件型
- **パフォーマンス向上**: ビルド時間・メモリ使用量の最適化
- **エラーメッセージ改善**: より分かりやすいエラー表示

---

## 次期バージョン情報（2026年）

| バージョン | リリース予定 | 主な変更 |
|-----------|-------------|---------|
| **6.0** | 2026年中 | JS版コンパイラ最終版<br>7.0への橋渡し<br>6.1はリリース予定なし |
| **7.0** | 2026年中 | ネイティブコンパイラ（Project Corsa）<br>10倍高速化（フルビルド）<br>メモリ・並列性改善 |

### 参考リンク
- [Progress on TypeScript 7](https://devblogs.microsoft.com/typescript/progress-on-typescript-7-december-2025/)
- [TypeScript Native Port](https://www.infoworld.com/article/4100582/microsoft-steers-native-port-of-typescript-to-early-2026-release.html)

---

## tsconfig.json 必須設定

```json
{
  "compilerOptions": {
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitReturns": true,
    "target": "es2024"
  }
}
```

---

## ツール

- ESLint + typescript-eslint
- Prettier
- TypeDoc
