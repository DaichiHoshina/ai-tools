---
name: code-smell-review
description: コード臭レビュー - 長すぎる関数、重複コード、マジックナンバー、複雑度を検出
requires-guidelines:
  - common
---

# コード臭レビュー

## 使用タイミング

- **リファクタリング前**
- **コードレビュー時（可読性確認）**
- **大規模修正時**

## レビュー観点

### 🔴 Critical（修正必須）

#### 1. 長すぎる関数（100行以上）

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

#### 2. 重複コード（DRY違反）

```typescript
// ❌ 危険 - 同じロジックの繰り返し
function getActiveUsers() {
  return users.filter(u => u.status === 'active' && u.deletedAt === null);
}
function getActivePosts() {
  return posts.filter(p => p.status === 'active' && p.deletedAt === null);
}

// ✅ 安全 - 共通化
function getActive<T extends { status: string; deletedAt: Date | null }>(items: T[]) {
  return items.filter(item => item.status === 'active' && item.deletedAt === null);
}
```

#### 3. マジックナンバー・文字列

```typescript
// ❌ 危険
if (user.age > 18) { ... }
if (order.status === 'pending') { ... }
setTimeout(callback, 3600000);

// ✅ 安全
const LEGAL_AGE = 18;
const OrderStatus = { PENDING: 'pending' as const };
const ONE_HOUR_MS = 60 * 60 * 1000;

if (user.age > LEGAL_AGE) { ... }
if (order.status === OrderStatus.PENDING) { ... }
setTimeout(callback, ONE_HOUR_MS);
```

### 🟡 Warning（要改善）

#### 1. 深いネスト（3階層以上）

```typescript
// ⚠️ 改善推奨
if (user) {
  if (user.isActive) {
    if (user.hasPermission) {
      if (user.subscription) {
        // 処理
      }
    }
  }
}

// ✅ 早期リターン
if (!user) return;
if (!user.isActive) return;
if (!user.hasPermission) return;
if (!user.subscription) return;
// 処理
```

#### 2. 長すぎるパラメータリスト（5個以上）

```typescript
// ⚠️ 改善推奨
function createUser(
  name: string,
  email: string,
  age: number,
  address: string,
  phone: string,
  country: string
) { ... }

// ✅ オブジェクト化
interface CreateUserParams {
  name: string;
  email: string;
  age: number;
  address: string;
  phone: string;
  country: string;
}
function createUser(params: CreateUserParams) { ... }
```

#### 3. God Object（何でも屋クラス）

```typescript
// ⚠️ 改善推奨
class UserManager {
  createUser() { ... }
  deleteUser() { ... }
  sendEmail() { ... }
  generateReport() { ... }
  validateInput() { ... }
  logActivity() { ... }
  // 責務が多すぎる
}

// ✅ 責務分離
class UserRepository { /* CRUD */ }
class EmailService { /* メール送信 */ }
class ReportGenerator { /* レポート生成 */ }
class Logger { /* ログ記録 */ }
```

#### 4. コメントアウトされたコード

```typescript
// ⚠️ 削除推奨
function process() {
  // const oldWay = doSomething();
  // const anotherOldWay = doAnotherThing();
  const newWay = doNewThing();
  return newWay;
}

// ✅ 削除（Git履歴で管理）
function process() {
  const result = doNewThing();
  return result;
}
```

## チェックリスト

### 関数・メソッド
- [ ] 50行以内か
- [ ] 単一責任か
- [ ] パラメータ4個以内か
- [ ] ネスト2階層以内か

### 変数・定数
- [ ] マジックナンバーがないか
- [ ] ハードコードされた文字列がないか
- [ ] 意味のある名前か

### 重複
- [ ] 同じコードが3回以上出現していないか
- [ ] 共通化できるロジックがないか

### その他
- [ ] コメントアウトされたコードがないか
- [ ] 使われていない変数・関数がないか
- [ ] 循環的複雑度が10以下か

## 出力形式

🔴 **Critical**: `ファイル:行` - 長すぎる関数/重複コード - リファクタ案
🟡 **Warning**: `ファイル:行` - 深いネスト/God Object - 改善案
📊 **Summary**: Critical X件 / Warning Y件

## 関連ガイドライン

レビュー実施時は以下のガイドラインを参照してください：

- `common/code-quality-design.md` - コード品質とクリーンアーキテクチャの原則
- `common/unused-code-detection.md` - 未使用コード検出と削除基準
- `languages/*.md` - 各言語の慣用的コーディングスタイル
  - TypeScript: 関数分割、モジュール設計、命名規則
  - Go: パッケージ設計、エラーハンドリング、シンプルさの追求

これらのガイドラインには、SOLID原則、DRY原則、リファクタリングパターンが含まれています。

## 外部知識ベース

必要に応じて以下の外部知識を参照してください：

- **リファクタリングカタログ** - Martin Fowlerのリファクタリングパターン集
- **コードスメル一覧** - 各種コードスメルの定義と対処法
- **クリーンコード原則** - 可読性向上のための実践的ガイド
- **複雑度計算ツール** - Cyclomatic Complexity、Cognitive Complexity測定方法

Context7 MCPを使用して最新のドキュメントを取得できます。

## プロジェクトコンテキスト

レビュー時は以下のプロジェクト情報を考慮してください：

- **コーディング規約** - プロジェクト内の命名規則、ディレクトリ構造、モジュール分割方針
- **許容される複雑度** - 循環的複雑度の上限値、関数行数制限
- **リファクタリング履歴** - 過去のリファクタリング実施内容、改善効果
- **技術的負債リスト** - 既知のコードスメル箇所、優先度付け

プロジェクト固有の情報はSerenaのメモリーから取得できます。
