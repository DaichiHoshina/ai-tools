---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Task, Skill, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*
model: sonnet
description: 完全自律ワークフロー - /flow --auto のショートカット。質問なし・承認スキップ・自動push。
---

## /flow-auto - 完全自律モード

タスクを受け取り、判断・実装・テスト・レビュー・pushまで全自動で実行する。

## 動作原則

| 項目 | 動作 |
|------|------|
| ユーザーへの質問 | しない。推奨パターンを自動採用 |
| PO Agent | スキップ |
| 設計判断 | シンプルな方を自動採用 |
| Agent起動 | `mode: "bypassPermissions"` |
| push先 | タスクタイプで自動判定 |

## 実行フロー

```text
1. タスク受領・タスクタイプ自動判定（/flow の判定表を使用）
2. git status確認（変更あり → /dev から開始）
3. ワークフロー自動実行（/flow の判定表に従う）
4. review-fix ループ（Critical 0 + Warning 0 まで、最大3回）
5. 秘匿情報チェック
6. /git-push（緊急/ドキュメント → --main、それ以外 → --pr）
7. Serena memory保存（work-context-YYYYMMDD-{topic}）
8. 完了報告
```

## タスクタイプ判定

→ `/flow` コマンドの判定表を参照。同一ロジックを使用。

## review-fixループ

実装完了後:
1. `/review` 実行
2. Critical/Warningがあれば自動修正
3. 再度 `/review`
4. 最大3回。3回後も残件あり → 残件報告して続行

## lint-test失敗時

- 自動修正を1回試行
- 2回失敗 → 停止してユーザーに報告

## 完了報告フォーマット

```text
## 完了

- タスクタイプ: {type}
- 実行ステップ: {steps}
- push先: {branch/PR URL}
- review結果: Critical {n} / Warning {n}
- 所要ステップ数: {n}
```

ARGUMENTS: $ARGUMENTS
