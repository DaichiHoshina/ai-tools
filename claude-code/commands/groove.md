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

メインAgentが直接ループを回す。外部CLIは使わない。スキーマ仕様は `~/.groove/schema.md` 参照。

### 1. 初期化

YAMLをReadで読み込み、最初のstepから開始。

- `version` フィールドを確認（未指定は v0 として警告のみ）
- `defaults` を抽出。各ステップの未指定フィールドに適用（ステップ値が優先）
- 内部変数で状態管理（step_count, loop_count, retry_count）

### 2. ステップ実行ループ

```text
WHILE current_step != COMPLETE && current_step != ABORT:
  1. step_count >= max_steps → ABORT
  2. loop_count[step] >= loop_limit → ABORT
  3. Agent定義をReadで読み込み
  4. Agent起動（下記ルール、defaults適用済みの値で）
  5. 出力から GROOVE_RESULT を抽出
     - Agent失敗/タイムアウト時 → retry処理へ
  6. rulesマッチングで次step決定
  7. step_count++, loop_count[step]++
```

### 2a. retry / error処理

```text
ON agent_error OR timeout:
  IF retry_count[step] < step.retry:
    retry_count[step]++
    → 同じステップを再実行
  ELSE:
    GROOVE_RESULT = error として rules評価
    → rules の on: error にマッチするnextへ遷移
    → 該当ルール未定義なら ABORT
```

v0 互換挙動の詳細は `~/.groove/schema.md#移行ルールv0--v1` を参照。

### 3. Agent起動ルール

**通常（逐次ステップ）:**

```text
Agent定義のfrontmatter から model を抽出。
Agent(
  subagent_type: "general-purpose",
  model: frontmatter.model（haiku/sonnet/opus）、なければ省略,
  mode: edit→"bypassPermissions" / readonly→"default",
  prompt: "{Agent定義本文（frontmatter除く）}\n\n## タスク\n{task}\n\n## 前ステップ結果\n{prev_result}"
)
```

逐次ステップでは isolation 不使用（前ステップの変更参照が必要なため）。

**parallel:**

単一メッセージで複数Agent並列起動。edit mode のサブステップには `isolation: "worktree"` を自動付与。集約は `aggregate.priority` の先頭にマッチした結果を採用:

```yaml
aggregate:
  priority: [spec_issue, any_fail, all_pass]
```

- `spec_issue`: いずれかの出力が spec_issue
- `any_fail`: いずれかが fail
- `all_pass`: 全員 pass

`aggregate` 未定義時のデフォルト priority: `[spec_issue, any_fail, all_pass]`。

worktree に変更が残る場合は親へマージ/チェリーピック統合。変更なしは自動クリーンアップ。

**provider: codex:**

Bash toolで `codex` コマンド実行。未インストール時は error（rules.on:error に従う）。

**ask_user: true:**

needs_input 時に AskUserQuestion で質問、回答を追記して再実行。

### 4. 結果解析

`GROOVE_RESULT: {値}` を検索。見つからない場合:

- edit → `done`
- readonly → `pass`
- agent エラー/timeout → `error`

### 5. 完了

- COMPLETE → 実行履歴表示。`--auto` なら `/git-push --pr` 実行 → PushNotification
- ABORT → 失敗理由表示 → PushNotification

## 参考

- スキーマ仕様・フィールド定義: `~/.groove/schema.md`
- 利用可能ワークフロー一覧: `~/.groove/README.md`（または `/groove list`）
