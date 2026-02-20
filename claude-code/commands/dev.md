---
allowed-tools: Read, Glob, Grep, Edit, MultiEdit, Write, Bash, Task, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*, mcp__context7__*
description: 直接実装コマンド - Agent不使用で直接実行。--quickオプションでhaiku高速実行。Agent Teamが必要なら /flow を使用。
---

## /dev - 実装モード

> **📌 /flow との使い分け**
> - `/dev`: 実装フェーズのみ実行（タスク内容が明確な場合）
> - `/flow`: タスク自動判定 → 最適なワークフロー全体を実行（PRD→Plan→Dev→Test→Review→PR）
> - 迷ったら `/flow` を使用

## protection-mode

session-startで自動適用済み。再読み込み不要。

## オプション

```bash
/dev --quick <task>    # 高速モード（haiku、1-2ファイル修正専用）
/dev <task>            # 通常モード（sonnet、直接実行）
# Agent Team が必要な場合は /flow を使用
```

### --quick モード（旧 /quick-fix）

**用途**:
- 1-2ファイルの単純な修正
- typo修正、小さなバグ修正
- 軽微な変更（数行程度）

**特徴**:
- **haiku model**使用（高速・低コスト）
- **Agent階層不使用**（直接実行）
- 確認最小限

**実行フロー**:
1. 対象ファイル特定
2. 修正実行（Serena MCP使用）
3. verify（lint/type check）
4. commit提案

**使用例**:
```
/dev --quick typoを修正
/dev --quick この関数のバグを直して
```

**注意**: 複雑なタスクには不向き。3ファイル以上の変更や設計判断が必要な場合は通常の `/dev` または `/flow` を使用。

## 思考モード（重要）

**always ultrathink** - 複雑な実装では必ず深く思考してから実行。安易な実装を避け、設計意図を理解した上でコードを書く。

## Step 0: ガイドライン読み込み（条件付き）

**判断基準**:
- `--quick`モード → ガイドライン読み込みスキップ（トークン節約）
- 1-2ファイルの軽微な修正 → スキップ可（既知のパターンなら不要）
- 新機能実装・設計判断 → `load-guidelines` 実行（サマリーモード推奨）
- UI開発（Tailwind/React検出時） → `ui-skills` スキル推奨

```
/load-guidelines        # サマリーのみ（~2,500トークン）
/load-guidelines full   # 詳細ガイドライン込み（+~5,500トークン）
```

## /dev と /flow の使い分け

| 状況 | 使うコマンド |
|------|-------------|
| タスク内容が明確、1-5ファイル程度 | `/dev` |
| 複雑なタスク、Agent Teamが必要 | `/flow` |
| 1-2ファイルの軽微な修正 | `/dev --quick` |

**`/dev` はAgent Teamを使用しない。** Agent Team（PO→Manager→Developer）が必要な場合は `/flow` を使用すること。

## 実行フロー

1. ガイドライン読込
2. Serena MCP でコード分析
3. TaskCreate で計画
4. ユーザー確認
5. 実装
6. lint/test 実行

## 優先順位

1. **型安全性** - any/as 禁止
2. **ガイドライン準拠**
3. **アーキテクチャパターン**
4. **テスタビリティ**

## 実装後の自動品質チェック（必須）

実装完了後、以下を自動実行:

```bash
# 言語別の静的解析
# TypeScript
npm run lint && npx tsc --noEmit

# Go
golangci-lint run && go vet ./...

# Python
ruff check . && mypy .
```

**チェック結果の対応:**
- エラー 0件 → ユーザーに完了報告
- エラーあり → 自動修正を試行、修正不可なら報告

## 次のアクション

```
/dev 完了
  → /lint-test（品質チェック）
  → /test（テスト作成・実行）
  → /review（コードレビュー）
  → /commit-push-pr or /commit-push-main（Git操作）
  → エラー時: /debug
```

## 関連コマンド

| コマンド | 関係 |
|---------|------|
| `/refactor` | 動作を変えずに構造改善。`/dev` の後に実行可能 |
| `/tdd` | テスト駆動開発モード。`/dev` のテスト優先版 |
| `/lint-test` | CI相当チェック。`/dev` 完了後に推奨 |

**実装前はユーザー確認必須。Serena MCP でコード操作。**
