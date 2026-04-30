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

## エージェント起動コスト（subagent-events.log 実測）

| agent | N | 平均実時間 | 最大 | 備考 |
|-------|---|-----------|------|------|
| developer-agent | 2* | 17s | 23s | 最速、タスク明確時 |
| manager-agent | 2* | 42s | 68s | 計画のみで軽量 |
| reviewer-agent | 27 | 82s | 161s | Opus + comprehensive-review |
| po-agent | 9* | 96s | 365s | 戦略判断で膨らむ |
| Explore (built-in) | 79 | 99s | 310s | 使用頻度最多 |
| general-purpose | 21 | **115s** | **501s** | **使用を避ける** |
| explore-agent | 7* | 123s | 289s | Haikuだがタスク範囲広く実時間長い |

`*` は N<10 の参考値（サンプル少、母数拡大で値ブレうる）。運用判断は使用頻度の多い agent（N≥20）の傾向を優先。

**再計算**: `~/.claude/hooks/subagent-events.log` を `references/performance-insights.md` の集計スクリプトで処理（最終更新日は `git log -1 --format=%cs agents/README.md` で取得可）。

運用ルール（判定表）は `claude-code/CLAUDE.md` の「探索・調査の使い分け」、計測方法・hook vs agent のコスト構造は [`references/performance-insights.md`](../references/performance-insights.md) 参照。

---

## コマンド→エージェントマッピング

| コマンド | 起動されるエージェント | フロー |
|---------|---------------------|--------|
| `/flow` | po-agent（軽量タスク事前判定で skip 可、それ以外は起動） | 親が PO → Manager → Developer × N を順次起動（Teamデフォルト） |
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
   ↓ PO: 実行モード判断・Reviewer 品質基準 → 判断結果を親に返却
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
5. 親 → Task(reviewer-agent, --codex) 起動（comprehensive-review + codex 並列、両者共通指摘を優先）
   ↓ Reviewer: P0/P1 分類で返却
   ↓ P0 あり → 親 → Task(manager-agent) 再配分 → Task(developer-agent)×M → Task(reviewer-agent, --codex) 再検証（最大1ループ）
   ↓ P0 = 0
   ↓
6. 親 → /lint-test → /git-push --pr
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

- **トリガー**: `/flow`（軽量タスク事前判定で skip 可、それ以外は起動）, `/plan`
- **役割**: 実行モード判断・戦略決定・Worktree管理・Manager への指示フォーマット作成（実装なし）
- **特徴**: 判断結果（モード・worktree・Manager 指示）を親に返却。親が次層を起動

### 6. verify-app

- **トリガー**: 明示要求時のみ（自動起動しない）。通常の検証は `/lint-test` を使用
- **役割**: ビルド・テスト・lintの包括検証（structural change 等で `/lint-test` で不足な場合）
- **特徴**: 失敗時は Developer に差し戻し（自動修正は行わない）

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
  ├─ /lint-test                  # 実装完了後の検証（verify-app は明示要求時のみ）
  └─ Task(reviewer-agent)        # 最終レビュー
```

**設計原則**:
- sub-agent は他 sub-agent を spawn できない（Claude Code 仕様）
- PO/Manager/Explore には `disallowedTools: Write, Edit, MultiEdit` を明示し、実装違反を物理防止
- 並列起動は親が 1メッセージで複数 `Task` を同時呼び出しする
- 並列実行パターン詳細・worktree 適用判定・責務分離: `references/PARALLEL-PATTERNS.md` 参照

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
