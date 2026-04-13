# Agents - エージェント一覧

Claude Codeで使用されるエージェント（自律的なサブプロセス）の説明とマッピング。

> **CLIコマンド**: `claude agents` で設定済みエージェントの一覧を表示できます（v2.1.47+）

## エージェント一覧

| エージェント | model | 役割 | 主な用途 |
|------------|-------|------|---------|
| **reviewer-agent** | opus | レビュー担当 | コード品質・セキュリティ・テストレビュー |
| **root-cause-analyzer** | opus | 根本原因分析 | バグの5Whys分析・構造的修正提案 |
| **developer-agent** | sonnet | 実装担当 | コード実装・修正・追加 |
| **po-agent** | sonnet | 戦略決定担当 | プロダクト戦略・Worktree管理 |
| **explore-agent** | sonnet | 探索・分析担当 | コードベース調査・並列探索 |
| **manager-agent** | haiku | タスク分割・配分 | 大規模タスクのサブタスク管理 |
| **verify-app** | haiku | 検証担当 | ビルド・テスト・lintの統合検証 |

---

## コマンド→エージェントマッピング

| コマンド | 起動されるエージェント | フロー |
|---------|---------------------|--------|
| `/flow` | po-agent（常時起動） | PO → Manager → Developer（Teamデフォルト） |
| `/dev` | なし（直接実行） | Agent不使用。Agent Teamが必要なら `/flow` を使用 |
| `/review` | reviewer-agent | レビュー自動実行 |
| `/plan` | po-agent + manager-agent | 戦略策定 + タスク分割 |
| `/explore` | explore-agent（並列） | 複数観点から同時調査 |

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
4. /simplify 実行（built-inスキル）
   ↓
5. verify-app 起動（ビルド・テスト）
   ↓
6. reviewer-agent 起動（最終レビュー）
```

---

## エージェントの特徴

### 1. developer-agent (dev1-4)

- **トリガー**: `/flow`（Team使用時、Manager経由で起動）
- **役割**: 実装・修正・テスト作成
- **特徴**: Serena MCP必須使用（シンボル操作）

### 2. reviewer-agent

- **トリガー**: `/review`, `/flow` の最終ステップ
- **役割**: Writer/Reviewer並列パターンでのレビュー
- **特徴**: 実装完了後に自動起動

### 3. explore-agent (explore1-4)

- **トリガー**: `/explore`, 調査系タスク
- **役割**: 読み取り専用の並列探索
- **特徴**: Serena MCP必須、複数観点から同時調査

### 4. manager-agent

- **トリガー**: PO Agentからの委任
- **役割**: タスク分割と配分計画（実装なし）
- **特徴**: TaskCreate/TaskUpdate で管理

### 5. po-agent

- **トリガー**: `/flow`（常時起動）, `/plan`
- **役割**: 実行モード判断・戦略決定・Worktree管理（実装なし）
- **特徴**: Team使用をデフォルトで判断、Manager Agentを起動

### 6. verify-app

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
          └─ /simplify (built-inスキル)
              └─ verify-app (検証)
                  └─ reviewer-agent (レビュー)
```

---

## 詳細情報

各エージェントの詳細は、対応する `.md` ファイルを参照：

- [developer-agent.md](./developer-agent.md)
- [reviewer-agent.md](./reviewer-agent.md)
- [root-cause-analyzer.md](./root-cause-analyzer.md)
- [explore-agent.md](./explore-agent.md)
- [manager-agent.md](./manager-agent.md)
- [po-agent.md](./po-agent.md)
- [verify-app.md](./verify-app.md)
