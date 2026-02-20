# Agents - エージェント一覧

Claude Codeで使用されるエージェント（自律的なサブプロセス）の説明とマッピング。

## エージェント一覧

| エージェント | 役割 | 主な用途 |
|------------|------|---------|
| **workflow-orchestrator** | ワークフロー自動化 | タスクタイプ判定→最適ワークフロー実行 |
| **developer-agent** | 実装担当 | コード実装・修正・追加 |
| **reviewer-agent** | レビュー担当 | コード品質・セキュリティ・テストレビュー |
| **explore-agent** | 探索・分析担当 | コードベース調査・並列探索 |
| **manager-agent** | タスク分割・配分 | 大規模タスクのサブタスク管理 |
| **po-agent** | 戦略決定担当 | プロダクト戦略・Worktree管理 |
| **code-simplifier** | 簡素化担当 | 実装後の複雑度削減・重複統合 |
| **verify-app** | 検証担当 | ビルド・テスト・lintの統合検証 |

---

## コマンド→エージェントマッピング

| コマンド | 起動されるエージェント | フロー |
|---------|---------------------|--------|
| `/flow` | po-agent（常時起動） | PO → Manager → Developer（Teamデフォルト） |
| `/dev` | なし（直接実行） | Agent不使用。Agent Teamが必要なら `/flow` を使用 |
| `/review` | reviewer-agent | レビュー自動実行 |
| `/plan` | po-agent + manager-agent | 戦略策定 + タスク分割 |
| `/explore` | explore-agent（並列） | 複数観点から同時調査 |
| `/refactor` | developer-agent → code-simplifier | 実装 → 簡素化 |
| `/test` | developer-agent | テストコード作成 |

---

## 自動起動されるエージェント

ユーザーがコマンドを実行すると、内部で自動的にエージェントが起動されます：

### `/flow` のワークフロー例（2段階起動方式）

```
1. po-agent 起動（常時・必須）
   ↓ タスク分析 → Team使用判断（デフォルト: Team）
   ↓
2. manager-agent 起動（PO→Manager委任）
   ↓ タスク分割・Developer配分計画
   ↓
3. developer-agent × N 並列起動（実装）
   ↓
4. code-simplifier 起動（簡素化）
   ↓
5. verify-app 起動（ビルド・テスト）
   ↓
6. reviewer-agent 起動（最終レビュー）
```

---

## エージェントの特徴

### 1. workflow-orchestrator

- **トリガー**: `/flow` コマンド
- **役割**: タスクタイプ自動判定 + 最適ワークフロー選択
- **判定基準**: キーワード優先度テーブル（10種類のタスクタイプ）

### 2. developer-agent (dev1-4)

- **トリガー**: `/dev`, `/flow`, `/test`
- **役割**: 実装・修正・テスト作成
- **特徴**: Serena MCP必須使用（シンボル操作）

### 3. reviewer-agent

- **トリガー**: `/review`, `/flow` の最終ステップ
- **役割**: Writer/Reviewer並列パターンでのレビュー
- **特徴**: 実装完了後に自動起動

### 4. explore-agent (explore1-4)

- **トリガー**: `/explore`, 調査系タスク
- **役割**: 読み取り専用の並列探索
- **特徴**: Serena MCP必須、複数観点から同時調査

### 5. manager-agent

- **トリガー**: PO Agentからの委任
- **役割**: タスク分割と配分計画（実装なし）
- **特徴**: TaskCreate/TaskUpdate で管理

### 6. po-agent

- **トリガー**: `/flow`（常時起動）, `/plan`
- **役割**: 実行モード判断・戦略決定・Worktree管理（実装なし）
- **特徴**: Team使用をデフォルトで判断、Manager Agentを起動

### 7. code-simplifier

- **トリガー**: 実装・リファクタリング後に**必ず自動起動**
- **役割**: 複雑度削減・重複統合・可読性向上
- **特徴**: 非破壊的アプローチ（既存機能維持）

### 8. verify-app

- **トリガー**: PR作成前に**必ず自動起動**
- **役割**: ビルド・テスト・lintの包括検証
- **特徴**: 失敗時は自動修正フローに入る

---

## エージェント階層（Agent Hierarchy）

大規模タスクでは階層構造で実行：

```
po-agent (戦略)
  └─ manager-agent (タスク分割)
      ├─ developer-agent (実装1)
      ├─ developer-agent (実装2)
      └─ developer-agent (実装3)
          └─ code-simplifier (簡素化)
              └─ verify-app (検証)
                  └─ reviewer-agent (レビュー)
```

---

## 詳細情報

各エージェントの詳細は、対応する `.md` ファイルを参照：

- [workflow-orchestrator.md](./workflow-orchestrator.md)
- [developer-agent.md](./developer-agent.md)
- [reviewer-agent.md](./reviewer-agent.md)
- [explore-agent.md](./explore-agent.md)
- [manager-agent.md](./manager-agent.md)
- [po-agent.md](./po-agent.md)
- [code-simplifier.md](./code-simplifier.md)
- [verify-app.md](./verify-app.md)
