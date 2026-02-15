---
allowed-tools: Read, Glob, Grep, Edit, MultiEdit, Write, Bash, Task, Skill, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*, mcp__context7__*
description: レビュー→修正→プッシュを1コマンドで実行。/review + /dev 全修正 + /commit-push-main の統合。
---

## /review-fix-push - レビュー・修正・プッシュ一括実行

Boris流の日常ワークフロー。レビューで見つけた問題を修正し、mainにpushするまでを一気に実行。

## フロー

### Step 1: レビュー

```
Skill("comprehensive-review")
```

5観点の統合レビューを実行。結果をCritical/Warning別に分類。

### Step 2: 判断

- Critical 0件 & Warning 0件 → "問題なし"で終了（pushのみ実行）
- 指摘あり → Step 3へ

### Step 3: 修正

指摘事項を自動修正:
- Critical → 全件修正（必須）
- Warning → 全件修正（デフォルト）

修正は `/dev` と同等のフローで実行（ガイドライン読込、静的解析確認含む）。

### Step 4: プッシュ

```
/commit-push-main
```

修正をコミットしてmainにpush。

## オプション

| 引数 | 説明 | 例 |
|------|------|-----|
| (なし) | 全工程を実行 | `/review-fix-push` |
| `--critical-only` | Criticalのみ修正 | `/review-fix-push --critical-only` |
| `--dry-run` | レビューのみ（修正・pushしない） | `/review-fix-push --dry-run` |

## 注意

- 修正前にレビュー結果をユーザーに表示し確認を得る
- force pushは禁止
- 修正後にlint/type checkを自動実行

ARGUMENTS: $ARGUMENTS
