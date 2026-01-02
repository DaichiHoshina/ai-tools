# クリーンアーキテクチャ ガイドライン

> **目的**: フレームワーク非依存・テスト容易なソフトウェア設計

## 基本原則

| 原則 | 内容 |
|------|------|
| **依存性の方向** | 外側 → 内側（内側は外側を知らない） |
| **関心の分離** | レイヤーごとに責務を分離 |
| **フレームワーク独立** | ビジネスロジックは技術詳細から独立 |

---

## レイヤー構成

| レイヤー | 責務 | 含むもの | 依存先 |
|----------|------|----------|--------|
| **Domain** | ビジネスルール | Entity, ValueObject, Repository IF | なし |
| **Application / UseCase** | アプリケーションロジック | UseCase, ApplicationService, DTO | Domain のみ |
| **Interface / Presentation** | 入出力処理 | Controller, Presenter | Application, Domain |
| **Infrastructure** | 技術詳細 | Repository 実装, API Client, ORM | 全層可 |

---

## 依存性逆転の原則 (DIP)

| 要素 | 役割 | 例 |
|------|------|-----|
| **インターフェース** | 上位層で定義 | `UserRepository` (Domain) |
| **実装** | 下位層で実装 | `PostgresUserRepository` (Infrastructure) |
| **注入** | DI で接続 | 起動時に実装を注入 |

---

## ディレクトリ構成

| パターン | 構成例 | 特徴 |
|----------|--------|------|
| **機能ベース（推奨）** | `features/user/{domain,application,infrastructure}/` | 機能単位で分離、スケーラブル |
| **レイヤーベース** | `{domain,application,infrastructure}/` | レイヤー単位で分離、シンプル |

---

## データフロー

```
Controller (リクエスト→DTO) → UseCase (ビジネスロジック) → Repository (永続化) → Presenter (レスポンス)
```

**境界を越えるデータ**: DTO で受け渡し、Domain エンティティは外部に漏らさない

---

## テスト戦略

| レイヤー | テスト種別 | モック | 特徴 |
|----------|-----------|--------|------|
| **Domain** | 単体テスト | 不要 | ビジネスロジック検証 |
| **Application** | 単体テスト | Repository をモック | フロー検証 |
| **Infrastructure** | 統合テスト | 実 DB 使用 | 技術詳細検証 |

---

## ❌ アンチパターン vs ✅ ベストプラクティス

| ケース | ❌ NG | ✅ OK |
|--------|-------|-------|
| **フレームワーク依存** | Domain にフレームワーク固有コード | Infrastructure でフレームワーク使用 |
| **貫通型アーキテクチャ** | Controller → DB 直接アクセス | UseCase 経由でアクセス |
| **過剰な抽象化** | 全てにインターフェース | 必要な境界のみ抽象化 |
| **ビジネスロジック配置** | Controller に複雑なロジック | Domain / UseCase に集約 |
| **技術詳細** | UseCase でフレームワーク固有処理 | Infrastructure に隔離 |
| **テスト容易性** | DI なし | DI でテスト容易性確保 |
| **レイヤー境界** | 曖昧な境界 | 明確な境界を定義 |
