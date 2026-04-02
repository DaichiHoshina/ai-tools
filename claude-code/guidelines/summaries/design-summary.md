# 設計ガイドライン（サマリー版）

## 詳細仕様（design/）

| ファイル | 内容 |
|---------|------|
| `clean-architecture.md` | レイヤー設計、依存性逆転の原則 |
| `domain-driven-design.md` | DDD戦略的・戦術的設計 |

## Clean Architecture

| レイヤー | 責務 | 依存先 |
|----------|------|--------|
| **Domain** | ビジネスルール（Entity, ValueObject） | なし |
| **Application** | アプリケーションロジック（UseCase） | Domain のみ |
| **Interface** | 入出力処理（Controller, Presenter） | Application, Domain |
| **Infrastructure** | 技術詳細（Repository実装, ORM） | 全層可 |

依存方向: 外側→内側。内側は外側を知らない。Interface定義はDomain層、実装はInfrastructure層。

## DDD

### 戦略的設計

境界づけられたコンテキスト、ユビキタス言語、コンテキストマップ

### 戦術的設計

| 要素 | 特徴 |
|------|------|
| **Entity** | IDで区別、ライフサイクルあり |
| **Value Object** | 不変、値で比較 |
| **Aggregate** | 一貫性境界、1-3エンティティ、ルート経由アクセス |
| **Repository** | 集約単位の永続化抽象 |
| **Domain Event** | 過去形命名、イミュータブル |
