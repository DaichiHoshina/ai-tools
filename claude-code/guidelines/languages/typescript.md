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

---

## 古いパターン検出（レビュー/実装時チェック）

`tsconfig.json` の `target` と `package.json` の TypeScript バージョンを確認してから指摘する。

### 🔴 Critical（必ず指摘）

| ❌ 古い | ✅ モダン | Since |
|---------|----------|-------|
| `enum Foo { ... }` (数値enum) | `as const` オブジェクト or ユニオン型 | TS全般 |
| `namespace` | ES Modules (`import`/`export`) | TS全般 |
| `/// <reference>` | `import` 文 | TS全般 |
| `require()` | `import` (ESM) | ES2015+ |
| `any` 型の使用 | `unknown` + 型ガード or ジェネリクス | strict |

### 🟡 Warning（積極的に指摘）

| ❌ 古い | ✅ モダン | Since |
|---------|----------|-------|
| `Promise.then().catch()` チェーン | `async`/`await` + `try`/`catch` | ES2017 |
| `Object.assign({}, obj)` | スプレッド `{ ...obj }` | ES2018 |
| `arr.indexOf(x) !== -1` | `arr.includes(x)` | ES2016 |
| `Object.keys(obj).forEach(...)` | `Object.entries(obj)` / `for...of` | ES2017 |
| `arr.filter(...)[0]` | `arr.find(...)` | ES2015 |
| `arr.reduce` で配列グルーピング | `Object.groupBy()` / `Map.groupBy()` | ES2024/TS5.7 |
| `lodash.get(obj, 'a.b.c')` | Optional chaining `obj?.a?.b?.c` | TS3.7/ES2020 |
| `x === null \|\| x === undefined` | `x ?? fallback` (Nullish Coalescing) | TS3.7/ES2020 |
| `x != null ? x : fallback` | `x ?? fallback` | TS3.7/ES2020 |
| class component (`extends React.Component`) | 関数コンポーネント + Hooks | React 16.8+ |
| `@decorator` (legacy/experimental) | Stage 3 Decorators | TS5.0 |
| `typeof x === 'string'` 繰返し | `satisfies` で型保証 | TS4.9 |

### ℹ️ Info（提案レベル）

| 項目 | 内容 | Since |
|------|------|-------|
| TS 7.0 (Project Corsa) | ネイティブコンパイラで10倍高速化。6.0はJS版最終版 | 2026予定 |
| `--erasableSyntaxOnly` | ランタイムに影響する構文を検出 | TS5.8 |

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
