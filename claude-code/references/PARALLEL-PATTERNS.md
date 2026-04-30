# 並列実行パターン

> **目的**: agent / worktree 並列を critical path 短縮ファーストで判断、責務を本ファイルに単一ソース化

このファイルは並列実行に関する判断基準・責務分離・worktree 適用判定の **正典**。manager-agent、po-agent、developer-agent、agents/README、session-management の各ファイルは詳細を再記述せず、本ファイルへの参照リンクのみ持つ。

## 用語定義

| 用語 | 定義 |
|---|---|
| **N** | 並列起動する Developer 数（= 並列 worktree 数）、`N = min(独立タスク数, 4)` |
| 同時セッション数 | 親 + 並列 Developer 数、最大 5 |
| Team 経路 | `/flow --parallel`、PO → Manager → Developer×N |
| 直接実行 | `/dev --parallel`、PO/Manager 経由なし、Developer×N のみ |
| **T_i** | タスク i の所要時間見積もり（実装 + テスト + lint + 自己確認を含む） |
| **LPT_makespan(T_i, N)** | LPT (Longest Processing Time) で N lane に割当てた最遅 lane 合計時間 |

### 4 Developer 上限の根拠

`同時セッション数 = 親 Claude Code + Developer × N <= 5` より `N <= 4`。5 同時セッション上限の根拠は通知洪水と context 追跡破綻（`references/session-management.md` 参照）。

## critical path 短縮判定式

### 共通形式

```text
expected_serial   = sum(T_i)
expected_parallel = LPT_makespan(T_i, N) + overhead(N)
採用条件: expected_parallel < expected_serial × 0.7
```

### LPT スケジューリング

```text
1. T_i 降順ソート
2. 各タスクを現在最も合計時間が短い lane に割当
3. makespan = max(各 lane の合計時間)
```

簡略化:
- 独立タスク数 = N: `LPT_makespan = max(T_i)`
- 独立タスク数 > N: 上記アルゴリズム適用

### N 選択ルール

```text
N_initial = min(独立タスク数, 4)
判定式 FAIL → N を 1 減らして再判定（N>=2）
N=1 → 順次実行
```

### T_i 見積もり優先順位

1. 過去実測（`references/performance-insights.md` の N>=20 サンプル）
2. Manager のタスク分解結果（変更ファイル数 × 単位時間）
3. 簡易ルール（実装+テスト+lint+自己確認込み）:
   - 単純編集（typo、import 修正）: 30s
   - ロジック追加（既存関数修正 + 単体テスト）: 60s
   - 新機能（新規ファイル + テスト + lint）: 120s
   - 複雑機能（複数ファイル横断 + 統合テスト）: 300s
4. 不明時: 保守的最大値、または並列化見送り

### コスト分解

| コスト | 値 | 性質 |
|---|---|---|
| `orchestration_cost`（Team） | 138s | PO 96s + Manager 42s（performance-insights.md 実測） |
| `integration_cost`（Team） | 42s | Manager 再起動 |
| `integration_cost`（直接） | 20s | 衝突確認 |
| `spawn_cost(N)` | 20N | Developer 起動 17s + 通知 → 20s/Dev に丸め |
| `worktree_setup_cost(N)` | **N**（実測 0.09s/wt 切り上げ） | git worktree add 平均 90ms、保守的に 1s/wt |
| `failure_retry` | 判定式から除外 | リスク注記: Developer 30 分タイムアウト × 2 リトライで最悪 60 分追加 |

> **実測補正**: 当初仮置き値 `worktree_setup_cost = 20N` を Phase 1 計測（5 サンプル平均 90ms）で `1N` に補正済。

### Team 経路（`/flow --parallel`、worktree あり）

```text
overhead_team(N) = orchestration_cost + integration_cost + spawn_cost(N) + worktree_setup_cost(N)
                 = 138 + 42 + 20N + N = 180 + 21N
採用条件: LPT_makespan(T_i, N) + 180 + 21N < sum(T_i) × 0.7
```

**等サイズタスク + 独立タスク数 = N の簡略化目安** (`LPT_makespan = T_task`):

| N | 必要 T_task | 評価 |
|---|---|---|
| 2 | 555s 超 | 原則非推奨 |
| 3 | 221s 超 | 原則非推奨 |
| 4 | 147s 超 | **第一候補** |

### 直接実行（`/dev --parallel`、worktree あり）

```text
overhead_direct(N) = spawn_cost(N) + worktree_setup_cost(N) + integration_cost
                   = 20N + N + 20 = 21N + 20
採用条件: LPT_makespan(T_i, N) + 21N + 20 < sum(T_i) × 0.7
```

**等サイズ簡略化目安**:

| N | 必要 T_task | 評価 |
|---|---|---|
| 2 | 155s 超 | 採用可（厳しめ） |
| 3 | 76s 超 | 採用可 |
| 4 | 58s 超 | **第一候補** |

加えて以下も必須:
- 独立タスク 2 件以上
- 編集対象が完全分離（同一ディレクトリでもファイル単位重複なし）

## worktree 適用判定フロー

```text
判定式 PASS かつ 独立タスク 2 件以上
  ├─ Yes → 同一ファイル編集なし?
  │         ├─ Yes → worktree 並列適用候補（PO 確認 or --auto 4 条件）
  │         └─ No  → 順次実行
  └─ No  → 順次実行
```

### `/flow --parallel --auto` 確認スキップ 4 条件

1. Team 判定式 PASS
2. clean worktree（git status 変更なし、stash も無し）
3. branch / worktree 名衝突なし
4. 作成失敗時の自動フォールバック（順次実行降格 + ユーザー通知）

### `/dev --parallel --auto` 確認スキップ 4 条件

1. 直接実行判定式 PASS（+ 独立 2 件 + 完全分離）
2. clean worktree
3. branch / worktree 名衝突なし
4. 作成失敗時の自動フォールバック

### 後片付け方針（共通）

- 変更ありの worktree: ブランチ返却、親がマージ、worktree 削除
- 変更なしの worktree: 自動削除
- マージ衝突: 順次実行降格、worktree 残置してユーザー引き継ぎ

## 責務分離

| 役割 | 担当 |
|---|---|
| worktree 作成可否判断 | PO Agent（ユーザー確認必須、--auto 4 条件で代替） |
| 並列実行起動 | flow / dev / 親（Claude Code） |
| タスク配分・並列度決定 | Manager Agent（Team 経路のみ） |
| worktree 内作業 | Developer Agent |

## 禁止語句定義（bats 検証対象）

### 検証対象ファイル

target_files:
- agents/manager-agent.md
- agents/po-agent.md
- agents/developer-agent.md
- agents/README.md
- references/session-management.md

注: 本ファイル（PARALLEL-PATTERNS.md）は定義元のため検証対象外。

### 禁止語句

forbidden_phrases:
- "パターン1: 完全並列実行"
- "パターン2: 段階的実行"
- "パターン3: 順次実行"
- "同一ファイル変更? → Yes → 順次"

### 許可される要約文

allowed_summaries:
- "並列実行パターン詳細: references/PARALLEL-PATTERNS.md 参照"
- "worktree 適用判定: references/PARALLEL-PATTERNS.md#worktree 適用判定フロー 参照"

### 更新マーカー regex（bats 境界別 skip 判定）

```regex
references/PARALLEL-PATTERNS\.md(#[a-zA-Z0-9_-]+)?
```

## 関連ドキュメント

- `claude-code/agents/manager-agent.md` - タスク配分、Manager の役割
- `claude-code/agents/po-agent.md` - 戦略決定、worktree 確認責務
- `claude-code/agents/developer-agent.md` - 並列実行時の振る舞い
- `claude-code/commands/flow.md` - `/flow --parallel` 仕様
- `claude-code/commands/dev.md` - `/dev --parallel` 仕様
- `claude-code/references/performance-insights.md` - agent 実時間実測
- `claude-code/references/session-management.md` - 5 同時セッション上限
