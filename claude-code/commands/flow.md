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

- 変更ファイルあり → 既存作業の続き
- 変更なし → 新規タスク

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
2. Shift+Tab 2回                  # Plan モード開始
3. /plan {PRD}                    # 設計
4. /dev {設計}                    # 実装
5. code-simplifier {変更ファイル} # 簡素化
6. /test {機能}                   # テスト作成
7. /review                        # レビュー
8. verify-app                     # 検証
9. /commit-push-pr                # PR作成

# ユーザーへの確認ポイント
- PRD内容確認
- Plan内容確認
- 実装後の簡素化確認
- PR作成前の最終確認
```

### 2. バグ修正（高速）

```bash
# 実行されるコマンド
1. /debug {エラー内容}            # 問題特定
2. /dev {修正内容}                # 修正実装
   → PostToolUse フック自動実行   # 自動フォーマット
3. verify-app テストのみ          # テスト確認
4. /commit-push-pr -m "fix: ..."  # PR作成

# ユーザーへの確認ポイント
- 修正内容確認
- テスト結果確認
- コミットメッセージ確認
```

### 3. リファクタリング（品質重視）

```bash
# 実行されるコマンド
1. Shift+Tab 2回                  # Plan モード開始
2. /plan {リファクタリング内容}   # 計画
3. /refactor {計画}               # リファクタリング実行
4. code-simplifier 全ファイル     # 簡素化（重要）
5. /review                        # アーキテクチャレビュー
6. verify-app                     # 検証
7. /commit-push-pr --draft        # ドラフトPR

# ユーザーへの確認ポイント
- Plan内容確認
- 簡素化結果確認
- レビュー結果確認
- ドラフトPR作成確認
```

### 4. ドキュメント整備

```bash
# 実行されるコマンド
1. /explore {対象機能}            # 並列調査
2. /docs {ドキュメント種類}       # ドキュメント作成
3. /review                        # ドキュメントレビュー
4. /commit-push-pr -m "docs: ..." # PR作成

# ユーザーへの確認ポイント
- ドキュメント内容確認
- コミットメッセージ確認
```

### 5. 緊急対応（最速）

```bash
# 実行されるコマンド
1. /debug {緊急エラー}            # 問題特定
2. /dev hotfix実装                # 即座に修正
3. verify-app テストのみ          # 最小限の検証
4. /commit-push-pr -m "hotfix: ..." # 即座にPR

# ユーザーへの確認ポイント
- 修正内容確認（簡潔に）
- PR作成確認
```

### 6. テスト作成

```bash
# 実行されるコマンド
1. /test {対象機能}               # テスト作成
2. /review                        # テスト品質レビュー
3. verify-app テストのみ          # テスト実行確認
4. /commit-push-pr -m "test: ..." # PR作成

# ユーザーへの確認ポイント
- テスト内容確認
- テスト結果確認
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

## 実装ロジック

### workflow-orchestrator エージェント使用

`workflow-orchestrator` エージェントが以下を担当:

1. **タスクタイプ判定** - プロンプト分析
2. **ワークフロー選択** - 最適なワークフロー決定
3. **Plan モード判断** - 必要に応じてPlan モード推奨
4. **ステップ実行** - 各コマンド/スキルを順次実行
5. **進捗管理** - TodoWrite で進捗可視化
6. **エラーハンドリング** - 失敗時のリトライ/スキップ判断

### Boris流の統合

- **Plan モード自動判断**: 複雑なタスクでは自動でPlan モード推奨
- **code-simplifier 自動実行**: 実装/リファクタリング後は必ず実行
- **verify-app 自動実行**: PR前の品質保証
- **/commit-push-pr 自動実行**: ワークフロー完了後に自動でPR作成

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
✓ Plan モード開始...
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

### 例2: バグ修正

```bash
ユーザー: /flow この認証エラーを修正

Claude:
📊 タスクタイプ判定: バグ修正
📋 ワークフロー: Debug → Dev → Verify(test) → PR
⚠️ Plan モード推奨: いいえ

実行してよろしいですか？ [y/n]

→ y

# 以下、自動実行
✓ /debug 実行中...
✓ /dev 実行中...
✓ verify-app テストのみ実行中...
✓ /commit-push-pr 実行中...

🎉 ワークフロー完了！
```

## Boris流の活用

- **"良い計画は本当に重要"** → 複雑なタスクで自動的にPlan モード推奨
- **"Claude に検証手段を与える"** → 常に verify-app を実行
- **"毎日何十回も使用"** → /commit-push-pr を自動実行
- **"最後の10%を仕上げる"** → PostToolUse フックで自動フォーマット
- **"簡素化で品質向上"** → code-simplifier を自動実行

## 注意事項

- **初回は --interactive 推奨**: ワークフローに慣れるまで各ステップで確認
- **緊急時は直接コマンド**: /flow より /debug → /dev が速い場合もある
- **カスタマイズ可**: workflow-orchestrator エージェントを編集してワークフロー調整可能
