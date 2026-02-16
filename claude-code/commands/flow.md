---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Task, AskUserQuestion, Skill, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*
model: sonnet
description: ワークフロー自動化 - タスクタイプを自動判定して最適なワークフローを実行
---

## /flow - 自動ワークフロー実行

> **使い分け**
> - `/flow`: タスク自動判定 → 最適なワークフロー全体を実行（推奨）
> - `/dev`: 実装フェーズのみ（タスク内容が既知の場合）
> - **迷ったら `/flow` を使用**

タスクを伝えるだけで、最適なワークフローを自動実行。

## タスクタイプ判定

| 優先度 | キーワード | タスクタイプ | ワークフロー |
|--------|-----------|------------|------------|
| 0 | 相談, アイデア, 設計検討, ブレスト, brainstorm | **設計相談** | /brainstorm → /prd → /plan |
| 1 | 緊急, hotfix, 本番, production, critical | **緊急対応** | /debug → /dev → /lint-test → /commit-push-main |
| 2 | 根本, 原因分析, root cause, rca | **バグ修正（RCA付き）** | /debug → Skill(root-cause) → /dev → /lint-test → /commit-push-pr |
| 3 | 修正, fix, バグ, エラー, 不具合, bug, error | **バグ修正** | /debug → /dev → /lint-test → /review → /commit-push-main |
| 4 | リファクタリング, 改善, 整理, refactor, improve | **リファクタリング** | /plan → /refactor → /lint-test → /test → /review → /commit-push-pr |
| 5 | ドキュメント, 仕様書, README, docs | **ドキュメント** | /docs → /review → /commit-push-main |
| 6 | テスト, test, spec, testing | **テスト作成** | /test → /review → /lint-test → /commit-push-pr |
| 7 | 追加, 実装, 作成, 新規, 機能, add, implement, create | **新機能実装** | /prd → /plan → /dev → /test → /review → /lint-test → /commit-push-pr |
| 8 | データ分析, 分析, analysis, データ | **データ分析** | Skill(data-analysis) → /docs → /commit-push-main |
| 9 | インフラ, terraform, kubernetes, k8s | **インフラ** | /plan → Skill(terraform) → /lint-test → /commit-push-pr |
| 10 | トラブルシュート, troubleshoot, 調査, 診断 | **トラブルシュート** | /debug → /dev → /docs |
| 11 | その他 | **新機能実装** | （デフォルト） |

## オプション

```bash
# 複雑度指定
--simple        # Simple強制（TaskCreate不使用）
--complex       # TaskDecomposition強制（TaskCreate使用）
--teams         # Agent階層強制（PO→Manager→Developer）

# ステップスキップ
--skip-prd      # PRDスキップ
--skip-test     # テストスキップ
--skip-review   # レビュースキップ

# 実行モード
--interactive   # 各ステップで確認
--auto          # 確認なし（session-mode fastと同等）
```

## 実行ロジック

> protection-modeはsession-startで自動適用済み。再読み込み不要。

### Step 1: git status確認

- 変更ファイルあり → /prdスキップ、/devから開始を提案
- 変更なし → 新規タスクとして最初から実行

### Step 2: 複雑度判定

| 複雑度 | 判定条件 | 適用機能 |
|--------|----------|----------|
| **Simple** | 設定ファイル・ドキュメントのみの変更 OR 行数<50 | 直接実行 |
| **TaskDecomposition** | ファイル数3-5 OR 行数50-300 | TaskCreate/Update で進捗追跡 + 直接実行 |
| **AgentHierarchy** | ファイル数>5 OR 行数>300 OR 新機能実装 OR リファクタリング | **必ず** Agent階層で実行 |

**Agent階層の実行手順**（AgentHierarchy判定時、スキップ禁止）:
```
1. Task(po-agent) → 戦略決定・タスク定義
2. Task(manager-agent) → タスク分割・Developer配分計画
3. Task(developer-agent) × N → 並列実装（1メッセージで複数Task）
```

### Step 3: Plan モード判断

- **Plan必須**: 新機能実装, リファクタリング, 複雑なバグ修正
  - → `EnterPlanMode()` で自動移行
- **通常モード**: 単純なバグ修正, ドキュメント, テスト

### Step 4: ワークフロー実行

タスクタイプ判定表に従い、各コマンドを順次実行。

## バグ修正ワークフロー詳細

### 自動切り替え

- `/flow バグ修正` → シンプル版
- `/flow 根本原因を特定してバグ修正` → RCA付き

### 複雑度による判定

| レベル | 例 | フロー |
|--------|---|--------|
| Low | タイポ、インポートミス | /debug → /dev → /lint-test → /commit-push-main |
| Medium | ロジックバグ、検証漏れ | /debug → Skill(root-cause) → /dev → /lint-test → /commit-push-pr |
| High | 競合状態、セキュリティ | /debug → Task(root-cause-analyzer) → /dev → /lint-test → /commit-push-pr |

## 統合ルール

### 必須フロー

```
実装完了 → /lint-test → 検証成功 → /commit-push-pr
                      → 検証失敗 → 修正 → 再検証
```

### 失敗時の対応

**2回失敗ルール**: 同じアプローチで2回失敗 → `/clear` → 問題再整理 → 新アプローチ

### 完了時のアクション提案

```
ワークフロー完了

次のアクション:
1. /commit-push-pr でcommit→push→PR作成
2. /commit-push-main でmainにpush
3. 追加の修正・テスト
```

## コマンド依存グラフ

各コマンドの推奨実行順序。`/flow` は自動でこの順序を適用する。

```
新機能:    /prd → /plan → /dev → /lint-test → /test → /review → /commit-push-pr
バグ修正:  /debug → /dev → /lint-test → /review → /commit-push-main
リファクタ: /plan → /refactor → /lint-test → /test → /review → /commit-push-pr
テスト:    /test → /review → /lint-test → /commit-push-pr
ドキュメント: /docs → /review → /commit-push-main
```

ARGUMENTS: $ARGUMENTS
