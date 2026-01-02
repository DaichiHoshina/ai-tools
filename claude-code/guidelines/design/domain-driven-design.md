# DDD (ドメイン駆動設計) ガイドライン

> **目的**: ビジネスロジックを中心としたソフトウェア設計

## 基本原則

| 原則 | 内容 |
|------|------|
| **ドメインモデル中心** | ビジネスルールをコードで表現 |
| **ユビキタス言語** | チーム共通の用語を使用 |
| **境界づけられたコンテキスト** | ドメインを適切に分割 |

---

## 戦略的設計

### 境界づけられたコンテキスト (Bounded Context)

- 各コンテキストは独自のドメインモデルを持つ
- コンテキスト間は明確なインターフェースで連携
- 例: 「注文」と「配送」は別コンテキスト

### コンテキストマップ

| パターン | 関係性 | 使用例 |
|----------|--------|--------|
| **Shared Kernel** | 共有カーネル | 共通の基盤コード（慎重に使用） |
| **Customer-Supplier** | 上流・下流 | 注文システム → 在庫システム |
| **Anticorruption Layer** | 防腐層 | 外部システムとの変換層 |

---

## 戦術的設計

| 要素 | 特徴 | 例 | 注意点 |
|------|------|-----|--------|
| **Entity** | ID で区別、ライフサイクルあり、ビジネスロジック内包 | `User`, `Order` | データ構造でなく振る舞いを持つ |
| **Value Object** | 不変、値で比較、副作用なし | `Money`, `Email`, `Address` | 生成後は変更不可 |
| **Aggregate** | 一貫性境界、ルートエンティティ経由アクセス | `Order` (OrderItem を含む) | 小さく保つ（1-3 エンティティ） |
| **Repository** | 集約の永続化抽象、IF は Domain 層 | `UserRepository` | DB 詳細は Infrastructure 層 |
| **Domain Event** | 過去形、イミュータブル、疎結合 | `UserRegistered`, `OrderPlaced` | コンテキスト間通信に活用 |

---

## 実装パターン

| パターン | 用途 | 例 |
|----------|------|-----|
| **Factory** | 複雑なオブジェクト生成、不変条件保証 | `UserFactory.create()` |
| **Specification** | ビジネスルールをオブジェクト化、条件の組み合わせ | `IsAdultSpecification` |

---

## レイヤー構成

| レイヤー | 責務 | 依存先 |
|----------|------|--------|
| **Domain** | Entity, ValueObject, Repository IF, Domain Event | なし |
| **Application** | UseCase, DTO | Domain のみ |
| **Infrastructure** | Repository 実装, 外部 API | 全層可 |

> 詳細は `clean-architecture.md` 参照

---

## 命名規則

| 要素 | 形式 | 例 |
|------|------|-----|
| **エンティティ** | 名詞 | `User`, `Order`, `Product` |
| **値オブジェクト** | ドメイン用語 | `Money`, `Email`, `OrderId` |
| **ドメインイベント** | 過去形 | `UserRegistered`, `OrderCompleted` |
| **リポジトリ** | `{Aggregate}Repository` | `UserRepository` |

---

## テスト戦略

| レイヤー | テスト種別 | 特徴 |
|----------|-----------|------|
| **Domain** | 単体テスト、モック不要 | ビジネスロジック検証 |
| **Application** | Repository モック、フロー検証 | ユースケース検証 |

---

## ❌ アンチパターン vs ✅ ベストプラクティス

| ケース | ❌ NG | ✅ OK |
|--------|-------|-------|
| **ドメインモデル** | getter/setter のみ（貧血ドメイン） | ビジネスロジックを内包 |
| **集約サイズ** | 1つの集約に多数のエンティティ | 小さな集約 + ID 参照 |
| **Domain Service** | 全てを Domain Service に | Entity / VO にロジック配置 |
| **複数エンティティ跨ぎ** | Domain Service に実装 | UseCase 層で調整 |
| **技術詳細** | Domain に混入 | Infrastructure に隔離 |
| **トランザクション境界** | 集約を超えた変更 | 集約単位で完結 |
| **不変条件** | 無視 | 常に満たす |
| **言語** | 技術用語中心 | ユビキタス言語をコードに反映 |
| **イベント** | 密結合 | ドメインイベントで疎結合 |
