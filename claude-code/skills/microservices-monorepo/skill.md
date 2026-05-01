---
name: microservices-monorepo
description: マイクロサービス・モノレポ設計。サービス分割・通信パターン・モノレポ構成、設計時に使用
requires-guidelines:
  - common
  - clean-architecture
  - ddd
---

# microservices-monorepo - マイクロサービス・モノレポ設計

## 設計パターン

### サービス分割戦略

| 基準 | 説明 |
|------|------|
| ビジネス機能 | 注文、在庫、配送、決済 |
| DDD境界づけられたコンテキスト | ドメイン境界と一致 |
| チーム構成 | Conwayの法則（組織構造に従う） |
| データ所有 | 各サービスが独自DBを持つ |

**サービスサイズ**: 1チームで管理可能、明確な責務境界

### 通信パターン

| 種別 | パターン | 用途 |
|------|---------|------|
| 同期 | REST API | シンプルなCRUD |
| 同期 | gRPC | 高パフォーマンス、型安全 |
| 非同期 | メッセージキュー | Kafka, RabbitMQ, SQS |
| 非同期 | イベント駆動 | 疎結合、スケーラブル |

### アーキテクチャパターン

- **API Gateway**: 単一エントリポイント、認証、ルーティング
- **Service Mesh**: Istio, Linkerd
- **Circuit Breaker**: 障害連鎖防止
- **Saga**: 分散トランザクション

### モノレポ構成

```
monorepo/
├── services/           # 各サービス
├── packages/           # 共通ライブラリ、proto、types
├── infrastructure/     # k8s, terraform
└── tools/              # scripts
```

**ツール**: Turborepo, Nx, pnpm workspaces

---

## アンチパターン（禁止事項）

- **他サービスのDB直接参照**: サービス境界違反。スキーマ変更で破綻 → 必ず API 経由
- **同期呼び出しチェーン**: A→B→C→D の連鎖。障害連鎖の原因 → 非同期イベント駆動を検討
- **共有DB**: Database per Service 違反。独自DBを持たせる

> 実装例は `guidelines/design/microservices-kubernetes.md` を参照。

---

## チェックリスト

### サービス分割
- [ ] サービス境界がビジネス機能と一致
- [ ] 各サービスが独立デプロイ可能
- [ ] 各サービスが独自DBを持つ

### 通信設計
- [ ] 同期/非同期の使い分けが適切
- [ ] Circuit Breakerでフォールバック
- [ ] タイムアウト/リトライ設定

### データ管理
- [ ] Database per Service
- [ ] 分散トランザクションはSagaパターン

### 可観測性
- [ ] 構造化ログ
- [ ] 分散トレーシング
- [ ] 相関IDでリクエスト追跡

---

## 出力形式

通常ケース:

```
📋 **サービス一覧**
- [サービス名]: [責務] - [DB] - [通信方式]

🔄 **サービス間通信**
[通信フロー]

🔴 **Critical**: サービス名 - 違反内容 - 修正案
🟡 **Warning**: サービス名 - 改善推奨 - リファクタ案
```

ゼロ件・モノリス検出（マイクロサービス未適用時）:

```
📋 **サービス一覧**
> [WARN] 単一サービス（モノリス）と判定。マイクロサービス分割提案のみ出力

🔴 **Critical**: 0件
🟡 **Warning**: 0件（適用前のため判定対象なし）

### 分割提案
- 候補1: [機能A] を独立サービス化（理由: 独立スケーリング要件）
- 候補2: [機能B] を独立サービス化（理由: チーム所有権分離）
```

---

## 関連ガイドライン / Context7

- `guidelines/design/microservices-kubernetes.md`, `design/clean-architecture.md`
- Context7: `/vercel/turborepo`, `/nrwl/nx`, "saga pattern", "circuit breaker"
