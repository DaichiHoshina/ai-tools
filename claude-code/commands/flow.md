---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Task, AskUserQuestion, Skill, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*
model: sonnet
description: ワークフロー自動化 - タスクタイプを自動判定して最適なワークフローを実行
---

## /flow - 自動ワークフロー実行

> **使い分け**: `/flow`（推奨）、`/dev`（実装のみ）

タスクを伝えるだけで、最適なワークフローを自動実行。

## タスクタイプ判定

| 優先度 | キーワード | タスクタイプ | ワークフロー |
|--------|-----------|------------|------------|
| 0 | 相談, アイデア, 設計検討, ブレスト, brainstorm | **設計相談** | /brainstorm → /prd → /plan |
| 1 | 緊急, hotfix, 本番, production, critical | **緊急対応** | /debug → /dev → /lint-test → /git-push --main |
| 2 | 根本, 原因分析, root cause, rca | **バグ修正（RCA付き）** | /debug → Skill(root-cause) → /dev → /lint-test → /git-push --pr |
| 3 | 修正, fix, バグ, エラー, 不具合, bug, error | **バグ修正** | /debug → /dev → /lint-test → /git-push --pr |
| 4 | リファクタリング, 改善, 整理, refactor, improve | **リファクタリング** | /plan → /refactor → /lint-test → /test → /review → /git-push --pr |
| 5 | ドキュメント, 仕様書, README, docs | **ドキュメント** | /docs → /review → /git-push --main |
| 6 | テスト, test, spec, testing | **テスト作成** | /test → /review → /lint-test → /git-push --pr |
| 7 | 追加, 実装, 作成, 新規, 機能, add, implement, create | **新機能実装** | /prd → /plan → /dev → /test → /review → /lint-test → /git-push --pr |
| 8 | データ分析, 分析, analysis, データ | **データ分析** | Skill(data-analysis) → /docs → /git-push --main |
| 9 | インフラ, terraform, kubernetes, k8s | **インフラ** | /plan → Skill(terraform) → /lint-test → /git-push --pr |
| 10 | トラブルシュート, troubleshoot, 調査, 診断 | **トラブルシュート** | /debug → /dev → /docs |
| 11 | その他 | **新機能実装** | （デフォルト） |

## オプション

```text
--skip-prd      # PRDスキップ
--skip-test     # テストスキップ
--skip-review   # レビュースキップ
--no-po         # PO起動をスキップし直接実行（緊急時のみ）
--interactive   # 各ステップで確認
--auto          # 完全自律モード
```

## --auto 完全自律モード

| 判断ポイント | 動作 |
|-------------|------|
| AskUserQuestion | 呼ばない。推奨（1番目）を自動採用 |
| Agent起動 | `mode: "bypassPermissions"` で承認スキップ |
| push先 | タスクタイプで自動判定（緊急/ドキュメント→main、それ以外→PR） |
| PO Agent | スキップ（`--no-po`と同等） |
| 設計判断 | 推奨パターンを自動採用。迷ったらシンプルな方 |
| lint-test失敗 | 自動修正を1回試行。2回失敗で停止しユーザーに報告 |

autoフロー: タスク受領 → タスクタイプ自動判定 → ワークフロー自動実行 → lint-test → review-fix ループ → 秘匿情報チェック → /git-push → Serena memory保存 → 完了報告

### review-fix ループ

`--auto` 時、実装完了後に `/review` → 自動修正を **Critical 0件 + Warning 0件** になるまで繰り返す（最大3回）。3回到達しても残る場合 → 残件をユーザーに報告して続行。

## 実行ロジック

### Step 1: git status確認

- 変更ファイルあり → /prdスキップ、/devから開始を提案
- 変更なし → 新規タスクとして最初から実行

### Step 2: PO Agent起動

**`/flow` は常にPO Agentを起動する。** 複雑度の自己判定は行わない。

PO Agentが「Team使用」or「直接実行推奨」を判断（デフォルト: Team）。`--no-po` 指定時のみPOをスキップし、タスクタイプ判定表で直接実行（緊急時のみ）。

### Step 3: ワークフロー実行

PO Agent完了後（またはPOスキップ時）、タスクタイプ判定表に従い後続ステップを実行する。

## バグ修正: 複雑度による分岐

| レベル | 例 | フロー |
|--------|---|--------|
| Low | タイポ、インポートミス | /debug → /dev → /lint-test → /review → /git-push --pr |
| Medium | ロジックバグ、検証漏れ | /debug → Skill(root-cause) → /dev → /lint-test → /review → /git-push --pr |
| High | 競合状態、セキュリティ | /debug → Task(root-cause-analyzer) → /dev → /lint-test → /review → /git-push --pr |

## 統合ルール

- **必須フロー**: 実装完了 → /lint-test → /review → review-fix ループ → /git-push
- **2回失敗ルール**: 同じアプローチで2回失敗 → `/clear` → 問題再整理 → 新アプローチ

### 完了時のアクション

- Serena memory保存（名前: work-context-YYYYMMDD-{topic}）
- `--auto`: 秘匿情報チェック → /git-push（タスクタイプで自動判定）
- 通常: AskUserQuestion「pushしますか？」→ main/PR/終了

## 自動適用機能（v2.1.50+）

| 機能 | 条件 | 動作 |
|------|------|------|
| worktree分離 | コード変更ワークフロー（直接実行時） | 自動作成・クリーンアップ |
| `/simplify` | 実装/修正ステップ後 | バンドルコマンドで高速実行 |
| background agents | `--auto`時のverify-app | 非同期検証 |

ARGUMENTS: $ARGUMENTS
