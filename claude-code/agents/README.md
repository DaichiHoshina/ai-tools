# Agents - エージェント一覧

Claude Codeで使用されるエージェント（自律的なサブプロセス）の説明とマッピング。

> **CLIコマンド**: `claude agents` で設定済みエージェントの一覧を表示できます（v2.1.47+）

## エージェント一覧

| エージェント | model | 役割 | 主な用途 |
|------------|-------|------|---------|
| **reviewer-agent** | opus | レビュー担当 | コード品質・セキュリティ・テストレビュー |
| **root-cause-analyzer** | opus | 根本原因分析 | バグの5Whys分析・構造的修正提案 |
| **po-agent** | sonnet | 戦略決定担当 | プロダクト戦略・Worktree管理・判断結果返却 |
| **manager-agent** | sonnet | タスク分割・配分計画作成 | 大規模タスクの配分計画・完了時の統合検証 |
| **developer-agent** | haiku | 実装担当 | コード実装・修正・追加 |
| **explore-agent** | haiku | 探索・分析担当 | コードベース調査・並列探索 |
| **verify-app** | haiku | 検証担当 | ビルド・テスト・lintの統合検証 |

---

## コマンド→エージェントマッピング

| コマンド | 起動されるエージェント | フロー |
|---------|---------------------|--------|
| `/flow` | po-agent（常時起動） | 親が PO → Manager → Developer × N を順次起動（Teamデフォルト） |
| `/dev` | なし（直接実行） | Agent不使用。Agent Teamが必要なら `/flow` を使用 |
| `/review` | reviewer-agent | レビュー自動実行 |
| `/plan` | po-agent + manager-agent | 戦略策定 + タスク分割 |
| `/explore` | explore-agent（並列） | 複数観点から同時調査 |

---

## 自動起動されるエージェント

ユーザーがコマンドを実行すると、内部で自動的にエージェントが起動されます：

### `/flow` のワークフロー（親ハンドリング型）

Claude Code の sub-agent 仕様上、sub-agent は他の sub-agent を spawn できない。**親（Claude Code）が各層を順次起動**する。

```
1. 親 → Task(po-agent) 起動
   ↓ PO: 実行モード判断 → 判断結果を親に返却
   ↓
2. 親 → Task(manager-agent) 起動（Team使用時）
   ↓ Manager: 配分計画を親に返却
   ↓
3. 親 → Task(developer-agent) × N を 1メッセージで並列起動
   ↓ 全 Developer 完了
   ↓
4. 親 → Task(manager-agent) 再起動（統合検証）
   ↓ Manager: 統合結果を返却
   ↓
5. 親 → /lint-test → /review(reviewer-agent) → /git-push --pr
```

**直接実行推奨時**: PO が判断結果を親に返し、親が `/dev` を起動（Step 2-4 スキップ）。

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

- **トリガー**: PO が Team使用判断時、親が起動
- **役割**: タスク分割・配分計画作成・完了時の統合検証（実装なし、Developer 起動は親が担当）
- **特徴**: 配分計画フォーマットを親に返し、親が `Task(developer-agent)` を並列起動

### 5. po-agent

- **トリガー**: `/flow`（常時起動）, `/plan`
- **役割**: 実行モード判断・戦略決定・Worktree管理・Manager への指示フォーマット作成（実装なし）
- **特徴**: 判断結果（モード・worktree・Manager 指示）を親に返却。親が次層を起動

### 6. verify-app

- **トリガー**: PR作成前に**必ず自動起動**
- **役割**: ビルド・テスト・lintの包括検証
- **特徴**: 失敗時は自動修正フローに入る

---

## エージェント階層（Agent Hierarchy）

大規模タスクでは階層構造で実行。**親（Claude Code）が各層を順次起動**する親ハンドリング型（sub-agent 仕様準拠）。

```
親（Claude Code）
  ├─ Task(po-agent)              # 戦略・Team判断 → 返却
  ├─ Task(manager-agent)         # 配分計画 → 返却
  ├─ Task(developer-agent) dev1  ┐ 1メッセージで
  ├─ Task(developer-agent) dev2  │ 並列起動
  ├─ Task(developer-agent) dev3  ┘
  ├─ Task(manager-agent)         # 統合検証（再起動）
  ├─ verify-app                  # 実装完了後
  └─ Task(reviewer-agent)        # 最終レビュー
```

**設計原則**:
- sub-agent は他 sub-agent を spawn できない（Claude Code 仕様）
- PO/Manager/Explore には `disallowedTools: Write, Edit, MultiEdit` を明示し、実装違反を物理防止
- 並列起動は親が 1メッセージで複数 `Task` を同時呼び出しする

> **⚠️ この設計を変更する前に必ず読む**: [ADR 0001: Agent Team は親ハンドリング型で構築する](../../docs/adr/0001-parent-handled-agent-hierarchy.md) — 自走型への回帰は公式 docs 違反のため不可。回帰防止の bats テスト `tests/integration/agent-frontmatter.bats` が CI で守っている。

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
