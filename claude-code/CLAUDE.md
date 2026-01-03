# ai-tools リポジトリ固有設定

> **注意**: 共通設定は `~/.claude/CLAUDE.md` を参照。このファイルはリポジトリ固有の情報のみ。

<!-- 🔒 PROTECTED SECTION - DO NOT MODIFY OR DELETE -->
<!-- このセクション（返信フォーマット〜8原則）は自動編集・削除禁止 -->
<!-- 変更はユーザーの明示的な指示がある場合のみ許可 -->

## 返信フォーマット（必須）🔒

> **重要**: 毎回の返信冒頭に以下を出力すること

フォーマット: `#N | 📁 ディレクトリ名 | 🌿 branch | guidelines(言語) | skill(スキル名)`

例:
- `#1 | 📁 ai-tools | 🌿 main | guidelines(go,ts) | skill(none)`
- `#2 | 📁 my-app | 🌿 feature/auth | guidelines(none) | skill(docker-troubleshoot)`

### 8原則 🔒

1. **mem**: serena memory を読み込み・更新
2. **serena**: /serena でコマンド実行
3. **guidelines**: load-guidelines で言語ガイドライン読み込み（検出言語を表示）
4. **自動処理禁止**: 整形・lint・ビルド・テスト修正を勝手に行わない
5. **完了通知**: タスク完了時に `afplay ~/notification.mp3` 実行
6. **型安全**: any禁止、as控える
7. **コマンド提案**: 適切なコマンドを提案（/dev, /review, /plan 等）
8. **確認済**: 不明点は確認してから実行

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

## コマンド（16個）

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

## スキル（25個）

**レビュー系**: architecture-review, code-smell-review, documentation-review, error-handling-review, performance-review, security-review, test-quality-review, type-safety-review, uiux-design

**開発系**: go-backend, typescript-backend, react-nextjs, api-design, clean-architecture-ddd, grpc-protobuf

**インフラ系**: dockerfile-best-practices, kubernetes, terraform, microservices-monorepo, docker-troubleshoot

**ユーティリティ**: load-guidelines, ai-tools-sync, cleanup-enforcement, guideline-maintenance, mcp-setup-guide

**退避中** (`skills-archive/`): ecommerce, shopify-app-bridge, gitlab-cicd

## エージェント（3個）

| エージェント | 説明 |
|-------------|------|
| `code-simplifier` | コード簡素化専門（複雑度削減、リファクタリング提案） |
| `verify-app` | アプリケーション検証専門（動作確認、統合テスト） |
| `workflow-orchestrator` | ワークフロー自動化（タスク判定、最適フロー実行） |

## フック（1個）

| フック | 説明 |
|--------|------|
| `post-tool-use` | ツール使用後の自動処理（エラー検出、品質チェック） |

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

### レビュースキル選択基準

| 問題タイプ | 使用スキル |
|-----------|-----------|
| 設計・構造 | architecture-review |
| 重複・複雑度 | code-smell-review |
| エラー処理 | error-handling-review |
| パフォーマンス | performance-review |
| セキュリティ | security-review |
| 型安全性 | type-safety-review |
| テスト | test-quality-review |
| ドキュメント | documentation-review |
| UI/UX | uiux-design |

## ガイドライン構成

### languages/ (3ファイル)
golang.md, typescript.md, nextjs-react.md

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
