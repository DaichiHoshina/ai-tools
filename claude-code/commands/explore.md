---
allowed-tools: Read, Glob, Grep, Bash, Task, mcp__serena__check_onboarding_performed, mcp__serena__find_file, mcp__serena__find_referencing_symbols, mcp__serena__find_symbol, mcp__serena__get_symbols_overview, mcp__serena__list_dir, mcp__serena__list_memories, mcp__serena__read_memory, mcp__serena__search_for_pattern
description: 並列探索コマンド - 複数の観点から同時調査
---

## /explore - 並列探索モード

> **重要**: 複数の観点から同時に調査し、効率的に情報を収集

## 1. 探索手順

### Step 1: 探索対象の確認

ユーザーの指示から以下を判断：
- 探索範囲（プロジェクト全体 or 特定機能）
- 主な調査目的（アーキテクチャ理解 / 機能調査 / 依存関係分析）
- 重点領域（Backend / Frontend / インフラ / テスト）

### Step 2: 観点の選択

#### 🔹 プロジェクト全体探索

全観点（explore1-4）を並列実行：
- **explore1**: アーキテクチャ全体像
  - ディレクトリ構造
  - 主要なエントリーポイント
  - 設定ファイル
- **explore2**: Backend/API 層
  - ハンドラー・コントローラー
  - ビジネスロジック
  - データモデル
- **explore3**: Frontend/UI 層
  - コンポーネント構造
  - ルーティング
  - 状態管理
- **explore4**: インフラ・テスト
  - CI/CD 設定
  - テスト構成
  - ビルド設定

#### 🔹 特定機能探索

関連観点のみ選択：

| 探索目的 | 選択する観点 |
|---------|-------------|
| API 機能調査 | explore1（構造） + explore2（Backend） |
| UI 機能調査 | explore1（構造） + explore3（Frontend） |
| テスト調査 | explore1（構造） + explore4（インフラ・テスト） |
| 依存関係分析 | explore1（構造） + explore2（Backend） + explore3（Frontend） |

### Step 3: Explore Agent 並列起動

#### 🔹 並列起動手順（重要：1メッセージで全Task呼び出し）

選択された観点を**同時に複数起動**：

1. **観点詳細の準備**
   - 各Exploreに渡す具体的な調査内容を準備
   - 探索範囲とフォーカスエリアを明確化

2. **並列実行（1メッセージで複数Task）**
   - 指定された観点数だけTask toolを同時呼び出し
   - 各Task toolのパラメータ:
     - `subagent_type`: "explore-agent"
     - `prompt`: Explore ID（explore1-4）+ 調査観点 + 探索範囲

3. **完了待機**
   - 全Exploreの完了を待機
   - エラー発生時は該当Exploreのログを確認

#### 🔹 エラーハンドリング

**部分的成功:**
- 一部のExploreのみ成功した場合も、取得できた結果は報告
- 失敗したExploreについては再実行を提案

**タイムアウト:**
- 長時間実行が予想される場合は、ユーザーに事前通知
- タイムアウトしたExploreは個別に再実行可能

**リトライ方針:**
- 自動リトライなし（手動で再実行を提案）
- 失敗原因を含めて報告

### Step 4: 結果集約

各Exploreの発見事項を以下の形式で報告：

- ✅/❌ 実行状態
- 観点ごとの主要な発見
- 統合サマリー（主要コンポーネント、技術スタック、注意点）
- 次のアクション提案

**エラー時**: 失敗理由を記載し、再実行を提案

## 2. 使用例

### 例1: 新規プロジェクト理解（全観点並列）

```
ユーザー: このプロジェクトの全体像を把握したい

選択される観点:
✅ explore1（アーキテクチャ全体像）
✅ explore2（Backend/API 層）
✅ explore3（Frontend/UI 層）
✅ explore4（インフラ・テスト）

実行方法: 4つのExploreを並列実行（同時呼び出し）
```

### 例2: API機能調査（関連観点のみ）

```
ユーザー: ユーザー認証APIの実装を調査したい

選択される観点:
✅ explore1（構造確認）
✅ explore2（Backend層の詳細）

実行方法: 2つのExploreを並列実行
```

## 3. 注意事項

- **Serena MCP優先**: ファイル探索は mcp__serena__* ツールを使用
- **並列実行がデフォルト**: 探索時間を最小化
- **観点の明確化**: 各Exploreに具体的な調査内容を指示
- **結果の構造化**: 次のアクションにつながる形で報告
- **エラー時の対応**: 部分的成功でも有用な情報を提供

## 4. 次のアクション

探索結果に基づいて適切なコマンドを提案：

- 実装が必要 → `/dev`
- 計画が必要 → `/plan`
- レビューが必要 → `/review`
- リファクタリングが必要 → `/refactor`
- テスト作成が必要 → `/test`
- デバッグが必要 → `/debug`
- ドキュメント作成が必要 → `/docs`
