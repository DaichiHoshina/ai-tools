---
name: groove
description: 軽量マルチエージェントオーケストレーター。YAMLワークフロー定義に従い、複数のAgentを協調実行する。外部依存なし。
---

# /groove - マルチエージェントオーケストレーター

## 使用方法

```text
/groove <task>                    # ワークフロー自動選択
/groove <workflow> <task>         # ワークフロー指定
/groove --auto <task>             # 自動モード（COMPLETE後にcommit+push）
/groove list                      # ワークフロー一覧
```

## ワークフロー自動選択

| キーワード | ワークフロー |
|-----------|------------|
| VSDD, vsdd, 品質重視, 仕様駆動テスト | `vsdd` |
| テスト, TDD, test | `tdd` |
| それ以外 | `spec-driven` |

## パス解決（プロジェクト優先→ホームフォールバック）

| 種類 | 1st | 2nd |
|------|-----|-----|
| ワークフロー | `.groove/workflows/` | `~/.groove/workflows/` |
| Agent定義 | `.groove/agents/` | `~/.groove/agents/` |

## 実行手順

メインAgentが直接ループを回す。外部CLIは使わない。

### 1. 初期化

YAMLをReadで読み込み、最初のstepから開始。内部変数で状態管理（step_count, loop_count）。

### 2. ステップ実行ループ

```
WHILE current_step != COMPLETE && current_step != ABORT:
  1. step_count >= max_steps → ABORT
  2. loop_count[step] >= loop_limit → ABORT
  3. Agent定義をReadで読み込み
  4. Agent起動（下記ルール）
     - timeout定義あり → Agent起動時にtimeout(秒×1000)を設定
  5. 出力からGROOVE_RESULT:を抽出
     - Agent失敗/タイムアウト時 → retry処理へ
  6. rulesマッチングで次step決定
  7. step_count++, loop_count[step]++
```

### 2a. retry/timeout/fallback処理

```
ON agent_error OR timeout:
  IF retry_count[step] < step.retry (default: 0):
    retry_count[step]++
    → 同じステップを再実行（step_countは増加）
  ELSE IF step.fallback defined:
    → fallback.next で指定されたステップへ遷移
  ELSE:
    → rulesの on: blocked にマッチ、なければ ABORT
```

| フィールド | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `retry` | int | 0 | 失敗時の最大リトライ回数 |
| `timeout` | int | なし | ステップのタイムアウト（秒） |
| `fallback.next` | string | なし | 全リトライ失敗時の遷移先ステップ |

### 3. Agent起動ルール

**通常（逐次ステップ）:**
```
Agent定義のfrontmatter（---で囲まれた部分）からmodelフィールドを抽出。
Agent(
  subagent_type: "general-purpose",
  model: frontmatterのmodel値（haiku/sonnet/opus）、なければ省略,
  mode: edit→"bypassPermissions" / readonly→"default",
  prompt: "{Agent定義本文（frontmatter除く）}\n\n## タスク\n{task}\n\n## 前ステップ結果\n{prev_result}"
)
```
※逐次ステップではisolation不使用（前ステップの変更を参照する必要があるため）

**parallel:** 単一メッセージで複数Agent並列起動。edit modeのAgentには `isolation: "worktree"` を付与し、独立環境で作業させる。集約: spec_issue > any_fail > all_pass。worktreeに変更がある場合、結果のブランチをマージまたはチェリーピックで統合する。

**provider: codex:** Bash toolで`codex`コマンドを実行。未インストール時はpassでスキップ。

**ask_user: true:** needs_input時にAskUserQuestionで質問し、回答を追加して再実行。

### 4. 結果解析

`GROOVE_RESULT: {値}`を検索。見つからない場合: edit→`done` / readonly→`pass`

### 5. 完了

- COMPLETE → 実行履歴を表示。`--auto`なら`/git-push --pr`を実行 → PushNotification（`"[groove] {workflow}: {task} 完了"`）
- ABORT → 失敗理由を表示 → PushNotification（`"[groove] {workflow} ABORT: {理由}"`）

## 利用可能ワークフロー

| ワークフロー | 説明 |
|-------------|------|
| `spec-driven` | 仕様レビュー→Codexレビュー→実装→受入検査→修正→簡素化 |
| `tdd` | テスト作成→実装→レビュー→修正 |
| `vsdd` | 仕様レビュー→テスト→実装→敵対的レビュー（5次元評価）→修正→簡素化 |
