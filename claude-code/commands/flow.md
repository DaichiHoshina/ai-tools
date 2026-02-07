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
| 2 | 修正, fix, バグ, エラー, 不具合, bug, error | **バグ修正** | Debug → Dev → Verify → PR |
| 3 | リファクタリング, 改善, 整理, 見直し, refactor, improve | **リファクタリング** | Plan → Refactor → Techdebt → Simplify → Review → Verify → PR(draft) |
| 4 | ドキュメント, 仕様書, README, docs, documentation | **ドキュメント** | Explore → Docs → Review → PR |
| 5 | テスト, test, spec, testing | **テスト作成** | Test → Review → Verify → PR |
| 6 | 追加, 実装, 作成, 新規, 機能, add, implement, create | **新機能実装** | PRD → Plan → Dev → Simplify → Test → Review → Verify → PR |
| 7 | データ分析, 分析, analysis, データ, data | **データ分析** | データ分析 → ドキュメント化 → PR |
| 8 | インフラ, infrastructure, terraform, kubernetes, k8s, IaC | **インフラ** | Plan → インフラコード → Verify → PR |
| 9 | トラブルシュート, troubleshoot, 調査, 診断, 障害 | **トラブルシュート** | 診断 → 修正 → ドキュメント化 |
| 10 | その他 | **新機能実装** | （デフォルト） |

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

### 3. 複雑度判定（Tasks自動化）

```
複雑度判定: UserRequest → {Simple, TaskDecomposition, AgentHierarchy}
```

| 条件 | 判定 | Tasksアクション |
|------|------|-----------------|
| ファイル数<5 AND 行数<300 | **Simple** | Tasks不使用 |
| ファイル数≥5 OR 独立機能≥3 | **TaskDecomposition** | **TaskCreate → TaskUpdate(in_progress/completed)** |
| 複数プロジェクト横断 | **AgentHierarchy** | PO経由でTasks管理 |

**TaskDecomposition時の自動フロー**:
```
# 1. サブタスク作成（依存関係付き）
TaskCreate(subject: "サブタスク1", description: "詳細", activeForm: "サブタスク1を実行中")
TaskCreate(subject: "サブタスク2", description: "詳細", activeForm: "サブタスク2を実行中")

# 2. 依存関係設定
TaskUpdate(taskId: "2", addBlockedBy: ["1"])

# 3. 各ステップ実行時
TaskUpdate(taskId: "1", status: "in_progress")  # 開始
# ... 実行 ...
TaskUpdate(taskId: "1", status: "completed")    # 完了

# セッション間共有（任意）
CLAUDE_CODE_TASK_LIST_ID=xxx で複数セッション間で共有可能
```

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
