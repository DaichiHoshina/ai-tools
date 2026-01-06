---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, TodoWrite, Task, AskUserQuestion, Skill, mcp__serena__*
model: sonnet
description: ワークフロー自動化 - タスクタイプを自動判定して最適なワークフローを実行
---

## /flow - 自動ワークフロー実行

> **コンセプト**: タスクを伝えるだけで、Claude が最適なワークフローを自動実行

## 使い方

```bash
# 基本（タスクタイプ自動判定）
/flow ユーザー認証機能を追加

# バグ修正
/flow この認証エラーを修正

# リファクタリング
/flow UserService を DDD に準拠させたい

# ドキュメント
/flow API仕様書を作成
```

## ワークフロー自動判定ロジック

### Step 1: タスクタイプ判定

プロンプトから以下を自動判定:

| キーワード | タスクタイプ | ワークフロー |
|-----------|------------|------------|
| 追加, 実装, 作成, 新規, 機能 | **新機能実装** | PRD → Plan → Dev → Simplify → Test → Review → Verify → PR |
| 修正, fix, バグ, エラー, 不具合 | **バグ修正** | Debug → Dev → Verify(test) → PR |
| リファクタリング, 改善, 整理, 見直し | **リファクタリング** | Plan → Refactor → Simplify → Review → Verify → PR(draft) |
| ドキュメント, 仕様書, README, docs | **ドキュメント整備** | Explore → Docs → Review → PR |
| 緊急, hotfix, 本番, production | **緊急対応** | Debug → Dev → Verify(test) → PR |
| テスト, test, spec | **テスト作成** | Test → Review → Verify → PR |

### Step 2: ファイル状態確認

```bash
git status --short
git diff --name-only
```

- **変更ファイルあり** → 既存作業の続きと判断。/prd をスキップして /dev から開始を提案
- **変更なし** → 新規タスクとして最初から実行

### Step 3: Plan モード判断

**Plan モード必須**:
- 新機能実装
- リファクタリング
- 複雑なバグ修正（複数ファイル関連）

**通常モード**:
- 単純なバグ修正（1-2ファイル）
- ドキュメント整備
- テスト作成

### Step 4: ワークフロー実行

ユーザー確認後、自動で各ステップを実行

## ワークフロー詳細

### 1. 新機能実装（最も包括的）

```bash
# 実行されるコマンド
1. /prd {タスク}                  # 要件整理
2. /plan {PRD}                    # 設計（Plan モード推奨をユーザーに通知）
3. /dev {設計}                    # 実装
4. code-simplifier {変更ファイル} # 簡素化
5. /test {機能}                   # テスト作成
6. /review                        # レビュー
7. verify-app                     # 検証
8. /commit-push-pr                # PR作成

```

### 2. バグ修正（高速）

```bash
# 実行されるコマンド
1. /debug {エラー内容}            # 問題特定
2. /dev {修正内容}                # 修正実装
   → PostToolUse フック自動実行   # 自動フォーマット
3. verify-app テストのみ          # テスト確認
4. /commit-push-pr -m "fix: ..."  # PR作成

```

### 3. リファクタリング（品質重視）

```bash
# 実行されるコマンド
1. /plan {リファクタリング内容}   # 計画（Plan モード推奨をユーザーに通知）
2. /refactor {計画}               # リファクタリング実行
3. code-simplifier 全ファイル     # 簡素化（重要）
4. /review                        # アーキテクチャレビュー
5. verify-app                     # 検証
6. /commit-push-pr --draft        # ドラフトPR

```

### 4. ドキュメント整備

```bash
# 実行されるコマンド
1. /explore {対象機能}            # 並列調査
2. /docs {ドキュメント種類}       # ドキュメント作成
3. /review                        # ドキュメントレビュー
4. /commit-push-pr -m "docs: ..." # PR作成

```

### 5. 緊急対応（最速）

```bash
# 実行されるコマンド
1. /debug {緊急エラー}            # 問題特定
2. /dev hotfix実装                # 即座に修正
3. verify-app テストのみ          # 最小限の検証
4. /commit-push-pr -m "hotfix: ..." # 即座にPR

```

### 6. テスト作成

```bash
# 実行されるコマンド
1. /test {対象機能}               # テスト作成
2. /review                        # テスト品質レビュー
3. verify-app テストのみ          # テスト実行確認
4. /commit-push-pr -m "test: ..." # PR作成

```

## オプション

### スキップ機能

```bash
# 特定ステップをスキップ
/flow {タスク} --skip-prd         # PRD作成スキップ
/flow {タスク} --skip-test        # テスト作成スキップ
/flow {タスク} --skip-review      # レビュースキップ
/flow {タスク} --skip-simplify    # 簡素化スキップ
```

### 手動モード

```bash
# 各ステップで確認を求める
/flow {タスク} --interactive

# 自動実行（確認なし、上級者向け）
/flow {タスク} --auto
```

## 実装ロジック（AIへの実行指示）

このコマンドを受け取ったら、以下を順次実行する。

### 1. オプション解析

引数から以下を抽出:

```
入力: "/flow ユーザー認証機能を追加 --skip-test --interactive"

解析結果:
- タスク: "ユーザー認証機能を追加"
- skip: ["test"]
- mode: "interactive" (default: "normal")
```

オプション一覧:
- `--skip-prd`, `--skip-test`, `--skip-review`, `--skip-simplify`: 該当ステップをスキップ
- `--interactive`: 各ステップでユーザー確認
- `--auto`: 確認なしで実行（上級者向け）

### 2. タスクタイプ判定

以下のキーワードで判定（複数該当時は先頭優先）:

| 優先度 | キーワード（正規表現） | タスクタイプ |
|--------|----------------------|------------|
| 1 | `緊急\|hotfix\|本番\|production` | 緊急対応 |
| 2 | `修正\|fix\|バグ\|エラー\|不具合` | バグ修正 |
| 3 | `リファクタ\|改善\|整理\|見直し` | リファクタリング |
| 4 | `ドキュメント\|仕様書\|README\|docs` | ドキュメント |
| 5 | `テスト\|test\|spec` | テスト作成 |
| 6 | `追加\|実装\|作成\|新規\|機能` | 新機能実装 |
| 7 | （上記に該当しない） | 新機能実装（デフォルト） |

### 3. Task tool で workflow-orchestrator を起動

```
Task(
  subagent_type: "workflow-orchestrator",
  prompt: """
    タスク: {タスク内容}
    タスクタイプ: {判定結果}
    オプション: {解析結果}

    上記に基づいてワークフローを実行してください。
  """
)
```

### 4. workflow-orchestrator の動作

エージェントは以下を実行:

1. **TodoWrite でワークフロー計画を作成**
2. **各ステップを Skill tool で順次実行**
   - `/prd`, `/plan`, `/dev` 等
3. **Plan モード推奨時はユーザーに通知**（切り替えはユーザー操作）
4. **進捗を TodoWrite で更新**
5. **エラー時は AskUserQuestion でリトライ/スキップを確認**

### Boris流の統合ルール

- **Plan モード推奨**: 新機能実装・リファクタリング時にユーザーへ通知
- **code-simplifier**: 実装・リファクタリング後に必ず実行（--skip-simplify除く）
- **verify-app**: PR作成前に必ず実行
- **/commit-push-pr**: ワークフロー最終ステップで実行

## 例

### 例1: 新機能実装

```bash
ユーザー: /flow ユーザー認証機能を追加

Claude:
📊 タスクタイプ判定: 新機能実装
📋 ワークフロー: PRD → Plan → Dev → Simplify → Test → Review → Verify → PR
⚠️ Plan モード推奨: はい

実行してよろしいですか？ [y/n]

→ y

# 以下、自動実行
✓ /prd 実行中...
⚠️ Plan モード推奨: 複雑なタスクです。Shift+Tab 2回でPlan モードに切り替えてください
✓ /plan 実行中...
✓ /dev 実行中...
✓ code-simplifier 実行中...
✓ /test 実行中...
✓ /review 実行中...
✓ verify-app 実行中...
✓ /commit-push-pr 実行中...

🎉 ワークフロー完了！
PR: https://github.com/user/repo/pull/123
```

## 注意事項

- **初回は --interactive 推奨**: ワークフローに慣れるまで各ステップで確認
- **緊急時は直接コマンド**: /flow より /debug → /dev が速い場合もある
- **カスタマイズ可**: workflow-orchestrator エージェントを編集してワークフロー調整可能
