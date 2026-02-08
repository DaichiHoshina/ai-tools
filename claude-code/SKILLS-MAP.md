# スキル依存関係マップ（統合後）

全18スキルの依存関係と推奨組み合わせ（Phase2-5スキル統合完了）

> **関連ドキュメント**: [commands/](commands/) | [QUICKSTART.md](QUICKSTART.md) | [GLOSSARY.md](GLOSSARY.md)

## 統合スキル（3スキル）

### comprehensive-review
- **パラメータ**: `--focus={quality|security|docs|all}`（デフォルト: all）
- **requires-guidelines**: common, typescript
- **用途**: 包括的コードレビュー - 品質・セキュリティ・ドキュメント/テストを統合評価
- **統合前**: code-quality-review, security-error-review, docs-test-review（廃止通知済み）

### backend-dev
- **パラメータ**: `--lang={auto|go|typescript|python|rust}`（デフォルト: auto）
- **requires-guidelines**: common + 言語別（golang, typescript, python, rust）
- **用途**: バックエンド開発 - 多言語対応、自動検出
- **統合前**: go-backend, typescript-backend（廃止通知済み）

### container-ops
- **パラメータ**: 
  - `--platform={auto|docker|kubernetes|podman}`（デフォルト: auto）
  - `--mode={auto|troubleshoot|best-practices|deploy}`（デフォルト: auto）
- **requires-guidelines**: common + kubernetes（platform=kubernetesの場合）
- **用途**: コンテナ運用 - Docker/Kubernetes/Podman対応
- **統合前**: docker-troubleshoot, kubernetes（廃止通知済み）

## レビュー系（3スキル）

### comprehensive-review
（上記参照）

### uiux-review
- **requires-guidelines**: ui-ux, nextjs-react
- **often-used-with**: ui-skills, react-best-practices
- **用途**: Material Design 3 + WCAG 2.2 AA + Nielsen 10原則で実装に直結するレビュー

### ui-skills
- **requires-guidelines**: nextjs-react, tailwind
- **often-used-with**: uiux-review, react-best-practices
- **用途**: Tailwind CSS/motion/react特化のエージェント向けUI構築制約

## 開発系（5スキル）

### backend-dev
（上記参照）

### react-best-practices
- **requires-guidelines**: nextjs-react
- **often-used-with**: ui-skills, uiux-review
- **用途**: Vercel React/Next.jsパフォーマンス最適化 - 45ルール8カテゴリ、ウォーターフォール排除からバンドル最適化まで

### api-design
- **requires-guidelines**: common
- **often-used-with**: backend-dev, grpc-protobuf
- **用途**: REST/GraphQL設計原則、バージョニング、エラーハンドリング、ドキュメント

### clean-architecture-ddd
- **requires-guidelines**: clean-architecture, ddd
- **often-used-with**: backend-dev, microservices-monorepo
- **用途**: レイヤー設計、ドメインモデリング、依存関係管理

### grpc-protobuf
- **requires-guidelines**: golang, common
- **often-used-with**: backend-dev, api-design, microservices-monorepo
- **用途**: proto定義、コード生成、バックエンド実装のワークフロー

## インフラ系（4スキル）

### container-ops
（上記参照）

### dockerfile-best-practices
- **requires-guidelines**: なし
- **often-used-with**: container-ops
- **用途**: マルチステージビルド、キャッシュ最適化、セキュリティ強化、イメージサイズ最小化の指針

### terraform
- **requires-guidelines**: terraform, common
- **often-used-with**: container-ops
- **用途**: モジュール設計、状態管理、セキュリティベストプラクティス

### microservices-monorepo
- **requires-guidelines**: microservices-kubernetes, common
- **often-used-with**: container-ops, clean-architecture-ddd, grpc-protobuf
- **用途**: サービス分割、通信パターン、モノレポ構成

## ユーティリティ（8スキル）

### load-guidelines
- **requires-guidelines**: なし
- **often-used-with**: すべてのスキル（前提として機能）
- **用途**: プロジェクトの技術スタックを検出し、必要なガイドラインのみをセッションに適用。トークン節約。

### ai-tools-sync
- **requires-guidelines**: なし
- **often-used-with**: なし
- **用途**: リポジトリと~/.claude/間の設定ファイル同期。to-local/from-local/diffモード。

### cleanup-enforcement
- **requires-guidelines**: common
- **often-used-with**: comprehensive-review, すべての開発系スキル
- **用途**: 後方互換残骸・未使用コード・進捗コメントを徹底削除

### mcp-setup-guide
- **requires-guidelines**: なし
- **often-used-with**: なし（初回セットアップのみ）
- **用途**: Claude Code向けMCPサーバーのセットアップ・トラブルシュート

### session-mode
- **requires-guidelines**: なし
- **often-used-with**: なし（セッション設定）
- **用途**: strict/normal/fast でGuard関手の動作を変更。Serena Memoryで状態永続化。

### context7
- **requires-guidelines**: なし
- **often-used-with**: backend-dev, react-best-practices
- **用途**: Context7 API経由でライブラリドキュメント取得

### data-analysis
- **requires-guidelines**: common
- **often-used-with**: なし
- **用途**: SQL自動生成・BigQuery/PostgreSQL/MySQL/CSV分析

### techdebt
- **requires-guidelines**: common
- **often-used-with**: cleanup-enforcement
- **用途**: 重複コード・DRY違反検出とリファクタリング提案

---

## 統合サマリー

| カテゴリ | 統合前 | 統合後 | 削減数 |
|---------|-------|--------|-------|
| レビュー系 | 5 | 3 | -2 |
| 開発系 | 6 | 5 | -1 |
| インフラ系 | 5 | 4 | -1 |
| ユーティリティ | 8 | 8 | 0 |
| **合計** | **24** | **20** | **-4** |

**実質的な機能数**: パラメータ化により14独立機能（comprehensive-review=3観点、backend-dev=4言語、container-ops=3プラットフォーム×3モード）

---

## 依存関係統計

### guidelines別スキル数

| ガイドライン | 依存スキル数 |
|-------------|-------------|
| common | 10 |
| typescript | 2 |
| golang | 2 |
| nextjs-react | 3 |
| kubernetes | 1 |
| terraform | 1 |
| clean-architecture | 1 |
| ddd | 1 |
| ui-ux | 1 |
| tailwind | 1 |
| microservices-kubernetes | 1 |

### 推奨組み合わせパターン

#### フルスタックレビュー
```bash
/skill comprehensive-review --focus=all  # 全観点レビュー
```

#### バックエンド開発（Go）
```bash
/skill backend-dev --lang=go
/skill backend-dev + clean-architecture-ddd  # 設計重視
/skill backend-dev + api-design  # API開発
```

#### バックエンド開発（TypeScript）
```bash
/skill backend-dev --lang=typescript
/skill backend-dev + api-design
```

#### React/Next.js開発
```bash
/skill react-best-practices + ui-skills + uiux-review
```

#### コンテナトラブルシューティング
```bash
/skill container-ops --platform=docker --mode=troubleshoot
/skill container-ops --platform=kubernetes --mode=troubleshoot
```

#### インフラ・Kubernetes
```bash
/skill container-ops --platform=kubernetes + dockerfile-best-practices
/skill container-ops + terraform  # IaC統合
```

---

## 使用ガイド

### スキル選択フローチャート

```
タスク開始
  ↓
[レビュー系?] → Yes → /skill comprehensive-review
  ↓ No
[技術スタック検出済み?] → No → /load-guidelines実行
  ↓ Yes
[問題タイプは?]
  ├ バックエンド開発 → backend-dev（言語自動検出）
  ├ コンテナ運用 → container-ops（プラットフォーム自動検出）
  ├ API開発 → api-design
  ├ UI/UX → uiux-review or ui-skills
  ├ インフラ → container-ops, dockerfile-best-practices, terraform
  └ エラー・障害 → container-ops --mode=troubleshoot, comprehensive-review --focus=security
```

### 自動推奨の優先順位

1. **エラーログ検出**（最優先、問題解決）
2. **ファイルパス検出**（変更箇所から推論）
3. **Git状態検出**（ブランチ名・コミット履歴）
4. **キーワード検出**（プロンプト内容）

user-prompt-submit.shが上記順序で検出し、systemMessageで推奨スキルを表示。

---

## 廃止スキル（後方互換性維持）

以下のスキルは統合され、廃止通知が追加されています。detect-from-*.shが自動的に新スキル名+パラメータに変換します。

### レビュー系
- **code-quality-review** → `comprehensive-review --focus=quality`
- **security-error-review** → `comprehensive-review --focus=security`
- **docs-test-review** → `comprehensive-review --focus=docs`

### 開発系
- **go-backend** → `backend-dev --lang=go`
- **typescript-backend** → `backend-dev --lang=typescript`

### インフラ系
- **docker-troubleshoot** → `container-ops --platform=docker --mode=troubleshoot`
- **kubernetes** → `container-ops --platform=kubernetes`

---

## マイグレーションガイド

### 旧スキル名の使用（後方互換性）

```bash
# 自動変換される（非推奨だが動作する）
/skill go-backend
→ /skill backend-dev + BACKEND_LANG=go

/skill code-quality-review
→ /skill comprehensive-review + REVIEW_FOCUS=quality

/skill docker-troubleshoot
→ /skill container-ops + CONTAINER_PLATFORM=docker + CONTAINER_MODE=troubleshoot
```

### 推奨される新しい使用方法

```bash
# 明示的パラメータ指定
/skill backend-dev --lang=go
/skill comprehensive-review --focus=quality
/skill container-ops --platform=docker --mode=troubleshoot

# 自動検出（推奨）
/skill backend-dev  # .goファイルを変更している場合
/skill comprehensive-review  # デフォルトで全観点
/skill container-ops  # エラーログから自動検出
```

---

## 参照

- [QUICKSTART.md](QUICKSTART.md): 新規ユーザー向けガイド
- [GLOSSARY.md](GLOSSARY.md): 用語集
- [commands/](commands/): コマンド定義
- [skills/](skills/): スキル定義
