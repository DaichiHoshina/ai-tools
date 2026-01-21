# スキル依存関係マップ

全22スキルの依存関係（requires-guidelines）と推奨組み合わせ（often-used-with）を可視化。

## レビュー系（5スキル）

### code-quality-review
- **requires-guidelines**: common, typescript
- **often-used-with**: security-error-review, docs-test-review
- **用途**: アーキテクチャ、コード臭、パフォーマンス、型安全性を統合評価

### security-error-review
- **requires-guidelines**: common
- **often-used-with**: code-quality-review
- **用途**: OWASP Top 10、エラー処理、ログ管理を統合評価

### docs-test-review
- **requires-guidelines**: common
- **often-used-with**: code-quality-review
- **用途**: コメント品質、API仕様、テストの意味、カバレッジを統合評価

### uiux-review
- **requires-guidelines**: ui-ux, nextjs-react
- **often-used-with**: ui-skills, code-quality-review
- **用途**: Material Design 3 + WCAG 2.2 AA + Nielsen 10原則で実装に直結するレビュー

### ui-skills
- **requires-guidelines**: nextjs-react, tailwind
- **often-used-with**: uiux-review, react-best-practices
- **用途**: Tailwind CSS/motion/react特化のエージェント向けUI構築制約

## 開発系（6スキル）

### go-backend
- **requires-guidelines**: golang, common
- **often-used-with**: grpc-protobuf, api-design
- **用途**: Goイディオム、並行処理、エラーハンドリング、テスト

### typescript-backend
- **requires-guidelines**: typescript, common
- **often-used-with**: api-design, clean-architecture-ddd
- **用途**: 型安全、Node.js/Deno/Bun、フレームワーク活用

### react-best-practices
- **requires-guidelines**: nextjs-react
- **often-used-with**: ui-skills, uiux-review
- **用途**: Vercel React/Next.jsパフォーマンス最適化 - 45ルール8カテゴリ、ウォーターフォール排除からバンドル最適化まで

### api-design
- **requires-guidelines**: common
- **often-used-with**: go-backend, typescript-backend, grpc-protobuf
- **用途**: REST/GraphQL設計原則、バージョニング、エラーハンドリング、ドキュメント

### clean-architecture-ddd
- **requires-guidelines**: clean-architecture, ddd
- **often-used-with**: typescript-backend, go-backend, microservices-monorepo
- **用途**: レイヤー設計、ドメインモデリング、依存関係管理

### grpc-protobuf
- **requires-guidelines**: golang, common
- **often-used-with**: go-backend, api-design, microservices-monorepo
- **用途**: proto定義、コード生成、バックエンド実装のワークフロー

## インフラ系（5スキル）

### dockerfile-best-practices
- **requires-guidelines**: なし
- **often-used-with**: kubernetes, docker-troubleshoot
- **用途**: マルチステージビルド、キャッシュ最適化、セキュリティ強化、イメージサイズ最小化の指針

### kubernetes
- **requires-guidelines**: kubernetes, common
- **often-used-with**: dockerfile-best-practices, microservices-monorepo, terraform
- **用途**: デプロイメント、スケーリング、ネットワーキング、セキュリティ

### terraform
- **requires-guidelines**: terraform, common
- **often-used-with**: kubernetes
- **用途**: モジュール設計、状態管理、セキュリティベストプラクティス

### microservices-monorepo
- **requires-guidelines**: microservices-kubernetes, common
- **often-used-with**: kubernetes, clean-architecture-ddd, grpc-protobuf
- **用途**: サービス分割、通信パターン、モノレポ構成

### docker-troubleshoot
- **requires-guidelines**: なし
- **often-used-with**: dockerfile-best-practices
- **用途**: lima/Docker Desktop接続エラー、コンテナ起動失敗の診断・解決

## ユーティリティ（6スキル）

### load-guidelines
- **requires-guidelines**: なし
- **often-used-with**: すべてのスキル（前提として機能）
- **用途**: プロジェクトの技術スタックを検出し、必要なガイドラインのみをセッションに適用。トークン節約。

### ai-tools-sync
- **requires-guidelines**: なし
- **often-used-with**: guideline-maintenance
- **用途**: リポジトリと~/.claude/間の設定ファイル同期。to-local/from-local/diffモード。

### cleanup-enforcement
- **requires-guidelines**: common
- **often-used-with**: code-quality-review, すべての開発系スキル
- **用途**: 後方互換残骸・未使用コード・進捗コメントを徹底削除

### guideline-maintenance
- **requires-guidelines**: なし
- **often-used-with**: ai-tools-sync
- **用途**: 最新ドキュメントからClaude向け実践的レシピへ変換・更新

### mcp-setup-guide
- **requires-guidelines**: なし
- **often-used-with**: なし（初回セットアップのみ）
- **用途**: Claude Code向けMCPサーバーのセットアップ・トラブルシュート

### session-mode
- **requires-guidelines**: なし
- **often-used-with**: なし（セッション設定）
- **用途**: strict/normal/fast でGuard関手の動作を変更。Serena Memoryで状態永続化。

## 依存関係統計

### guidelines別スキル数

| ガイドライン | 依存スキル数 |
|-------------|-------------|
| common | 13 |
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

#### フルスタックレビュー（3スキル）
- code-quality-review + security-error-review + docs-test-review

#### フロントエンド開発（2-3スキル）
- react-best-practices + ui-skills
- react-best-practices + ui-skills + uiux-review（デザイン重視）

#### バックエンド開発（2-3スキル）
- go-backend + api-design
- typescript-backend + api-design
- go-backend + grpc-protobuf + api-design（マイクロサービス）

#### インフラ・Kubernetes（2-3スキル）
- kubernetes + dockerfile-best-practices
- kubernetes + terraform
- microservices-monorepo + kubernetes + grpc-protobuf（マイクロサービスフル）

## 使用ガイド

### `/review` コマンド時の選択基準

| 問題タイプ | スキル |
|-----------|--------|
| 設計・構造・複雑度・パフォーマンス・型 | code-quality-review |
| セキュリティ・エラー処理 | security-error-review |
| ドキュメント・テスト | docs-test-review |
| UI/UX（汎用） | uiux-review |
| Tailwind/React特化UI制約 | ui-skills |

### `/dev` コマンド時の選択基準

1. **load-guidelines** で技術スタック検出
2. 検出結果に基づき、開発系スキルを自動選択：
   - Go検出 → go-backend
   - TypeScript検出 → typescript-backend
   - React/Next.js検出 → react-best-practices
3. 設計重視の場合は追加：
   - clean-architecture-ddd（DDD/レイヤー設計）
   - api-design（API設計）

---

## スキル推奨組み合わせ

### よくあるパターン

#### フルスタックレビュー
```bash
/review  # 自動的に以下を選択:
# - code-quality-review（設計・品質）
# - security-error-review（セキュリティ）
# - docs-test-review（ドキュメント・テスト）
```

#### Go開発
- **go-backend** + **clean-architecture-ddd**
- gRPC使用時: + **grpc-protobuf**
- API設計: + **api-design**

#### React/Next.js開発
- **react-best-practices** + **ui-skills** + **uiux-review**
- Tailwind使用時: ui-skillsが自動適用

#### インフラ開発
- **dockerfile-best-practices** + **kubernetes** + **terraform**
- トラブルシューティング: + **docker-troubleshoot**

#### マイクロサービス
- **microservices-monorepo** + **kubernetes** + **api-design** + **grpc-protobuf**

### スキル選択フローチャート

```
タスク開始
  ↓
[レビュー系?] → Yes → /review（動的Skill選択）
  ↓ No
[技術スタック検出済み?] → No → /load-guidelines実行
  ↓ Yes
[問題タイプは?]
  ├ 設計・リファクタ → clean-architecture-ddd
  ├ API開発 → api-design
  ├ UI/UX → uiux-review or ui-skills
  ├ インフラ → dockerfile-best-practices, kubernetes, terraform
  └ エラー・障害 → docker-troubleshoot, security-error-review
```

### 自動推奨の優先順位

1. **エラーログ検出**（最優先、問題解決）
2. **ファイルパス検出**（変更箇所から推論）
3. **Git状態検出**（ブランチ名・コミット履歴）
4. **キーワード検出**（プロンプト内容）

user-prompt-submit.shが上記順序で検出し、systemMessageで推奨スキルを表示。
