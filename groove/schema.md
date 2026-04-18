# groove Workflow Schema

ワークフローYAMLの仕様（version 1）。

## トップレベル

| フィールド | 型 | 必須 | 説明 |
|-----------|-----|-----|------|
| `version` | int | ○ | スキーマバージョン（現在: `1`） |
| `name` | string | ○ | ワークフロー識別子 |
| `description` | string | ○ | 概要説明 |
| `max_steps` | int | ○ | 総ステップ実行数の上限（超過で ABORT） |
| `loop_limit` | int | ○ | 同一ステップの再訪問上限（超過で ABORT） |
| `defaults` | object | - | 各ステップへ適用する既定値（ステップ側で上書き可） |
| `steps` | array | ○ | ステップ定義リスト |

## defaults

全ステップへ適用する既定値。ステップ側のフィールドが優先。

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `retry` | int | リトライ回数（既定 `0`） |
| `timeout` | int | タイムアウト秒（既定なし） |
| `mode` | `readonly` \| `edit` | デフォルト実行モード |

## steps[]

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `name` | string | ステップ識別子（`rules.next` で参照） |
| `agent` | string | `agents/{name}.md` を読み込む |
| `mode` | `readonly` \| `edit` | 実行モード |
| `retry` | int | 失敗時再試行回数 |
| `timeout` | int | タイムアウト秒 |
| `provider` | string | `codex` 等の外部プロバイダー指定 |
| `parallel` | array | 並列ステップ定義（下記） |
| `aggregate` | object | parallel 結果集約ルール |
| `rules` | array | 遷移ルール |

### parallel

```yaml
parallel:
  - agent: acceptor
    mode: readonly
  - agent: ai-reviewer
    mode: readonly
aggregate:
  priority: [spec_issue, any_fail, all_pass]
```

- `priority`: 集約時に採用する結果の優先順位（先頭ほど優先）
- edit モードのサブステップには自動で `isolation: "worktree"` を付与

### rules[]

| `on` 値 | 意味 |
|--------|------|
| `pass` | readonly agent 成功 |
| `fail` | readonly agent 失敗 |
| `done` | edit agent 成功 |
| `blocked` | edit agent 実行不能 |
| `needs_input` | ユーザー回答必要（`ask_user: true` 併用） |
| `error` | agent エラー / timeout / 全リトライ失敗 |
| `all_pass` / `any_fail` / `spec_issue` | parallel 集約結果 |

`next` の特殊値:

- `COMPLETE` - 成功終了
- `ABORT` - 失敗終了

`ask_user: true` 指定時、needs_input で AskUserQuestion を呼び回答を追記して再実行。

## 解決順序

1. ステップのフィールド値
2. `defaults` の値
3. ビルトイン既定値（retry=0 等）

## error 遷移の設計指針

- `simplify.on:error` → `fix`: 整形中の破壊可能性に備えフォールバック
- `fix.on:error` → `implement`: 修正アプローチを白紙に戻す。worktree 使用時は親ブランチとの統合で未コミット変更が衝突し得るため、3回目以降は `ABORT` 推奨
- `implement.on:error` → `ABORT`: 実装起点の失敗は人の介入を要求

## 移行ルール（v0 → v1）

- `fallback.next` は廃止 → `rules` に `on: error` を追加
- parallel の集約優先順位は `aggregate.priority` で宣言（旧: コマンド側ハードコード）
- `version` 未指定は v0 として読み、警告表示

## 例

```yaml
version: 1
name: sample
description: 最小例
max_steps: 10
loop_limit: 2

defaults:
  retry: 1
  timeout: 180

steps:
  - name: implement
    agent: developer
    mode: edit
    timeout: 300
    rules:
      - on: done
        next: verify
      - on: error
        next: ABORT

  - name: verify
    agent: verifier
    rules:
      - on: pass
        next: COMPLETE
      - on: fail
        next: implement
```
