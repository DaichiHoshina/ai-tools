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

## 前提条件（必須）

**kenron読み込み**: `/kenron` または `Skill("kenron")` で圏論的思考法を適用

```
Guard関手による操作分類:
- Safe射（即実行）: 読み取り、分析、git status/log/diff
- Boundary射（要確認）: git commit/push、ファイル編集、設定変更
- Forbidden射（拒否）: rm -rf /、secrets漏洩、YAGNI違反
```

**ワークフロー内で常に意識**: 各操作実行前にGuard関手で分類し、Boundary射は必ず確認を取る

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

### 0. kenron読み込み（必須）
`Skill("kenron")` でGuard関手・3層分類をセッションに適用

### 1. オプション解析
引数からタスク内容とオプションを抽出

### 2. git status確認
- 変更ファイルあり → /prdスキップ、/devから開始を提案
- 変更なし → 新規タスクとして最初から実行

### 3. ComplexityCheck射（Kanban自動化）

```
ComplexityCheck : UserRequest → {Simple, TaskDecomposition, AgentHierarchy}
```

| 条件 | 判定 | Kanbanアクション |
|------|------|-----------------|
| ファイル数<5 AND 行数<300 | **Simple** | Kanban不使用 |
| ファイル数≥5 OR 独立機能≥3 | **TaskDecomposition** | **kanban init → add → start/done 自動** |
| 複数プロジェクト横断 | **AgentHierarchy** | PO経由でKanban管理 |

**TaskDecomposition時の自動フロー**:
```bash
# 1. ボード初期化
kanban init "{タスク名}"

# 2. サブタスク自動分解・追加
kanban add "サブタスク1" --priority=high
kanban add "サブタスク2" --priority=medium
...

# 3. 各ステップ実行時
kanban start {id}  # 開始
# ... 実行 ...
kanban done {id}   # 完了
```

### 4. Plan モード判断
- **Plan必須**: 新機能実装, リファクタリング, 複雑なバグ修正
- **通常モード**: 単純なバグ修正, ドキュメント, テスト

### 5. workflow-orchestrator起動

```
Task(
  subagent_type: "workflow-orchestrator",
  prompt: "タスク: {内容}, タイプ: {判定結果}, 複雑度: {ComplexityCheck結果}, オプション: {解析結果}"
)
```

## 統合ルール

- **code-simplifier**: 実装・リファクタリング後に必ず実行
- **verify-app**: PR作成前に必ず実行
- **/commit-push-pr**: 最終ステップで実行

---

ARGUMENTS: $ARGUMENTS
