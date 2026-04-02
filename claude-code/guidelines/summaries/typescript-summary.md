# TypeScript ガイドライン（サマリー版）

## バージョン: TypeScript 5.9.3（次期: TS 6.0 2026年Q2-Q3）

## 型安全性（最優先）

| NG | OK |
|----|----|
| `data: any` | `data: T`（ジェネリクス） |
| `data as string` | `typeof data === 'string'`（型ガード） |
| strict mode無効 | `tsconfig.json`で有効化必須 |

## 命名規則

| 種類 | 規則 | 例 |
|------|------|-----|
| 変数/関数 | camelCase | `fetchUserData` |
| クラス/IF | PascalCase | `UserProfile` |
| 定数 | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |

## 古いパターン検出

### 必ず指摘

| 古い | モダン | Since |
|------|--------|-------|
| 数値`enum` | `as const` / ユニオン型 | 全般 |
| `namespace` | ES Modules | 全般 |
| `require()` | `import`（ESM） | ES2015 |
| `any` | `unknown` + 型ガード | strict |

### 積極的に指摘

| 古い | モダン | Since |
|------|--------|-------|
| `.then().catch()` | `async`/`await` | ES2017 |
| `indexOf !== -1` | `includes()` | ES2016 |
| `reduce`グルーピング | `Object.groupBy()` | ES2024 |
| `lodash.get` | `?.`（Optional chaining） | TS3.7 |
| `x === null \|\| x === undefined` | `??`（Nullish Coalescing） | TS3.7 |
