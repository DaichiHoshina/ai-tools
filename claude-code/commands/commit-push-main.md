---
allowed-tools: Bash, Read, Grep, Glob
description: commit → main push を1コマンドで実行。「pushして」「main push」等の表記揺れを統一。
---

# /commit-push-main - Commit & Push to Main

Boris流の日常コマンド。変更をコミットしてmainにpushするまでを一気に実行。
`/commit-push-pr`からPR作成を省いた簡易版。

## フロー

1. **状態確認**
   ```bash
   git status --short
   git branch --show-current
   git diff --stat
   git log --oneline -5
   ```

2. **未コミット変更の処理**
   - 変更あり → 差分を分析してConventional Commitsメッセージを生成 → ユーザー確認 → コミット
   - 変更なし → pushへ進む

3. **push実行**
   - 現在ブランチがmain → `git push`
   - 現在ブランチがmain以外 → mainにチェックアウト後push、またはそのままpush

4. **結果表示**
   - push成功 → コミットハッシュとブランチ名を表示

## コミットメッセージ

Conventional Commits形式で自動生成:
```
<type>(<scope>): <subject>
```

## オプション

| 引数 | 説明 | 例 |
|------|------|-----|
| (なし) | 変更をコミットしてpush | `/commit-push-main` |
| `-m "msg"` | メッセージ指定 | `/commit-push-main -m "fix: typo"` |

## 注意

- force pushは**絶対禁止**
- リモートより遅れている場合はpull提案
- コミット前に必ずユーザー確認

## エラーハンドリング

| エラー | 対処 |
|--------|------|
| 変更なし & pushなし | 「Already up to date」で終了 |
| reject（競合） | `git pull --rebase` を提案 |
| 認証エラー | SSH鍵/トークン確認を提案 |

ARGUMENTS: $ARGUMENTS
