---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, TodoWrite, Task, AskUserQuestion, Skill, mcp__serena__*
model: sonnet
description: ワークフロー自動化 - タスクタイプを自動判定して最適なワークフローを実行
---

## /flow - 自動ワークフロー実行

> **📌 /dev との使い分け**
> - `/flow`: タスク自動判定 → 最適なワークフロー全体を実行（推奨）
> - `/dev`: 実装フェーズのみ（タスク内容・タイプが既知の場合）
> - **迷ったら `/flow` を使用**

タスクを伝えるだけで、最適なワークフローを自動実行。

## タスクタイプ判定

| 優先度 | キーワード | タスクタイプ | ワークフロー |
|--------|-----------|------------|------------|
| 1 | 緊急, hotfix, 本番 | **緊急対応** | Debug → Dev → Verify → PR |
| 2 | 修正, fix, バグ, エラー | **バグ修正** | Debug → Dev → Verify → PR |
| 3 | リファクタ, 改善, 整理 | **リファクタリング** | Plan → Refactor → Simplify → Review → Verify → PR(draft) |
| 4 | ドキュメント, 仕様書, docs | **ドキュメント** | Explore → Docs → Review → PR |
| 5 | テスト, test, spec | **テスト作成** | Test → Review → Verify → PR |
| 6 | 追加, 実装, 作成, 機能 | **新機能実装** | PRD → Plan → Dev → Simplify → Test → Review → Verify → PR |
| 7 | その他 | **新機能実装** | （デフォルト） |

## オプション

```bash
--skip-prd      # PRDスキップ
--skip-test     # テストスキップ
--skip-review   # レビュースキップ
--skip-simplify # 簡素化スキップ
--interactive   # 各ステップで確認
--auto          # 確認なし（上級者向け）
```

## 実行ロジック

### 1. オプション解析
引数からタスク内容とオプションを抽出

### 2. git status確認
- 変更ファイルあり → /prdスキップ、/devから開始を提案
- 変更なし → 新規タスクとして最初から実行

### 3. Plan モード判断
- **Plan必須**: 新機能実装, リファクタリング, 複雑なバグ修正
- **通常モード**: 単純なバグ修正, ドキュメント, テスト

### 4. workflow-orchestrator起動

```
Task(
  subagent_type: "workflow-orchestrator",
  prompt: "タスク: {内容}, タイプ: {判定結果}, オプション: {解析結果}"
)
```

## 統合ルール

- **code-simplifier**: 実装・リファクタリング後に必ず実行
- **verify-app**: PR作成前に必ず実行
- **/commit-push-pr**: 最終ステップで実行

---

ARGUMENTS: $ARGUMENTS
