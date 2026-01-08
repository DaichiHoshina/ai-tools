# ai-tools リポジトリ固有設定

> **注意**: 共通設定は `~/.claude/CLAUDE.md` を参照。このファイルはリポジトリ固有の情報のみ。

<!-- 🔒 PROTECTED SECTION - DO NOT MODIFY OR DELETE -->
<!-- このセクション（返信フォーマット〜9原則）は自動編集・削除禁止 -->
<!-- 変更はユーザーの明示的な指示がある場合のみ許可 -->

## 返信フォーマット（必須）🔒

> **重要**: 毎回の返信冒頭に以下を出力すること

フォーマット: `#N | 📁 ディレクトリ名 | 🌿 branch | guidelines(言語) | skill(スキル名)`

例:
- `#1 | 📁 ai-tools | 🌿 main | guidelines(go,ts) | skill(none)`
- `#2 | 📁 my-app | 🌿 feature/auth | guidelines(none) | skill(docker-troubleshoot)`

### 9原則 🔒

1. **kenron**: 圏論的思考法を適用（Guard関手・3層分類で操作の安全性を判断）
2. **mem**: serena memory を読み込み・更新
3. **serena**: /serena でコマンド実行
4. **guidelines**: load-guidelines で言語ガイドライン読み込み（検出言語を表示）
5. **自動処理禁止**: 整形・lint・ビルド・テスト修正を勝手に行わない
6. **完了通知**: タスク完了時に `afplay ~/notification.mp3` 実行
7. **型安全**: any禁止、as控える
8. **コマンド提案**: 適切なコマンドを提案（/dev, /review, /plan 等）
9. **確認済**: 不明点は確認してから実行

<!-- 🔒 END PROTECTED SECTION -->

## Planモード活用（Boris推奨）🔒

> **重要**: ほとんどのセッションは Plan モード（Shift + Tab 2回）から開始すること

- 目的がPRなら、Plan モードで計画を詰める
- 納得できる計画 → auto-accept edits モードで一発（1-shot）で仕上げ
- **良い計画は本当に重要！**（Boris: Claude Code開発者）

### 使い分け
- Plan モード → 複数ファイル修正、新機能実装、リファクタリング
- 通常モード → 1-2ファイルの単純修正、質問応答

## 概要

Claude Code の設定を一元管理するリポジトリ。

## コマンド（17個）

| コマンド | 説明 |
|---------|------|
| `/prd` | PRD作成（対話式要件整理 + 10視点レビュー） |
| `/dev` | 実装（Agent階層 or 直接実行） |
| `/review` | コードレビュー（Codex使用） |
| `/plan` | 設計・計画 |
| `/refactor` | リファクタリング |
| `/test` | テスト作成 |
| `/debug` | デバッグ支援 |
| `/docs` | ドキュメント作成 |
| `/commit` | コミットメッセージ提案 |
| `/commit-push-pr` | コミット・プッシュ・PR作成を一括実行（Boris流） |
| `/flow` | ワークフロー自動化（タスクタイプ判定→最適ワークフロー実行） |
| `/explore` | 並列探索 |
| `/retrospective` | 振り返り（過去分析→改善提案） |
| `/serena` | Serena MCP操作 |
| `/serena-refresh` | Serenaデータ更新 |
| `/reload` | CLAUDE.md再読込 |
| `/kenron` | 圏論的思考法ロード（Guard関手・3層分類） |

## スキル（21個）

**レビュー系**: code-quality-review, security-error-review, docs-test-review, uiux-review（4個、旧9個を統合）

**開発系**: go-backend, typescript-backend, react-nextjs, api-design, clean-architecture-ddd, grpc-protobuf

**インフラ系**: dockerfile-best-practices, kubernetes, terraform, microservices-monorepo, docker-troubleshoot

**ユーティリティ**: load-guidelines, ai-tools-sync, cleanup-enforcement, guideline-maintenance, mcp-setup-guide, session-mode

**退避中** (`skills-archive/`): ecommerce, shopify-app-bridge, gitlab-cicd, review-skills（旧レビュー系9個）

## エージェント（7個）

| エージェント | 説明 |
|-------------|------|
| `po-agent` | 戦略決定・Worktree管理 |
| `manager-agent` | タスク分割・配分計画 |
| `developer-agent` | 実装担当（dev1-4） |
| `explore-agent` | 探索・分析担当（explore1-4） |
| `code-simplifier` | コード簡素化専門 |
| `verify-app` | アプリ検証専門 |
| `workflow-orchestrator` | ワークフロー自動化 |

## フック（7個）

| フック | タイミング | 用途 |
|--------|-----------|------|
| session-start | セッション開始時 | Serena接続・ガイドライン確認 |
| user-prompt-submit | プロンプト送信時 | 技術スタック検出・スキル推奨 |
| pre-tool-use | ツール実行前 | 自動処理禁止チェック |
| post-tool-use | ツール実行後 | 自動フォーマット（Go/TypeScript） |
| pre-compact | コンパクション前 | 自動バックアップ |
| stop | 停止時 | 統計保存 |
| session-end | セッション終了時 | 完了通知・Git変更検出 |

## コマンド・スキル・ガイドラインの関係

```
コマンド（入口）→ スキル（専門知識）→ ガイドライン（詳細仕様）
```

### 選択フロー

```
タスク開始
  ↓
[コマンド実行?] → Yes → コマンドが自動選択
  ↓ No
[技術スタック不明?] → Yes → load-guidelines実行
  ↓ No
[レビュー系?] → Yes → 問題タイプから*-review選択
  ↓ No
技術スタック別スキル使用
```

### コマンド → スキル対応表

| コマンド | 自動適用スキル | 備考 |
|----------|----------------|------|
| `/dev` | load-guidelines | 技術スタック検出後、適切なスキル適用 |
| `/review` | （状況判断） | 問題タイプに応じて*-review系を1-3個選択 |
| `/refactor` | load-guidelines, clean-architecture-ddd | アーキテクチャ原則に基づく |
| `/debug` | （エラー種別で判断） | Docker系→docker-troubleshoot等 |
| `/test` | load-guidelines, test-quality-review | テスト品質基準を適用 |

### レビュースキル選択基準（統合版）

| 問題タイプ | 使用スキル |
|-----------|-----------|
| 設計・構造・複雑度・パフォーマンス・型安全性 | code-quality-review（4-in-1統合） |
| セキュリティ・エラー処理 | security-error-review（2-in-1統合） |
| ドキュメント・テスト | docs-test-review（2-in-1統合） |
| UI/UX | uiux-review |

**統合の詳細**:
- `code-quality-review`: architecture + code-smell + performance + type-safety
- `security-error-review`: security + error-handling
- `docs-test-review`: documentation + test-quality
- `uiux-review`: uiux-design を改名

## ガイドライン構成

### languages/ (6ファイル)
golang.md, typescript.md, nextjs-react.md, tailwind.md, shadcn.md, eslint.md

### common/ (10ファイル)
claude-code-tips.md, code-quality-design.md, development-process.md, document-management.md, emergency-parallel-work.md, error-handling-patterns.md, technical-pitfalls.md, testing-guidelines.md, type-safety-principles.md, unused-code-detection.md

### design/ (6ファイル)
clean-architecture.md, domain-driven-design.md, ecommerce-platforms.md, microservices-kubernetes.md, requirements-engineering.md, ui-ux-guidelines.md

### infrastructure/ (5ファイル)
aws-ec2.md, aws-ecs-fargate.md, aws-eks.md, aws-lambda.md, terraform.md

### summaries/ (4ファイル)
common-summary.md, golang-summary.md, nextjs-react-summary.md, typescript-summary.md

## 自動スキル適用ルール

以下の状況では、対応するスキルを**自動的に適用**すること:

| トリガー | スキル | アクション |
|----------|--------|-----------|
| Docker接続エラー | `docker-troubleshoot` | lima/daemon状態を診断・修復 |
| `/serena オンボーディング` | - | `check_onboarding_performed`で重複確認 |

### 重複防止ルール

- **オンボーディングは1回のみ**: `/serena オンボーディング`実行前に`mcp__serena__check_onboarding_performed`を確認
- **同じ質問は避ける**: 「〇〇の仕様は？」→ まずSerena memory検索

## 同期コマンド

- `./claude-code/install.sh` - 初回インストール
- `./claude-code/sync.sh` - リポジトリ ↔ ~/.claude 同期

## トークン節約ルール

| 場面 | 推奨アクション |
|------|---------------|
| コードベース把握 | `summaries/*.md` を先に読む |
| 詳細確認 | summaryで不足時のみ本体を読む |
| ガイドライン | load-guidelinesで必要なもののみ |
| kenron | 初回のみファイル読み込み、以降はmemory参照 |
| 大きなファイル | 必要な部分のみoffset/limitで読む |
