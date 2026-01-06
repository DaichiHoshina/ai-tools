---
name: microservices-monorepo
description: マイクロサービス・モノレポ設計 - サービス分割、通信パターン、モノレポ構成
requires-guidelines:
  - common
---

# マイクロサービス・モノレポ設計

## 使用タイミング

- **サービス分割検討時（モノリスからの移行）**
- **新規マイクロサービス設計時（境界決定）**
- **モノレポ構成設計時（構造決定）**
- **サービス間通信の最適化時（パフォーマンス改善）**

## 設計パターン

### サービス分割戦略

#### サービス境界の決定
- **ビジネス機能**: 注文、在庫、配送、決済 etc.
- **DDD 境界づけられたコンテキスト**: ドメイン境界と一致
- **チーム構成**: Conway の法則（組織構造に従う）
- **データ所有**: 各サービスが独自の DB を持つ

#### サービスサイズ
- **小さすぎ ❌**: 過度な通信オーバーヘッド、管理コスト増
- **大きすぎ ❌**: モノリスに逆戻り、デプロイ独立性喪失
- **適切 ✅**: 1チームで管理可能、明確な責務境界

### 通信パターン

#### 同期通信
- **REST API**: シンプルな CRUD、人間可読
- **gRPC**: 高パフォーマンス、型安全、ストリーミング
- **GraphQL**: クライアント主導、柔軟なクエリ

#### 非同期通信
- **メッセージキュー**: Kafka, RabbitMQ, SQS
- **イベント駆動**: 疎結合、スケーラブル
- **Pub/Sub**: 1対多通信

#### アーキテクチャパターン
- **API Gateway**: 単一エントリポイント、認証、ルーティング
- **Service Mesh**: サービス間通信の制御（Istio, Linkerd）
- **Circuit Breaker**: 障害の連鎖防止、フォールバック
- **Saga**: 分散トランザクション、補償処理

### モノレポ構成

#### ディレクトリ構造
```
monorepo/
├── services/
│   ├── user-service/
│   ├── order-service/
│   └── payment-service/
├── packages/
│   ├── common-lib/
│   ├── proto/           # gRPC定義
│   └── types/           # 共有型定義
├── infrastructure/
│   ├── k8s/
│   └── terraform/
└── tools/
    └── scripts/
```

#### モノレポツール
- **Turborepo**: 高速ビルド、キャッシュ、並列実行
- **Nx**: 依存関係グラフ、affected コマンド
- **Lerna**: パッケージバージョニング
- **pnpm workspaces**: 効率的な依存管理

## 具体例

### ✅ Good: サービス境界（Go）

```go
// ❌ Bad: 1つの巨大サービス
user-service/
  - authentication
  - profile
  - notifications
  - billing
  - analytics

// ✅ Good: 適切な分割
auth-service/         # 認証専用
  - login, register, token管理

user-profile-service/ # プロフィール管理
  - CRUD, アバター

notification-service/ # 通知専用
  - email, push, SMS

billing-service/      # 課金専用
  - stripe連携、請求
```

### ✅ Good: イベント駆動通信（TypeScript）

```typescript
// ✅ 非同期イベントで疎結合
// order-service
class OrderService {
  async placeOrder(order: Order): Promise<void> {
    await this.orderRepository.save(order);

    // イベント発行（他サービスの実装を知らない）
    await this.eventBus.publish({
      type: 'OrderPlaced',
      orderId: order.id,
      userId: order.userId,
      amount: order.totalAmount,
    });
  }
}

// inventory-service（独立して動作）
class InventoryEventHandler {
  @Subscribe('OrderPlaced')
  async handleOrderPlaced(event: OrderPlacedEvent): Promise<void> {
    await this.inventoryService.reserveStock(event.orderId);
  }
}

// notification-service（独立して動作）
class NotificationEventHandler {
  @Subscribe('OrderPlaced')
  async handleOrderPlaced(event: OrderPlacedEvent): Promise<void> {
    await this.emailService.sendOrderConfirmation(event.userId);
  }
}
```

### ✅ Good: API Gateway パターン

```typescript
// api-gateway
class APIGateway {
  async getUserWithOrders(userId: string): Promise<UserWithOrders> {
    // 複数サービスを組み合わせてレスポンス
    const [user, orders] = await Promise.all([
      this.userService.getUser(userId),      // user-service
      this.orderService.getOrders(userId),   // order-service
    ]);

    return { user, orders };
  }
}
```

### ❌ Bad: サービス間の直接DB参照

```go
// ❌ order-service が user-service の DB を直接参照
package order

import "database/sql"

func GetOrderWithUser(orderID string) (*OrderWithUser, error) {
    // 他サービスのDBに直接接続 ← 禁止！
    userDB, _ := sql.Open("postgres", "user-service-db-url")

    // 強い結合、スキーマ変更で壊れる
    row := userDB.QueryRow("SELECT * FROM users WHERE id = $1", userID)
}
```

### ✅ Good: API 経由でアクセス

```go
// ✅ order-service が user-service の API を呼び出し
package order

type UserServiceClient interface {
    GetUser(ctx context.Context, userID string) (*User, error)
}

func (s *OrderService) GetOrderWithUser(orderID string) (*OrderWithUser, error) {
    order, _ := s.orderRepo.FindByID(orderID)

    // API経由で取得（疎結合）
    user, _ := s.userClient.GetUser(ctx, order.UserID)

    return &OrderWithUser{Order: order, User: user}, nil
}
```

### ❌ Bad: 同期通信の連鎖

```typescript
// ❌ 同期呼び出しの連鎖（レイテンシ増大）
// frontend → api-gateway → service-a → service-b → service-c
class ServiceA {
  async process(): Promise<void> {
    const b = await this.serviceB.call();  // 待機
    const c = await this.serviceC.call();  // 待機
    // レイテンシが累積
  }
}
```

### ✅ Good: 非同期処理

```typescript
// ✅ 非同期イベントで即座にレスポンス
class ServiceA {
  async process(): Promise<void> {
    // イベント発行して即座に完了
    await this.eventBus.publish('ProcessRequested', data);
    return;  // すぐ返す
  }
}

// 後続処理はイベント駆動
class ServiceB {
  @Subscribe('ProcessRequested')
  async handle(event): Promise<void> {
    // 非同期で処理
  }
}
```

### ✅ Good: モノレポ共通ライブラリ（TypeScript）

```typescript
// packages/common-lib/src/logger.ts
export class Logger {
  log(message: string): void {
    console.log(`[${new Date().toISOString()}] ${message}`);
  }
}

// services/user-service/src/index.ts
import { Logger } from '@monorepo/common-lib';

const logger = new Logger();
logger.log('User service started');

// services/order-service/src/index.ts
import { Logger } from '@monorepo/common-lib';  // 同じライブラリを使用

const logger = new Logger();
logger.log('Order service started');
```

## チェックリスト

### サービス分割
- [ ] サービス境界がビジネス機能と一致しているか
- [ ] 各サービスが独立してデプロイ可能か
- [ ] サービスサイズが適切か（小さすぎず大きすぎず）
- [ ] 各サービスが独自の DB を持つか
- [ ] サービス間の依存が最小化されているか

### 通信設計
- [ ] 同期/非同期の使い分けが適切か
- [ ] API は後方互換性を保つ設計か
- [ ] Circuit Breaker でフォールバック可能か
- [ ] タイムアウト設定が適切か
- [ ] リトライ処理が実装されているか

### データ管理
- [ ] Database per Service が守られているか
- [ ] 分散トランザクションが Saga パターンで実装されているか
- [ ] 結果整合性が許容できるか
- [ ] イベントソーシングが必要か検討したか

### モノレポ構成
- [ ] 共通ライブラリが適切に分離されているか
- [ ] ビルドキャッシュが効いているか
- [ ] 依存関係が明確か
- [ ] 循環依存がないか

### Kubernetes
- [ ] リソース limits/requests が設定されているか
- [ ] ヘルスチェック（liveness/readiness）が実装されているか
- [ ] HPA で自動スケールが設定されているか
- [ ] Service Mesh で通信が管理されているか

### 可観測性
- [ ] 構造化ログが実装されているか
- [ ] メトリクスが収集されているか
- [ ] 分散トレーシングが実装されているか
- [ ] 相関 ID でリクエスト追跡可能か

## 出力形式

### サービス分割設計時
```
📋 **サービス一覧**
- [サービス名]: [責務] - [DB] - [通信方式]

🔄 **サービス間通信**
[通信フロー図]

📊 **データフロー**
[データの流れ]

🚀 **デプロイ戦略**
[デプロイ方針]
```

### レビュー時
```
🔴 **Critical**: サービス名 - 違反内容 - 修正案
🟡 **Warning**: サービス名 - 改善推奨 - リファクタ案
📊 **Summary**: Critical X件 / Warning Y件
```

## 関連ガイドライン

設計実施前に以下のガイドラインを参照:
- `~/.claude/guidelines/design/microservices-kubernetes.md`
- `~/.claude/guidelines/design/clean-architecture.md`
- `~/.claude/guidelines/design/domain-driven-design.md`

## 外部知識ベース

最新のマイクロサービスベストプラクティス確認には context7 を活用:
- マイクロサービスパターン
- Kubernetes 公式ドキュメント
- Service Mesh（Istio, Linkerd）
- イベント駆動アーキテクチャ
- モノレポツール（Turborepo, Nx）

## プロジェクトコンテキスト

プロジェクト固有の設計情報を確認:
- serena memory からサービス構成・通信パターンを取得
- プロジェクトの標準的なサービス構造を優先
- 既存のマイクロサービスパターンとの一貫性を確認
- チームの技術スタック（Kubernetes, メッセージング）を考慮
