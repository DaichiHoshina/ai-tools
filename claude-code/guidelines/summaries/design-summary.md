# 設計ガイドライン（サマリー版）

## 📚 詳細仕様一覧（design/）

| ファイル | 内容 |
|---------|------|
| `clean-architecture.md` | レイヤー設計、依存性逆転の原則 |
| `domain-driven-design.md` | DDD 戦略的・戦術的設計 |

---

## Clean Architecture

### レイヤー構成

| レイヤー | 責務 | 依存先 |
|----------|------|--------|
| **Domain** | ビジネスルール（Entity, ValueObject） | なし |
| **Application** | アプリケーションロジック（UseCase） | Domain のみ |
| **Interface** | 入出力処理（Controller, Presenter） | Application, Domain |
| **Infrastructure** | 技術詳細（Repository実装, ORM） | 全層可 |

### 基本原則

| 原則 | 内容 |
|------|------|
| **依存性の方向** | 外側 → 内側（内側は外側を知らない） |
| **関心の分離** | レイヤーごとに責務を分離 |
| **フレームワーク独立** | ビジネスロジックは技術詳細から独立 |

### 依存性逆転の原則 (DIP)

```
Interface定義: Domain層（例: UserRepository IF）
        ↑
実装: Infrastructure層（例: PostgresUserRepository）
```

---

## DDD（ドメイン駆動設計）

### 戦略的設計

| 概念 | 説明 |
|------|------|
| **境界づけられたコンテキスト** | ドメインを適切に分割（例: 注文/配送） |
| **ユビキタス言語** | チーム共通の用語を使用 |
| **コンテキストマップ** | コンテキスト間の関係性を定義 |

### 戦術的設計

| 要素 | 特徴 | 例 |
|------|------|-----|
| **Entity** | IDで区別、ライフサイクルあり | `User`, `Order` |
| **Value Object** | 不変、値で比較 | `Money`, `Email`, `Address` |
| **Aggregate** | 一貫性境界、ルート経由アクセス | `Order` (OrderItem含む) |
| **Repository** | 集約の永続化抽象 | `UserRepository` |
| **Domain Event** | 過去形、イミュータブル | `UserRegistered` |

### 実装パターン

| パターン | 用途 |
|----------|------|
| **Factory** | 複雑なオブジェクト生成 |
| **Specification** | ビジネスルールのオブジェクト化 |
| **Domain Service** | 複数エンティティにまたがるロジック |

---

## ディレクトリ構成

### 機能ベース（推奨）

```
src/
├── features/
│   ├── user/
│   │   ├── domain/        # Entity, ValueObject, Repository IF
│   │   ├── application/   # UseCase
│   │   ├── interface/     # Controller, DTO
│   │   └── infrastructure/# Repository実装
│   └── order/
└── shared/                # 共通機能
```

### レイヤーベース

```
src/
├── domain/        # 全ドメインのEntity, ValueObject
├── application/   # 全UseCase
├── interface/     # 全Controller
└── infrastructure/# 全Repository実装
```

---

## データフロー

```
Request → Controller → UseCase → Repository → Presenter → Response
           (DTO変換)  (ビジネス   (永続化)     (DTO変換)
                      ロジック)
```

---

## 注意点

| 項目 | 推奨 |
|------|------|
| **Aggregateサイズ** | 1-3エンティティに抑える |
| **Repositoryスコープ** | 集約単位（Entityごとではない） |
| **Domain Eventの命名** | 過去形（`UserRegistered`, `OrderPlaced`） |
| **ValueObjectの不変性** | 生成後は変更不可、変更は新規作成 |
