---
allowed-tools: Read, Glob, Grep, Edit, Write, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*, mcp__context7__*
description: ドキュメント作成 - README、API ドキュメント、アーキテクチャ図などを作成
---

## /docs - ドキュメント作成モード

**目的**: プロジェクトのドキュメントを作成・更新する

## Auto Language Detection

プロジェクトの言語を自動検出し、対応するガイドラインを読み込む:

| 検出ファイル | 言語 | ガイドライン |
|-------------|------|-------------|
| `go.mod` | Go | `~/.claude/guidelines/languages/golang.md` |
| `package.json` + `tsconfig.json` | TypeScript | `~/.claude/guidelines/languages/typescript.md` |
| `next.config.*` | Next.js/React | `~/.claude/guidelines/languages/nextjs-react.md` |

**検出順序**: next.config → tsconfig → go.mod

## Document Types

### 1. README.md
- プロジェクト概要
- セットアップ手順
- 使い方
- ライセンス

### 2. API Documentation
- エンドポイント一覧
- リクエスト・レスポンス例
- エラーコード
- 認証方法

### 3. Architecture Documentation
- システムアーキテクチャ図 (Mermaid)
- データフロー図
- ER図（データベース設計）
- コンポーネント構成

### 4. Developer Guide
- 開発環境セットアップ
- コーディング規約
- テスト方法
- デプロイ手順

## Execution

1. **Detect** project language and read guideline
2. **Analyze** codebase with Serena MCP
   - プロジェクト構造を把握
   - 主要なシンボル・モジュールを特定
   - 依存関係を分析
3. **Determine** document type
   - ユーザーに何のドキュメントを作成するか確認
4. **Create** document
   - 既存コードから情報を抽出
   - 適切なフォーマットで記述
   - コードブロック・図表を活用
5. **Review** with user
   - ドキュメント案を提示
   - フィードバックを反映

## Writing Standards

- **明確**: 技術的に正確で分かりやすい
- **簡潔**: 冗長な説明を避ける
- **具体的**: 実例・コード例を含める
- **一貫性**: 用語・フォーマットを統一
- **完全性**: 必要な情報を網羅

**Mermaid 図の活用**:
- システム構成図
- シーケンス図
- クラス図
- フローチャート

**注意**: ドキュメント作成前に必ずユーザーに確認を取る

Use Serena MCP for code analysis and information extraction.
