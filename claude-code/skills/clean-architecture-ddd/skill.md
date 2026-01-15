---
name: clean-architecture-ddd
description: クリーンアーキテクチャ・DDD設計 - レイヤー設計、ドメインモデリング、依存関係管理
requires-guidelines:
  - clean-architecture
  - ddd
  - common
---

# クリーンアーキテクチャ・DDD設計

## 使用タイミング

- **新規プロジェクト設計時（アーキテクチャ決定）**
- **既存システムのリファクタリング時（構造改善）**
- **ドメインモデリング時（ビジネスロジック整理）**

## 設計パターン

### レイヤー構成

```
依存方向: 外側 → 内側のみ

┌─────────────────────────────────────┐
│  Infrastructure (DB, API, Framework)│ ← 最外部（技術詳細）
├─────────────────────────────────────┤
│  Interface (Controller, Presenter)  │ ← ユーザーIF層
├─────────────────────────────────────┤
│  Application (UseCase, Service)     │ ← ビジネスフロー
├─────────────────────────────────────┤
│  Domain (Entity, ValueObject, Repo) │ ← 最内部（依存なし）
└─────────────────────────────────────┘
```

### DDD 戦術パターン

| パターン | 責務 | 配置層 |
|---------|------|--------|
| Entity | ID識別、ライフサイクル、ビジネスロジック | Domain |
| Value Object | 不変、値比較、副作用なし | Domain |
| Aggregate | 一貫性境界、ルートエンティティ | Domain |
| Repository | 永続化抽象（IF=Domain / 実装=Infra） | Domain/Infra |
| UseCase | アプリケーション固有ビジネスロジック | Application |
| Domain Event | 過去形命名、疎結合、イベント駆動 | Domain |

## 具体例

### ✅ Good: クリーンアーキテクチャ（Go）

```go
// Domain 層: ビジネスロジック + IF定義
package domain

type User struct {
    ID    UserID
    Email Email
    Status UserStatus
}

func (u *User) Activate() error {
    if u.Status == StatusActive {
        return ErrAlreadyActive
    }
    u.Status = StatusActive
    return nil
}

// Repository インターフェースは Domain に定義
type UserRepository interface {
    Save(user *User) error
    FindByID(id UserID) (*User, error)
}

// Application 層: UseCase
package application

type ActivateUserUseCase struct {
    repo domain.UserRepository  // IFに依存
}

func (uc *ActivateUserUseCase) Execute(userID domain.UserID) error {
    user, err := uc.repo.FindByID(userID)
    if err != nil {
        return err
    }

    if err := user.Activate(); err != nil {  // ロジックはDomainに
        return err
    }

    return uc.repo.Save(user)
}

// Infrastructure 層: 実装
package infrastructure

type PostgresUserRepository struct {
    db *sql.DB
}

func (r *PostgresUserRepository) Save(user *domain.User) error {
    // DB固有の処理はここに
}
```

### ✅ Good: DDD パターン（TypeScript）

```typescript
// Domain 層: Value Object（不変）
class Email {
  private constructor(private readonly value: string) {}

  static create(value: string): Email {
    if (!this.isValid(value)) {
      throw new Error('Invalid email');
    }
    return new Email(value);
  }

  private static isValid(value: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
  }

  equals(other: Email): boolean {
    return this.value === other.value;
  }
}

// Domain 層: Aggregate Root
class Order {
  private items: OrderItem[] = [];
  private status: OrderStatus;

  addItem(item: OrderItem): void {
    if (this.status !== OrderStatus.Draft) {
      throw new Error('Cannot add item to non-draft order');
    }
    this.items.push(item);
  }

  getTotalAmount(): Money {
    return this.items.reduce(
      (sum, item) => sum.add(item.price),
      Money.zero()
    );
  }

  place(): void {
    if (this.items.length === 0) {
      throw new Error('Cannot place empty order');
    }
    this.status = OrderStatus.Placed;
  }
}

// Application 層: UseCase
class PlaceOrderUseCase {
  constructor(
    private orderRepository: OrderRepository,
    private eventPublisher: EventPublisher
  ) {}

  async execute(orderId: OrderId): Promise<void> {
    const order = await this.orderRepository.findById(orderId);

    order.place();  // ビジネスロジックはDomainに

    await this.orderRepository.save(order);
    await this.eventPublisher.publish(new OrderPlaced(orderId));
  }
}
```

### ❌ Bad: 依存関係違反

```go
// ❌ Domain が Infrastructure に依存
package domain

import "gorm.io/gorm"  // ← 禁止！Domainが技術詳細を知っている

type User struct {
    gorm.Model  // ← ORM依存
    Email string
}
```

```typescript
// ❌ Controller にビジネスロジック
class UserController {
  async createUser(req: Request): Promise<Response> {
    // ビジネスロジックがここに ← 禁止！
    if (req.body.age < 18) {
      return { error: 'Too young' };
    }

    if (req.body.status === 'verified' && req.body.score > 100) {
      // 複雑な計算 ← これはDomain/UseCaseに配置すべき
    }

    await this.db.save(req.body);  // ← DB直接アクセス
  }
}
```

### ❌ Bad: 貧血ドメインモデル

```typescript
// ❌ getter/setter のみ（ビジネスロジックなし）
class User {
  private email: string;
  private status: string;

  getEmail(): string { return this.email; }
  setEmail(value: string): void { this.email = value; }

  getStatus(): string { return this.status; }
  setStatus(value: string): void { this.status = value; }
}

// ビジネスロジックがServiceに散在 ← アンチパターン
class UserService {
  activateUser(user: User): void {
    if (user.getStatus() === 'active') {
      throw new Error('Already active');
    }
    user.setStatus('active');
  }
}
```

### ✅ Good: リッチドメインモデル

```typescript
// ✅ ビジネスロジックを内包
class User {
  private status: UserStatus;

  activate(): void {
    if (this.status === UserStatus.Active) {
      throw new Error('Already active');
    }
    this.status = UserStatus.Active;
  }

  canPurchase(): boolean {
    return this.status === UserStatus.Active && !this.isSuspended();
  }
}
```

## チェックリスト

### レイヤー設計
- [ ] Domain 層は外部依存がないか
- [ ] 依存方向が外側→内側になっているか
- [ ] Repository IF は Domain 層に定義されているか
- [ ] UseCase は Domain のみに依存しているか
- [ ] Infrastructure は技術詳細のみを含むか

### ドメインモデリング
- [ ] ビジネスロジックが Domain/UseCase にあるか
- [ ] Entity にビジネスルールが実装されているか
- [ ] Value Object は不変か
- [ ] Aggregate は小さく保たれているか（1-3エンティティ）
- [ ] 他の Aggregate は ID で参照しているか

### 依存関係
- [ ] 循環依存がないか
- [ ] Controller は薄いか（入力変換・UseCase呼び出し・出力変換のみ）
- [ ] Domain に ORM/Framework の型が漏れていないか
- [ ] DI でテスト容易性が確保されているか

### データフロー
- [ ] Domain エンティティが外部に漏れていないか
- [ ] DTO で境界を越えているか
- [ ] トランザクション境界が適切か

## 出力形式

### 新規設計時
```
📋 **レイヤー構成**
- Domain: [エンティティ一覧]
- Application: [UseCase一覧]
- Infrastructure: [実装一覧]

🔄 **依存関係図**
[依存方向の図示]

📝 **実装ガイド**
- [優先順位付きタスク]
```

### リファクタリング時
```
🔴 **Critical**: ファイル:行 - 違反内容 - 修正案
🟡 **Warning**: ファイル:行 - 改善推奨 - リファクタ案
📊 **Summary**: Critical X件 / Warning Y件
```

## 関連ガイドライン

設計実施前に以下のガイドラインを参照:
- `~/.claude/guidelines/design/clean-architecture.md`
- `~/.claude/guidelines/design/domain-driven-design.md`
- `~/.claude/guidelines/common/code-quality-design.md`

## 外部知識ベース

最新のアーキテクチャベストプラクティス確認には context7 を活用:
- クリーンアーキテクチャ（Robert C. Martin）
- DDD（エリック・エヴァンス）
- SOLID原則
- アーキテクチャパターン

## プロジェクトコンテキスト

プロジェクト固有の設計情報を確認:
- serena memory からレイヤー構成・ドメインモデルを取得
- プロジェクトの標準的なディレクトリ構造を優先
- 既存の設計パターンとの一貫性を確認
- チームのユビキタス言語を適用
