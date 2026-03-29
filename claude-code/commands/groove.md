---
name: groove
description: 軽量マルチエージェントオーケストレーター。YAMLワークフロー定義に従い、複数のAgentを協調実行する。外部依存なし。
---

# /groove - マルチエージェントオーケストレーター

## 使用方法

```text
/groove <workflow> <task>
/groove list
```

## 引数解析

| パターン | 動作 |
|---------|------|
| `/groove list` | `.groove/workflows/`のワークフロー一覧表示 |
| `/groove spec-driven タスク` | 指定ワークフローで実行 |
| `/groove タスク` | デフォルト`spec-driven`で実行 |

## オーケストレーション実行手順

**このコマンドを受けたら、以下のループを自分自身（メインAgent）が直接実行する。外部CLIやカスタムAgent typeは使わない。**

### 1. 初期化

1. `.groove/workflows/{name}.yaml`をReadで読み込む
2. 実行IDを生成: `date +%Y%m%d-%H%M%S`
3. `.groove/runs/{id}/`を作成、`state.json`を書き込む:
   ```json
   {"workflow":"名前","task":"タスク","run_id":"ID","current_step":"最初のstep","step_count":0,"loop_count":{},"status":"running","history":[]}
   ```

### 2. ステップ実行ループ

`current_step`がCOMPLETE/ABORTになるまで繰り返す:

```
WHILE current_step != COMPLETE && current_step != ABORT:
  1. state.json読み込み
  2. step_count >= max_steps → ABORT
  3. loop_count[current_step] >= loop_limit → ABORT
  4. YAMLからステップ定義取得
  5. Agent起動（下記ルール）
  6. Agent出力から GROOVE_RESULT: を抽出
  7. rulesマッチングで次ステップ決定
  8. レポート保存: .groove/runs/{id}/{step}-{n}.md
  9. state.json更新
```

### 3. Agent起動ルール

#### 通常ステップ

`.groove/agents/{agent名}.md`をReadで読み込み、その内容をpromptに含める:

```
Agent(
  subagent_type: "general-purpose",
  mode: edit→"bypassPermissions" / readonly→"default",
  prompt: "{Agent定義の内容}\n\n## タスク\n{タスク内容}\n\n## 前ステップのレポート\n{直前レポート}"
)
```

#### parallelステップ

**単一メッセージ内で複数のAgent tool callを並列発行する。**

結果集約（優先順位順）:
1. いずれかがspec_issue → `spec_issue`
2. いずれかがfail → `any_fail`
3. 全てpass → `all_pass`

#### ask_user: true

needs_inputの場合、GROOVE_QUESTIONの内容でAskUserQuestionを呼び、回答を追加して再実行。

### 4. 結果解析

Agent出力から`GROOVE_RESULT: {値}`を検索。見つからない場合:
- edit mode → `done`
- readonly mode → `pass`

### 5. 完了処理

結果レポートを`.groove/runs/{id}/result.md`に保存し、実行履歴を表示。

## YAML構造

```yaml
name: ワークフロー名
description: 説明
max_steps: 25
loop_limit: 3

steps:
  - name: ステップ名
    agent: Agent定義名     # .groove/agents/{name}.md
    mode: readonly|edit
    rules:
      - on: イベント名
        next: ステップ名|COMPLETE|ABORT
        ask_user: true     # オプション

  - name: 並列ステップ名   # parallel版
    parallel:
      - agent: Agent1
        mode: readonly
      - agent: Agent2
        mode: readonly
    rules:
      - on: all_pass
        next: 次ステップ
      - on: any_fail
        next: 修正ステップ
```

## 利用可能ワークフロー

| ワークフロー | 説明 |
|-------------|------|
| `spec-driven` | 仕様レビュー→Codexレビュー→実装→受入検査→修正→簡素化 |
| `tdd` | テスト作成→実装→レビュー→修正（TDD） |
