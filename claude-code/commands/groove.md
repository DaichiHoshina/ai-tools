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

## 実行フロー

### 引数解析

| パターン | 動作 |
|---------|------|
| `/groove list` | `.groove/workflows/`内のワークフロー一覧を表示 |
| `/groove spec-driven タスク内容` | 指定ワークフローでタスクを実行 |
| `/groove タスク内容` | ワークフロー未指定 → `spec-driven`をデフォルト使用 |

### 実行

groove-orchestrator Agentを起動する:

```
Agent(
  subagent_type: "groove-orchestrator",
  mode: "bypassPermissions",
  prompt: "ワークフロー: {workflow}\nタスク: {task}"
)
```

### list

```bash
ls .groove/workflows/*.yaml
```

各YAMLのname + descriptionを表示する。

## ワークフロー定義

`.groove/workflows/`にYAMLファイルとして配置。

### YAML構造

```yaml
name: ワークフロー名
description: 説明
max_steps: 25        # ステップ実行上限
loop_limit: 3        # 同一ステップのループ上限

steps:
  - name: ステップ名
    agent: Agent定義名  # .groove/agents/{name}.md
    mode: readonly|edit
    rules:
      - on: イベント名
        next: 次ステップ名|COMPLETE|ABORT
        ask_user: true  # オプション
```

### 並列ステップ

```yaml
  - name: ステップ名
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

### Agent定義

`.groove/agents/{name}.md`にMarkdownで配置。各Agentは最後に`GROOVE_RESULT: {結果}`を出力する。

## 利用可能ワークフロー

| ワークフロー | 説明 |
|-------------|------|
| `spec-driven` | 仕様レビュー→実装→受入検査→修正→簡素化 |
