# TypeScript ガイドライン（サマリー版）

## バージョン情報

| 項目 | バージョン |
|------|-----------|
| **最新安定版** | TypeScript 5.9.3 |
| **次期予定** | TS 6.0（2026年Q2-Q3）、TS 7.0（2027年） |

## TypeScript 5.9 新機能

| 機能 | 概要 |
|------|------|
| 型推論改善 | `satisfies`演算子とジェネリクスの推論精度向上 |
| パフォーマンス向上 | 大規模プロジェクトのコンパイル速度改善 |
| エディタ連携強化 | 補完・リファクタリング機能向上 |

## 次期バージョン展望

| バージョン | 予定機能 |
|-----------|---------|
| **TS 6.0** | 型システム刷新、新構文導入 |
| **TS 7.0** | ECMAScript最新仕様対応、破壊的変更 |

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

## パフォーマンス

| 項目 | 推奨 |
|------|------|
| 不要な再レンダリング防止 | React: メモ化活用 |
| メモ化 | useMemo, useCallback（必要時のみ） |
| 遅延ロード | lazy import、dynamic import |
