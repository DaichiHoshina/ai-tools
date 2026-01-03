---
name: code-quality-review
description: コード品質レビュー - アーキテクチャ、コード臭、パフォーマンス、型安全性を統合評価
requires-guidelines:
  - common
  - typescript
---

# コード品質レビュー（統合版）

## 統合スコープ

このスキルは以下4つの観点を統合したレビューを提供します：

1. **アーキテクチャ** - クリーンアーキテクチャ、DDD、依存関係
2. **コード臭** - 長すぎる関数、重複コード、マジックナンバー、複雑度
3. **パフォーマンス** - N+1問題、メモリリーク、非効率なアルゴリズム
4. **型安全性** - any/as使用、null安全性、型ガード

## 使用タイミング

- **コードレビュー時（包括的な品質確認）**
- **リファクタリング時**
- **/review コマンド実行時**

---

## レビュー観点

### 🔴 Critical（修正必須）

#### 1. アーキテクチャ: 依存関係の逆転

```go
// ❌ 危険: Domain が Infrastructure に依存
domain/
  user.go
    import "infrastructure/database"  ← 禁止！

// ✅ 正しい: Infrastructure が Domain に依存
domain/
  user.go
  repository.go  ← インターフェース定義
infrastructure/
  user_repository.go
    import "domain"  ← OK
```

#### 2. アーキテクチャ: ビジネスロジックの配置違反

```typescript
// ❌ 危険: Controller にビジネスロジック
class UserController {
  async create(req) {
    // 複雑なバリデーション・計算ロジックがここにある
    if (user.age >= 18 && user.status === 'verified') { ... }
  }
}

// ✅ 正しい: UseCase/Domain に配置
class CreateUserUseCase {
  execute(input: CreateUserInput) {
    const user = User.create(input);
    user.verify();  // ロジックはDomainに
  }
}
```

#### 3. コード臭: 長すぎる関数（100行以上）

```typescript
// ❌ 危険 - 200行の関数
function processOrder(order) {
  // バリデーション 50行
  // 在庫チェック 30行
  // 決済処理 40行
  // メール送信 30行
  // ログ記録 50行
}

// ✅ 安全 - 責務分離
function processOrder(order) {
  validateOrder(order);
  checkInventory(order);
  processPayment(order);
  sendConfirmationEmail(order);
  logOrderProcessed(order);
}
```

#### 4. コード臭: マジックナンバー・文字列

```typescript
// ❌ 危険
if (user.age > 18) { ... }
if (order.status === 'pending') { ... }

// ✅ 安全
const LEGAL_AGE = 18;
const OrderStatus = { PENDING: 'pending' as const };

if (user.age > LEGAL_AGE) { ... }
if (order.status === OrderStatus.PENDING) { ... }
```

#### 5. パフォーマンス: N+1 問題

```typescript
// ❌ 危険 - N+1
const users = await getUserList();
for (const user of users) {
  const posts = await getPostsByUserId(user.id); // N回クエリ
}

// ✅ 安全 - 1クエリ
const users = await getUserList();
const userIds = users.map(u => u.id);
const posts = await getPostsByUserIds(userIds);
```

#### 6. パフォーマンス: メモリリーク

```typescript
// ❌ 危険 - イベントリスナー解除なし
useEffect(() => {
  window.addEventListener('resize', handler);
  // cleanup なし
}, []);

// ✅ 安全 - cleanup
useEffect(() => {
  window.addEventListener('resize', handler);
  return () => window.removeEventListener('resize', handler);
}, []);
```

#### 7. 型安全性: any 型の使用

```typescript
// ❌ 危険
function process(data: any) { ... }
const result: any = fetchData();

// ✅ 安全
function process(data: unknown) { ... }
const result: User = fetchData();
```

#### 8. 型安全性: 無検証の型アサーション

```typescript
// ❌ 危険
const user = data as User;

// ✅ 安全（型ガード使用）
function isUser(data: unknown): data is User {
  return typeof data === 'object' && data !== null && 'id' in data;
}
if (isUser(data)) { ... }
```

### 🟡 Warning（要改善）

#### 1. アーキテクチャ: Fat Controller / Fat Service

```typescript
// ⚠️ 1ファイル500行超え、複数責務
class UserService {
  createUser() { ... }
  sendEmail() { ... }
  generateReport() { ... }
}

// ✅ 責務分離
class CreateUserUseCase { ... }
class EmailService { ... }
class ReportGenerator { ... }
```

#### 2. コード臭: 深いネスト（3階層以上）

```typescript
// ⚠️ 改善推奨
if (user) {
  if (user.isActive) {
    if (user.hasPermission) {
      // 処理
    }
  }
}

// ✅ 早期リターン
if (!user) return;
if (!user.isActive) return;
if (!user.hasPermission) return;
// 処理
```

#### 3. パフォーマンス: 非効率なアルゴリズム

```typescript
// ⚠️ O(n²) - 改善推奨
for (const a of list1) {
  for (const b of list2) {
    if (a.id === b.id) { ... }
  }
}

// ✅ O(n) - Map使用
const map = new Map(list2.map(b => [b.id, b]));
for (const a of list1) {
  const b = map.get(a.id);
  if (b) { ... }
}
```

#### 4. 型安全性: 過剰な型注釈

```typescript
// ⚠️ 冗長
const users: User[] = getUsers(); // getUsers()の戻り値型が明確

// ✅ 型推論活用
const users = getUsers();
```

---

## チェックリスト

### アーキテクチャ
- [ ] Domain は外部依存がないか
- [ ] ビジネスロジックが Domain/UseCase にあるか
- [ ] 循環依存がないか

### コード臭
- [ ] 関数が50行以内か
- [ ] マジックナンバーがないか
- [ ] 重複コードが3回以上出現していないか

### パフォーマンス
- [ ] N+1 問題がないか
- [ ] イベントリスナーの cleanup があるか
- [ ] O(n²) 以上のアルゴリズムがないか

### 型安全性
- [ ] any が使用されていないか
- [ ] as による型アサーションに型ガードがあるか
- [ ] strictNullChecks が有効か

---

## 出力形式

```
## コード品質レビュー結果

### アーキテクチャ
🔴 **Critical**: `ファイル:行` - 依存違反 - 修正案
🟡 **Warning**: `ファイル:行` - 設計改善推奨 - リファクタ案

### コード臭
🔴 **Critical**: `ファイル:行` - 長すぎる関数 - リファクタ案
🟡 **Warning**: `ファイル:行` - 深いネスト - 改善案

### パフォーマンス
🔴 **Critical**: `ファイル:行` - N+1問題 - 修正案
🟡 **Warning**: `ファイル:行` - 非効率な処理 - 最適化案

### 型安全性
🔴 **Critical**: `ファイル:行` - any使用 - 型ガード実装案
🟡 **Warning**: `ファイル:行` - 改善推奨 - リファクタ案

📊 **Summary**: Critical X件 / Warning Y件
```

---

## 関連ガイドライン

- `common/code-quality-design.md` - コード品質とクリーンアーキテクチャの原則
- `common/type-safety-principles.md` - 型安全性の基本原則
- `common/technical-pitfalls.md` - パフォーマンス関連の技術的落とし穴
- `languages/*.md` - 各言語の慣用的コーディングスタイル

---

## 外部知識ベース

最新のベストプラクティス確認には context7 を活用:
- DDD（ドメイン駆動設計）公式資料
- クリーンアーキテクチャ
- SOLID原則
- リファクタリングカタログ（Martin Fowler）
- TypeScript公式ドキュメント
- Go公式ドキュメント

---

## プロジェクトコンテキスト

プロジェクト固有の情報を確認:
- serena memory からレイヤー構成・設計パターンを取得
- プロジェクトのアーキテクチャパターンとの一貫性を確認
- コーディング規約（命名規則、ディレクトリ構造）
- 許容される複雑度（循環的複雑度の上限値、関数行数制限）
