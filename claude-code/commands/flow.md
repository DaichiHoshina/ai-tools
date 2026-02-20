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
# ステップスキップ
--skip-prd      # PRDスキップ
--skip-test     # テストスキップ
--skip-review   # レビュースキップ
--no-po         # PO起動をスキップし直接実行（緊急時のみ）

# 実行モード
--interactive   # 各ステップで確認
--auto          # 確認なし（session-mode fastと同等）
```

## 実行ロジック

> protection-modeはsession-startで自動適用済み。再読み込み不要。

### Step 1: git status確認

- 変更ファイルあり → /prdスキップ、/devから開始を提案
- 変更なし → 新規タスクとして最初から実行

### Step 2: PO Agent起動（必須）

**`/flow` は常にPO Agentを起動する。** 複雑度の自己判定は行わない。

```
Task(subagent_type: "po-agent") を起動
  → POがタスクを分析
  → POが「Team使用」or「直接実行推奨」を判断（デフォルト: Team）
  → Team使用の場合: POがManager Agentを起動
  → 直接実行推奨の場合: POの分析結果を元にStep 3へ
```

**例外**: `--no-po` 指定時のみPOをスキップし、従来通り直接実行。

### Step 3: ワークフロー実行

PO Agent完了後（またはPOスキップ時）、タスクタイプ判定表に従い後続ステップを実行。

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
