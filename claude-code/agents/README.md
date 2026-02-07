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
| `/flow` | workflow-orchestrator | タスク自動判定 → 複数エージェント起動 |
| `/dev` | developer-agent | 直接実装（単純） or manager-agent経由（複雑） |
| `/review` | reviewer-agent | レビュー自動実行 |
| `/plan` | po-agent + manager-agent | 戦略策定 + タスク分割 |
| `/explore` | explore-agent（並列） | 複数観点から同時調査 |
| `/refactor` | developer-agent → code-simplifier | 実装 → 簡素化 |
| `/test` | developer-agent | テストコード作成 |

---

## 自動起動されるエージェント

ユーザーがコマンドを実行すると、内部で自動的にエージェントが起動されます：

### `/flow` のワークフロー例

```
1. workflow-orchestrator 起動
   ↓ タスクタイプ判定: 「新機能実装」
   ↓
2. po-agent 起動（PRD作成）
   ↓
3. manager-agent 起動（タスク分割）
   ↓
4. developer-agent 起動（実装）
   ↓
5. code-simplifier 起動（簡素化）
   ↓
6. verify-app 起動（ビルド・テスト）
   ↓
7. reviewer-agent 起動（最終レビュー）
```

### リファクタリングのワークフロー例

```
1. workflow-orchestrator 起動
   ↓ タスクタイプ判定: 「リファクタリング」
   ↓
2. manager-agent 起動（タスク分割）
   ↓
3. developer-agent 起動（実装）
   ↓
4. code-simplifier 起動（必須・複雑度削減）
   ↓
5. verify-app 起動（デグレ確認）
   ↓
6. reviewer-agent 起動（品質確認）
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

- **トリガー**: 複雑度判定で TaskDecomposition 以上
- **役割**: タスク分割と配分計画（実装なし）
- **特徴**: TaskCreate/TaskUpdate で管理

### 6. po-agent

- **トリガー**: `/plan`, 戦略的判断が必要な場合
- **役割**: プロダクト戦略・Worktree管理（実装なし）
- **特徴**: 読み取り専門、意思決定支援

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
