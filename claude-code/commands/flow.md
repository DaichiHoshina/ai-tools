---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Task, AskUserQuestion, Skill, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*
description: ワークフロー自動化 - タスクタイプを自動判定して最適なワークフローを実行
---

## /flow - 自動ワークフロー実行

> **使い分け**: `/flow`（推奨）、`/dev`（実装のみ）

タスクを伝えるだけで、最適なワークフローを自動実行。

## タスクタイプ判定

**凡例**: `*実装*` は PO 判定に応じて以下のいずれかに展開される:

- **Team使用**: 親が `Task(po-agent)` → PO返却 → 親が `Task(manager-agent)` → Manager返却（配分計画） → 親が `Task(developer-agent)×N` を並列起動 → 親が `Task(manager-agent)` 再起動で統合
- **直接実行推奨**: `/dev`

> **仕様注意**: Claude Code の sub-agent は他の sub-agent を spawn できない（公式 docs）。各層は親が順次起動する。

| 優先度 | キーワード | タスクタイプ | ワークフロー |
|--------|-----------|------------|------------|
| 0 | 相談, アイデア, 設計検討, ブレスト, brainstorm | **設計相談** | /brainstorm → /prd → /plan |
| 1 | 緊急, hotfix, 本番, production, critical | **緊急対応** | /diagnose → *実装* → /lint-test → /git-push --pr |
| 1.5 | インシデント, 障害, incident, 調査して, エラーログ | **インシデント対応** | Skill(incident-response) → /diagnose → *実装* → /lint-test → /git-push --pr |
| 2 | 根本, 原因分析, root cause, rca | **バグ修正（RCA付き）** | /diagnose → Skill(root-cause) → *実装* → /lint-test → /git-push --pr |
| 3 | 修正, fix, バグ, エラー, 不具合, bug, error | **バグ修正** | /diagnose → *実装* → /lint-test → /git-push --pr |
| 4 | リファクタリング, 改善, 整理, refactor, improve | **リファクタリング** | /plan → *実装* → /lint-test → /test → /review → /git-push --pr |
| 5 | ドキュメント, 仕様書, README, docs | **ドキュメント** | /docs → /review → /git-push --pr |
| 6 | テスト, test, spec, testing | **テスト作成** | /test → /review → /lint-test → /git-push --pr |
| 7 | 追加, 実装, 作成, 新規, 機能, add, implement, create | **新機能実装** | /prd → /plan → *実装* → /test → /review → /lint-test → /git-push --pr |
| 8 | データ分析, 分析, analysis, データ | **データ分析** | Skill(data-analysis) → /docs → /git-push --pr |
| 9 | インフラ, terraform, kubernetes, k8s | **インフラ** | /plan → Skill(terraform) → /lint-test → /git-push --pr |
| 10 | トラブルシュート, troubleshoot, 調査, 診断 | **トラブルシュート** | /diagnose → *実装* → /docs |
| 11 | その他 | **新機能実装** | （デフォルト） |

## オプション

```text
--skip-prd      # PRDスキップ
--skip-test     # テストスキップ
--skip-review   # レビュースキップ
--no-po         # PO起動をスキップし直接実行（緊急時のみ）
--interactive   # 各ステップで確認
--auto          # 完全自律モード
```

## --auto 完全自律モード

| 判断ポイント | 動作 |
|-------------|------|
| AskUserQuestion | 呼ばない。推奨（1番目）を自動採用 |
| Agent起動 | `mode: "bypassPermissions"` で承認スキップ |
| push先 | 常にPR（main直pushは禁止） |
| PO Agent | スキップ（`--no-po`と同等） |
| 設計判断 | 推奨パターンを自動採用。迷ったらシンプルな方 |
| lint-test失敗 | 自動修正を1回試行。2回失敗で停止しユーザーに報告 |

autoフロー: タスク受領 → タスクタイプ自動判定 → ワークフロー自動実行 → lint-test → review-fix ループ → 秘匿情報チェック → /git-push → Serena memory保存 → 完了報告

### review-fix ループ

`--auto` 時、実装完了後に `/review` → 自動修正を **Critical 0件 + Warning 0件** になるまで繰り返す（最大3回）。3回到達しても残る場合 → 残件をユーザーに報告して続行。

## 実行ロジック

### Step 1: git status確認

- 変更ファイルあり → /prdスキップ、/devから開始を提案
- 変更なし → 新規タスクとして最初から実行

### Step 2: PO Agent起動（親が実行）

**`/flow` は常にPO Agentを起動する。** 複雑度の自己判定は行わない。

親（Claude Code）が `Task(po-agent)` を起動し、PO が判断結果を返す（`実行モード` / `Worktree情報` / `Manager への指示`）。`--no-po` 指定時のみ PO をスキップし、`/dev` で直接実行（緊急時のみ）。

### Step 3: 実装ステップの分岐（*実装* の展開）

PO の返却内容で分岐:

- **Team使用**:
  1. 親が `Task(manager-agent)` を起動し、PO の指示を prompt に含める
  2. Manager が配分計画（実行方式・Developer task prompt 群）を返す
  3. 親が `Task(developer-agent) × N` を **1メッセージで並列起動**（段階的実行時は Stage 毎に並列）
  4. 全 Developer 完了後、親が `Task(manager-agent)` を再起動して統合検証を依頼
  5. Manager が統合結果を返却 → 親が Step 4 に進む
- **直接実行推奨** → 親が `/dev` を起動
- **`--no-po`** → 親が `/dev` を起動

### Step 4: 後続ステップ

タスクタイプ判定表の *実装* 以降（/lint-test, /test, /review, /git-push 等）を順次実行。

## バグ修正: 複雑度による分岐

| レベル | 例 | フロー |
|--------|---|--------|
| Low | タイポ、インポートミス | /diagnose → *実装* → /lint-test → /review → /git-push --pr |
| Medium | ロジックバグ、検証漏れ | /diagnose → Skill(root-cause) → *実装* → /lint-test → /review → /git-push --pr |
| High | 競合状態、セキュリティ | /diagnose → Task(root-cause-analyzer) → *実装* → /lint-test → /review → /git-push --pr |

## 統合ルール

- **必須フロー**: 実装完了 → /lint-test → /review → review-fix ループ → /git-push
- **2回失敗ルール**: 同じアプローチで2回失敗 → `/clear` → 問題再整理 → 新アプローチ

### 完了時のアクション

- Serena memory保存（名前: work-context-YYYYMMDD-{topic}）
- `--auto`: 秘匿情報チェック → /git-push --pr → PushNotification（完了通知）
- 通常: AskUserQuestion「pushしますか？」→ PR/終了

### PushNotification（--auto時）

`--auto`モード完了時、PushNotification toolで結果を通知する。離席中の完了検知用。

- 成功: `"[flow-auto] {topic} 完了 → PR作成済み"`
- 失敗: `"[flow-auto] {topic} 失敗: {理由}"`
- lint-test 2回失敗停止: `"[flow-auto] {topic} 停止: lint-test 2回失敗、確認必要"`

## 自動適用機能（v2.1.50+）

| 機能 | 条件 | 動作 |
|------|------|------|
| worktree分離 | `--auto`で独立タスク並列時 | Agent `isolation: "worktree"` で自動作成・クリーンアップ |
| `/simplify` | 実装/修正ステップ後 | バンドルコマンドで高速実行 |
| background agents | `--auto`時のverify-app | 非同期検証 |

## worktree並列実行

独立した複数タスクをAgent `isolation: "worktree"` で並列実行する。

**使える場面:**
- 複数ファイル/モジュールの独立した修正
- レビューと実装の同時実行
- テスト作成と実装の並行

**Agent呼び出し:**
```
Agent(
  isolation: "worktree",
  mode: "bypassPermissions",
  prompt: "タスク内容とコンテキストを全て含める"
)
```

**注意:**
- 各worktreeは独立。前ステップの変更は見えない
- 変更ありのworktreeはブランチが返る → 親がマージ統合
- 変更なしのworktreeは自動クリーンアップ
- 逐次依存のあるタスクには使わない

ARGUMENTS: $ARGUMENTS
