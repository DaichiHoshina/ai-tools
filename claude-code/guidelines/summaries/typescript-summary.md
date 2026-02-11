# TypeScript ガイドライン（サマリー版）

## バージョン情報

| 項目 | バージョン |
|------|-----------|
| **最新安定版** | TypeScript 5.9.3 |
| **次期予定** | TS 6.0（2026年Q2-Q3）、TS 7.0（2027年） |

## 型安全性（最優先）

| NG | OK |
|----|----|
| `function process(data: any) {}` | `function process<T>(data: T) {}` |
| `const value = data as string` | `if (typeof data === 'string') { ... }` |

## 基本原則

| 原則 | 説明 |
|------|------|
| **strict mode** | `tsconfig.json`で有効化必須 |
| **null/undefinedチェック** | 必ず確認 |
| **型推論活用** | 不要な型注釈は避ける |

## 非同期処理

```typescript
// ✅ 推奨パターン
async function fetchData(): Promise<Data> {
  try {
    const response = await fetch(url);
    return await response.json();
  } catch (error) {
    throw new Error(`Failed: ${error}`);
  }
}
```

| 項目 | 推奨 |
|------|------|
| async/await | Promise chaining より推奨 |
| エラーハンドリング | try-catch で適切に処理 |

## 命名規則

| 種類 | 規則 | 例 |
|------|------|-----|
| 変数/関数 | camelCase | `fetchUserData` |
| クラス/インターフェース | PascalCase | `UserProfile` |
| 定数 | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| プライベート | _prefix または private | `_internalState` |

## 型ガード

```typescript
// ✅ 型ガード例
function isString(value: unknown): value is string {
  return typeof value === 'string';
}
```

| パターン | 使用ケース |
|----------|------------|
| `typeof` | プリミティブ型チェック |
| `instanceof` | クラスインスタンスチェック |
| カスタム型ガード | 複雑な型判定 |

## 古いパターン検出（レビュー/実装時）

### 必ず指摘

| ❌ 古い | ✅ モダン | Since |
|---------|----------|-------|
| `enum` (数値enum) | `as const` or ユニオン型 | 全般 |
| `namespace` | ES Modules | 全般 |
| `require()` | `import` (ESM) | ES2015 |
| `any` 型 | `unknown` + 型ガード or ジェネリクス | strict |

### 積極的に指摘

| ❌ 古い | ✅ モダン | Since |
|---------|----------|-------|
| `.then().catch()` | `async`/`await` | ES2017 |
| `indexOf !== -1` | `includes()` | ES2016 |
| `reduce` でグルーピング | `Object.groupBy()` | ES2024/TS5.7 |
| `lodash.get` | Optional chaining `?.` | TS3.7 |
| `x === null \|\| x === undefined` | `??` (Nullish Coalescing) | TS3.7 |
| legacy `@decorator` | Stage 3 Decorators | TS5.0 |
