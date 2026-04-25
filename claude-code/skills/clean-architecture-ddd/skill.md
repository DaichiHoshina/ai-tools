---
name: clean-architecture-ddd
description: クリーンアーキテクチャ・DDD設計 - レイヤー設計、ドメインモデリング、依存関係管理。設計判断時に使用
requires-guidelines:
  - common
  - clean-architecture
  - ddd
---

# clean-architecture-ddd - クリーンアーキテクチャ・DDD設計

## 使用タイミング

- 新規プロジェクト設計時
- 既存システムのリファクタリング時
- ドメインモデリング時

---

## レイヤー構成

```
依存方向: 外側 → 内側のみ

┌─────────────────────────────────────┐
│  Infrastructure (DB, API, Framework)│ ← 最外部
├─────────────────────────────────────┤
│  Interface (Controller, Presenter)  │ ← ユーザーIF層
├─────────────────────────────────────┤
│  Application (UseCase, Service)     │ ← ビジネスフロー
├─────────────────────────────────────┤
│  Domain (Entity, ValueObject, Repo) │ ← 最内部（依存なし）
└─────────────────────────────────────┘
```

## DDD戦術パターン

| パターン | 責務 | 配置層 |
|---------|------|--------|
| Entity | ID識別、ライフサイクル、ビジネスロジック | Domain |
| Value Object | 不変、値比較、副作用なし | Domain |
| Aggregate | 一貫性境界、ルートエンティティ | Domain |
| Repository | IF=Domain / 実装=Infra | Domain/Infra |
| UseCase | アプリケーション固有ロジック | Application |
| Domain Event | 過去形命名、疎結合 | Domain |

---

## アンチパターン（禁止事項）

- **Domain → Infrastructure 依存**（例: `gorm.Model` を Domain に埋め込む）: DB技術への依存。ID/CreatedAt等は自前で定義
- **貧血ドメインモデル**: getter/setterのみの Entity。ビジネスロジックを Entity/UseCase に置く
- **Repository IF を Infra に配置**: IF は必ず Domain 層に定義

> 実装例は `guidelines/design/clean-architecture.md` を参照。

---

## チェックリスト

### レイヤー設計
- [ ] Domain層は外部依存なし
- [ ] 依存方向が外側→内側
- [ ] Repository IFはDomain層に定義

### ドメインモデリング
- [ ] ビジネスロジックがDomain/UseCaseにある
- [ ] Entityにビジネスルール実装
- [ ] Value Objectは不変
- [ ] Aggregateは小さく（1-3エンティティ）

### 依存関係
- [ ] 循環依存なし
- [ ] Controllerは薄い（入力変換→UseCase→出力変換）
- [ ] DomainにORM/Framework型が漏れていない

---

## 出力形式

```
📋 **レイヤー構成**
- Domain: [エンティティ一覧]
- Application: [UseCase一覧]
- Infrastructure: [実装一覧]

🔴 **Critical**: ファイル:行 - 違反内容 - 修正案
🟡 **Warning**: ファイル:行 - 改善推奨 - リファクタ案
```

---

## 関連ガイドライン / Context7

- `guidelines/design/clean-architecture.md`, `design/domain-driven-design.md`
- Context7: "repository pattern", "dependency injection", "aggregate root", "value object immutable"
