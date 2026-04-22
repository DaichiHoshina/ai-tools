# Agents - エージェント一覧

Claude Codeで使用されるエージェント（自律的なサブプロセス）の説明とマッピング。

> **CLIコマンド**: `claude agents` で設定済みエージェントの一覧を表示できます（v2.1.47+）

## エージェント一覧

| エージェント | model | 役割 | 主な用途 |
|------------|-------|------|---------|
| **reviewer-agent** | opus | レビュー担当 | コード品質・セキュリティ・テストレビュー |
| **root-cause-analyzer** | opus | 根本原因分析 | バグの5Whys分析・構造的修正提案 |
| **po-agent** | sonnet | 戦略決定担当 | プロダクト戦略・Worktree管理・Manager 起動 |
| **manager-agent** | sonnet | タスク分割・配分・Developer 並列起動 | 大規模タスクのサブタスク管理・統合 |
| **developer-agent** | haiku | 実装担当 | コード実装・修正・追加 |
| **explore-agent** | haiku | 探索・分析担当 | コードベース調査・並列探索 |
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

### `/flow` のワークフロー（自走型階層起動）

各層が **自分で次の層を起動** する。親（Claude Code）は PO を呼ぶだけで以下が連鎖する。

```
1. 親 → Task(po-agent) 起動
   ↓ タスク分析 → Team使用判断（デフォルト: Team）
   ↓
2. PO → Task(manager-agent) 自走起動（Team使用時のみ）
   ↓ タスク分割・配分計画
   ↓
3. Manager → Task(developer-agent) × N を 1メッセージで並列起動
   ↓ 実装 → 全Developer完了を統合
   ↓
4. Manager → 統合結果を PO に返却
   ↓
5. PO → 結果を親に返却（ここで PO 完了）
   ↓
6. 親 → /lint-test → /review(reviewer-agent) → /git-push --pr
```

**直接実行推奨時**: PO が判断結果を親に返し、親が `/dev` を起動（Step 2-5 スキップ）。

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

- **トリガー**: PO Agent が Team使用判断時に自走起動
- **役割**: タスク分割・配分計画・Developer 並列起動・完了統合（実装なし）
- **特徴**: `Task(developer-agent)` を 1メッセージで並列呼び出し、全完了まで管理

### 5. po-agent

- **トリガー**: `/flow`（常時起動）, `/plan`
- **役割**: 実行モード判断・戦略決定・Worktree管理・Manager 起動（実装なし）
- **特徴**: Team使用判断時は **自ら `Task(manager-agent)` を起動** し完了まで待機

### 6. verify-app

- **トリガー**: PR作成前に**必ず自動起動**
- **役割**: ビルド・テスト・lintの包括検証
- **特徴**: 失敗時は自動修正フローに入る

---

## エージェント階層（Agent Hierarchy）

大規模タスクでは階層構造で実行。各層が **自分で次の層を起動** する自走型。

```
親（Claude Code）
  └─ Task(po-agent)              # 戦略・Team判断
       └─ Task(manager-agent)    # PO が自走起動
            ├─ Task(developer-agent) dev1  # Manager が並列起動
            ├─ Task(developer-agent) dev2
            └─ Task(developer-agent) dev3
  └─ verify-app                  # 実装完了後、親が起動
  └─ Task(reviewer-agent)        # 最終レビュー
```

**設計原則**: 各 Agent の `tools` に次層の `Task(...)` を持たせ、親のハンドリング漏れを防ぐ。

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
