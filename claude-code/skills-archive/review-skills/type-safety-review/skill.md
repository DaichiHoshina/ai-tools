---
name: type-safety-review
description: 型安全性レビュー - any/as使用、null安全性、型ガードの観点からコードをレビュー
requires-guidelines:
  - typescript
  - common
---

# 型安全性レビュー

## 使用タイミング

- **コードレビュー時（型安全性の確認）**
- **PRレビュー時（any/asの検出）**
- **リファクタリング時（型安全性の向上）**

## レビュー観点

### 🔴 Critical（修正必須）

#### 1. any 型の使用
```typescript
// ❌ 危険
function process(data: any) { ... }
const result: any = fetchData();

// ✅ 安全
function process(data: unknown) { ... }
const result: User = fetchData();
```

#### 2. 無検証の型アサーション
```typescript
// ❌ 危険
const user = data as User;
const id = (response as Response).id;

// ✅ 安全（型ガード使用）
function isUser(data: unknown): data is User {
  return typeof data === 'object' && data !== null && 'id' in data;
}
if (isUser(data)) { ... }
```

#### 3. Non-null assertion (!)
```typescript
// ❌ 危険
const name = user!.name;
document.getElementById('app')!.innerHTML = '';

// ✅ 安全
const name = user?.name ?? 'default';
const app = document.getElementById('app');
if (app) { app.innerHTML = ''; }
```

### 🟡 Warning（要改善）

#### 1. interface{} / any の使用（Go）
```go
// ⚠️ 改善推奨
func process(data interface{}) { ... }

// ✅ ジェネリクス使用
func process[T any](data T) { ... }
```

#### 2. 型アサーション without ok check（Go）
```go
// ⚠️ 改善推奨
str := data.(string)

// ✅ okパターン
str, ok := data.(string)
if !ok { return errors.New("not a string") }
```

#### 3. 過剰な型注釈
```typescript
// ⚠️ 冗長
const users: User[] = getUsers(); // getUsers()の戻り値型が明確

// ✅ 型推論活用
const users = getUsers();
```

## チェックリスト

### TypeScript
- [ ] any が使用されていないか
- [ ] as による型アサーションに型ガードがあるか
- [ ] ! (Non-null assertion) が使用されていないか
- [ ] strictNullChecks が有効か
- [ ] Optional chaining (?.) / Nullish coalescing (??) を活用しているか

### Go
- [ ] interface{} が使用されていないか
- [ ] 型アサーションに ok パターンがあるか
- [ ] ポインタの nil チェックが適切か
- [ ] ジェネリクスで代替可能か

## やむを得ず any/as を使用する場合

**許容条件**:
- 外部ライブラリの型定義が不完全
- 既存コードとの一時的な互換性

**必須ルール**:
```typescript
// eslint-disable-next-line @typescript-eslint/no-explicit-any -- 外部ライブラリの型定義不備のため
const result = externalLib.method() as any;
// TODO: ライブラリ更新時に型定義を修正する
```

## 出力形式

🔴 **Critical**: `ファイル:行` - any/as/!の使用 - 型ガード実装案
🟡 **Warning**: `ファイル:行` - 改善推奨箇所 - リファクタ案
📊 **Summary**: Critical X件 / Warning Y件

## 関連ガイドライン

レビュー実施時は以下のガイドラインを参照してください：

- `common/type-safety-principles.md` - 型安全性の基本原則
- `languages/typescript.md` - TypeScript型安全性ベストプラクティス
- `languages/golang.md` - Go言語の型システムと型アサーション

これらのガイドラインには、プロジェクト固有の型安全性ポリシーや、チーム内で合意された型使用基準が含まれています。

## 外部知識ベース

必要に応じて以下の外部知識を参照してください：

- **TypeScript公式ドキュメント** - 最新の型システム機能、型ガードパターン
- **Go公式ドキュメント** - 型アサーション、インターフェース設計
- **型安全性ベストプラクティス集** - 各言語の型安全なコーディングパターン
- **strictモード設定ガイド** - tsconfig/linter設定の推奨値

Context7 MCPを使用して最新のドキュメントを取得できます。

## プロジェクトコンテキスト

レビュー時は以下のプロジェクト情報を考慮してください：

- **型定義規約** - プロジェクト内の型定義ルール（interface vs type、命名規則等）
- **any使用ポリシー** - any型が許容される条件、コメント記載ルール
- **型エラー対処履歴** - 過去に発生した型起因のバグ、修正パターン
- **外部ライブラリ型定義** - 型定義が不完全なライブラリのリスト、対処方法

プロジェクト固有の情報はSerenaのメモリーから取得できます。
