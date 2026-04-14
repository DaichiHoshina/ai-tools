---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Skill, AskUserQuestion, mcp__serena__*, mcp__context7__*
description: レビュー→修正→プッシュを1コマンドで実行。/review + /dev 全修正 + /git-push --pr の統合。
---

## /review-fix-push - レビュー・修正・プッシュ一括実行

Boris流の日常ワークフロー。レビューで見つけた問題を修正し、ブランチにpush→PR作成まで一気に実行。

## フロー

### Step 1: レビュー

```
Skill("comprehensive-review")
```

7観点の統合レビューを実行。結果をCritical/Warning別に分類。レビュー完了後、difitでブラウザに差分+コメント表示（`--no-difit`で抑制）。

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
/git-push --pr
```

修正をコミットしてブランチにpush、PR作成。

## オプション

| 引数 | 説明 | 例 |
|------|------|-----|
| (なし) | 全工程を実行 | `/review-fix-push` |
| `--critical-only` | Criticalのみ修正 | `/review-fix-push --critical-only` |
| `--dry-run` | レビューのみ（修正・pushしない） | `/review-fix-push --dry-run` |
| `--no-difit` | difit起動を抑制 | `/review-fix-push --no-difit` |
| `--from-pr <N>` | PR関連セッションを復元してレビュー | `/review-fix-push --from-pr 123` |

`--from-pr`指定時はStep 0として`claude --from-pr <N>`相当のコンテキスト復元を行い、そのPRの差分に対してレビューを実行する。

## 注意

- 修正前にレビュー結果をユーザーに表示し確認を得る
- force pushは禁止
- 修正後にlint/type checkを自動実行

ARGUMENTS: $ARGUMENTS
