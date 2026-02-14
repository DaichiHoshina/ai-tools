---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Task, AskUserQuestion, Skill, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*
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

**protection-mode読み込み**: `/protection-mode` または `Skill("protection-mode")` で操作チェッカーを適用

```
操作チェッカーによる分類:
- ✅ 安全操作（即実行）: 読み取り、分析、git status/log/diff
- ⚠️ 要確認操作（確認必要）: git commit/push、ファイル編集、設定変更
- 🚫 禁止操作（拒否）: rm -rf /、secrets漏洩、YAGNI違反
```

**ワークフロー内で常に意識**: 各操作実行前に分類し、要確認操作は必ず確認を取る

## タスクタイプ判定

| 優先度 | キーワード | タスクタイプ | ワークフロー |
|--------|-----------|------------|------------|
| 0 | 相談, アイデア, 設計検討, ブレスト, brainstorm, 構想, 検討 | **設計相談** | Brainstorm → PRD → Plan → ... |
| 1 | 緊急, hotfix, 本番, production, critical | **緊急対応** | Debug → Dev → Verify → PR |
| 2 | 根本, 原因分析, root cause, rca | **バグ修正（RCA付き）** | Debug → RootCause → Dev → Verify → PR |
| 3 | 修正, fix, バグ, エラー, 不具合, bug, error | **バグ修正（シンプル）** | Debug → Dev → Verify → PR |
| 4 | リファクタリング, 改善, 整理, 見直し, refactor, improve | **リファクタリング** | Plan → Refactor → Techdebt → Simplify → Review → Verify → PR(draft) |
| 5 | ドキュメント, 仕様書, README, docs, documentation | **ドキュメント** | Explore → Docs → Review → PR |
| 6 | テスト, test, spec, testing | **テスト作成** | Test → Review → Verify → PR |
| 7 | 追加, 実装, 作成, 新規, 機能, add, implement, create | **新機能実装** | PRD → Plan → Dev → Simplify → Test → Review → Verify → PR |
| 8 | データ分析, 分析, analysis, データ, data | **データ分析** | データ分析 → ドキュメント化 → PR |
| 9 | インフラ, infrastructure, terraform, kubernetes, k8s, IaC | **インフラ** | Plan → インフラコード → Verify → PR |
| 10 | トラブルシュート, troubleshoot, 調査, 診断, 障害 | **トラブルシュート** | 診断 → 修正 → ドキュメント化 |
| 11 | その他 | **新機能実装** | （デフォルト） |

## オプション

```bash
--skip-prd      # PRDスキップ
--skip-test     # テストスキップ
--skip-review   # レビュースキップ
--skip-simplify # 簡素化スキップ
--interactive   # 各ステップで確認
--auto          # 確認なし（上級者向け）- session-mode fastと同等
```

**session-modeとの連携**: session-modeが`fast`の場合、`--auto`が暗黙的に有効化される。
これにより「yes」「y」「はい」の繰り返し入力が不要に。

**注意**: `--autonomous` / `--fast` オプションは廃止されました。代わりに、複雑度に応じて自動的に適切な機能が有効化されます。

## 実行ロジック

### 0. protection-mode読み込み（必須）
`Skill("protection-mode")` で操作チェッカー・安全性分類をセッションに適用

**Guard関手が各操作に自動適用**:
```
Guard_M : Mode × Action → {Allow, AskUser, Deny}

- Allow（Safe射）: 読み取り、分析 → 即座実行
- AskUser（Boundary射）: git push、設定変更 → 確認後実行
- Deny（Forbidden射）: rm -rf /、secrets漏洩 → 拒否
```

### 1. オプション解析
引数からタスク内容とオプションを抽出

### 2. git status確認
- 変更ファイルあり → /prdスキップ、/devから開始を提案
- 変更なし → 新規タスクとして最初から実行

### 3. 複雑度判定と自動機能適用

`/flow` コマンドは、タスクの複雑度を自動判定し、必要な機能を**自動的に有効化**します。

```
複雑度判定: UserRequest → {Simple, TaskDecomposition, AgentHierarchy}
             ↓
         自動機能適用
```

| 複雑度 | 判定条件 | 自動適用機能 |
|--------|----------|--------------|
| **Simple** | ファイル数<5 AND 行数<300 | • 通常実行<br>• タイムアウト: なし<br>• Tasks: 不使用 |
| **TaskDecomposition** | ファイル数≥5 OR 独立機能≥3 OR 行数≥300 | • TaskCreate/Update 自動化<br>• **セッションタイムアウト: 2時間**<br>• **進捗追跡**: `progress/` 自動作成・更新<br>• テスト多数時: サンプリング推奨通知 |
| **AgentHierarchy** | 複数プロジェクト横断 OR 大規模変更 | • PO/Manager/Developer階層<br>• **タスクロック**: `current_tasks/` 自動作成<br>• **全タイムアウト有効**（セッション2h、タスク30m、ループ5m）<br>• **進捗集約**: `aggregate_progress()` 実行<br>• **テストサンプリング**: 10%自動有効化 |

#### TaskDecomposition時の自動フロー（中規模タスク）

**自動的に実行される処理**:
```bash
# 進捗ディレクトリ初期化
load_lib "progress.sh"
init_progress_dir()
update_session_progress "$SESSION_ID" "planning" 0 "Task decomposition started"

# サブタスク作成（依存関係付き）
TaskCreate(subject: "サブタスク1", description: "詳細", activeForm: "サブタスク1を実行中")
TaskCreate(subject: "サブタスク2", description: "詳細", activeForm: "サブタスク2を実行中")
TaskUpdate(taskId: "2", addBlockedBy: ["1"])

# セッションタイムアウト監視開始
load_lib "timeout.sh"
session_start=$(get_epoch)

# 各ステップ実行時
TaskUpdate(taskId: "1", status: "in_progress")
update_session_progress "$SESSION_ID" "implementation" 50 "Implementing feature X"

# タイムアウトチェック（各ステップで自動実行）
if check_session_timeout "$session_start"; then
    load_lib "error-codes.sh"
    emit_error "E1001" "Session exceeded 2 hours"
    exit 1
fi

TaskUpdate(taskId: "1", status: "completed")

# セッション間共有（任意）
CLAUDE_CODE_TASK_LIST_ID=xxx で複数セッション間で共有可能
```

**ユーザーへの通知**:
- 開始時: "中規模タスク検出（ファイル8件）。進捗追跡とタイムアウト（2時間）を有効化"
- 1時間経過時: "⏰ セッション残り1時間"
- テスト多数時: "💡 大量のテスト検出（500件）。次回以降10%サンプリングで高速化されます"

#### AgentHierarchy時の自動フロー（大規模タスク）

**自動的に実行される処理**:
```bash
# 全機能フル有効化
load_lib "timeout.sh"
load_lib "progress.sh"
load_lib "task-lock.sh"
load_lib "sampling.sh"
load_lib "error-codes.sh"

init_progress_dir()
session_start=$(get_epoch)

# Agent Teams起動
TeamCreate(team_name: "project-refactor")

# タスクロック取得（並列実行時の重複防止）
if acquire_lock "task-123" "$AGENT_ID"; then
    task_start=$(get_epoch)
    update_session_progress "$SESSION_ID" "implementation" 60 "Task-123"
    
    # タスクタイムアウトチェック
    if check_task_timeout "$task_start"; then
        emit_error "E1002" "Task exceeded 30 minutes"
        release_lock "task-123" "$AGENT_ID"
        exit 1
    fi
    
    release_lock "task-123" "$AGENT_ID"
fi

# テスト自動サンプリング（10%、決定的）
if [ $TEST_COUNT -gt 100 ]; then
    seed=$(generate_seed "$AGENT_ID")
    find . -name "*.test.js" | sample_items 0.1 "$seed" | xargs jest
fi

# 進捗集約（複数セッション時）
aggregate_progress()
```

**ユーザーへの通知**:
- 開始時: "大規模タスク検出（20ファイル）。Agent Teams、タスクロック、全タイムアウト、テストサンプリング(10%)を有効化"
- 並列セッション検出時: "他のセッションと並列実行中。タスクロックで重複を防止"

### 4. Agent Teams判定（AgentHierarchy時のみ）

**実行条件**: ステップ3で `AgentHierarchy` と判定された場合のみ

```bash
# 1. 環境変数チェック
if [ -z "$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" ]; then
  echo "⚠️ Agent Teams機能が未有効化です"
  echo "複雑度: AgentHierarchy（複数プロジェクト横断 OR 大規模変更）"
  # AskUserQuestion で有効化確認
fi

# 2. 有効化が必要な場合
if [ 有効化選択 ]; then
  # ~/.zshrc または ~/.bashrc に追加
  echo 'export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1' >> ~/.zshrc
  echo "✅ Agent Teams機能を有効化しました"
  echo "📌 新しいセッションで有効になります"
fi
```

**スキップ条件**:
- 複雑度が `Simple` または `TaskDecomposition` の場合
- 環境変数が既に設定済みの場合

### 5. Plan モード判断（自動移行）
- **Plan必須**: 新機能実装, リファクタリング, 複雑なバグ修正
  - → `EnterPlanMode()` で自動移行、完了後 `ExitPlanMode()` で自動終了
- **通常モード**: 単純なバグ修正, ドキュメント, テスト

### 6. workflow-orchestrator起動

```
Task(
  subagent_type: "workflow-orchestrator",
  prompt: "タスク: {内容}, タイプ: {判定結果}, 複雑度: {ComplexityCheck結果}, オプション: {解析結果}"
)
```

## バグ修正ワークフローの選択

### 自動切り替え

- `/flow バグ修正` → bugfix（シンプル版）
- `/flow 根本原因を特定してバグ修正` → bugfix_with_rca

### 複雑度による自動判定

複雑度がMedium以上の場合、自動的にRCA付きワークフローに切り替わります。

**複雑度判定基準**:
- Low: タイポ、インポートミス、単純な条件反転
- Medium: ロジックバグ、データ検証漏れ
- High: 競合状態、メモリリーク、セキュリティ脆弱性、繰り返し発生

### RCAフェーズの内容

1. 5つのなぜ分析で根本原因を特定
2. 修正戦略の比較（L1対症療法/L2部分治療/L3根本治療）
3. 類似問題の検出
4. ユーザーと戦略を協議（AskUserQuestion）

### RCA適用フロー

```
バグ修正タスク → 複雑度判定
  → Low: Debug → Dev → Verify → PR（従来通り）
  → Medium: Debug → /root-cause → Dev → Verify → PR
  → High: Debug → root-cause-analyzer Agent → Dev → Verify → PR
```

---

## 統合ルール

### 必須フロー

```
実装完了 → code-simplifier → verify-app → verify成功 → commit-push-pr
                                        → verify失敗 → 修正 → 再verify
```

### 各ステップの役割

- **code-simplifier**: 実装・リファクタリング後に**必ず実行**（複雑度削減・重複統合）
- **verify-app**: PR作成前に**必ず実行**（ビルド・テスト・lint を包括検証）
- **commit-push-pr**: 検証合格後の最終ステップ（verify-app通過が前提）

### 失敗時の対応

**2回失敗ルール**: 同じアプローチで2回失敗 → `/clear` → 問題再整理 → 新アプローチ

### 完了時のアクション提案

ワークフロー完了時、次のアクションを提案：

```
✅ ワークフロー完了しました

📋 次のアクション：
1. /commit-push-pr でcommit→push→PR作成
2. 手動でgit操作
3. 追加の修正・テスト
```

**Boris流**: ほとんどの場合は `1` を選択してPR作成まで一気に完了

---

## Writer/Reviewer並列パターン（大規模変更時）

**適用条件**:
- 10ファイル以上 OR 500行以上の変更
- 重要機能の実装（認証、決済、データ移行）
- アーキテクチャ変更

**実行方法**:
```
# Developer（実装） + Reviewer（レビュー）並列実行
Task(subagent_type: "developer-agent", prompt: "{実装内容}")
Task(subagent_type: "reviewer-agent", prompt: "実装完了後にレビュー")
```

**フロー**:
```
Developer実装 → Reviewer検証 → 問題あり → Developer修正
                              → 問題なし → verify-app → PR
```

---

ARGUMENTS: $ARGUMENTS
