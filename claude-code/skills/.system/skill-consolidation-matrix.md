# スキル統合マトリクス

## 統合完了済み

### レビュー系

| 旧スキル | 統合先 | 状態 |
|---------|--------|------|
| code-quality-review | comprehensive-review --focus=quality | 削除済み |
| security-error-review | comprehensive-review --focus=security | 削除済み |
| docs-test-review | comprehensive-review --focus=docs | 削除済み |

### 開発系

| 旧スキル | 統合先 | 状態 |
|---------|--------|------|
| go-backend | backend-dev --lang=go | 削除済み |
| typescript-backend | backend-dev --lang=typescript | 削除済み |

### インフラ系

| 旧スキル | 統合先 | 状態 |
|---------|--------|------|
| docker-troubleshoot | container-ops --platform=docker --mode=troubleshoot | 削除済み |
| dockerfile-best-practices | container-ops --platform=docker --mode=best-practices | 削除済み |
| kubernetes | container-ops --platform=kubernetes | 削除済み |

### コマンド

| 旧コマンド | 統合先 | 状態 |
|-----------|--------|------|
| quick-fix | /dev --quick | 削除済み |

## 現在のスキル一覧（19スキル）

### レビュー系（3スキル）

- **comprehensive-review** - 品質・セキュリティ・ドキュメント/テストの統合レビュー
- **uiux-review** - UI/UXレビュー（Material Design 3 + WCAG 2.2 AA）
- **ui-skills** - Tailwind CSS/motion/react特化のUI構築

### 開発系（5スキル）

- **backend-dev** - Go/TypeScript/Python/Rust対応バックエンド開発
- **react-best-practices** - Next.js/Reactパフォーマンス最適化
- **api-design** - REST/GraphQL設計原則
- **clean-architecture-ddd** - クリーンアーキテクチャ・DDD
- **grpc-protobuf** - gRPC/Protobuf開発

### インフラ系（3スキル）

- **container-ops** - Docker/Kubernetes/Podman対応コンテナ運用
- **terraform** - Terraform IaC設計
- **microservices-monorepo** - マイクロサービス・モノレポ設計

### ユーティリティ系（8スキル）

- **load-guidelines** - 技術スタック検出とガイドライン読み込み
- **ai-tools-sync** - リポジトリと~/.claude/間の設定ファイル同期
- **cleanup-enforcement** - 未使用コード・後方互換残骸の削除強制
- **techdebt** - 技術的負債検出とリファクタリング提案
- **mcp-setup-guide** - MCPサーバーセットアップ
- **session-mode** - セッションモード切替（strict/normal/fast）
- **context7** - ライブラリドキュメント取得
- **data-analysis** - SQL不要でDB/CSV分析

## 今後の統合候補

| 候補 | 統合案 | 優先度 |
|------|--------|--------|
| uiux-review + ui-skills | ui-review（mode=review/development） | 低 |
| api-design + grpc-protobuf | api-architecture（type=rest/graphql/grpc） | 低 |
| clean-architecture-ddd + microservices-monorepo | architecture-design | 低 |

これらは現状で十分機能しており、統合の緊急性は低い。
