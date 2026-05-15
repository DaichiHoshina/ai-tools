---
allowed-tools: Bash, Read
description: Git pull --rebase の安全実行。未コミット変更を自動stash→pull→pop。
---

# /git-pull - 安全なpull

`git pull --rebase` 実行前に未コミット変更を自動stash、完了後に自動pop。stash時のコンフリクトはブロックして報告。

## 現在のGit状態

!`git status --short`
!`git branch --show-current`
!`git log --oneline -3`

## オプション

| オプション | 説明 |
|-----------|------|
| `--no-rebase` | merge方式でpull（デフォルトはrebase） |
| `--no-stash` | stashせず実行（変更ありなら通常のエラー） |

## フロー

1. **状態確認**: `git status --porcelain` で未コミット変更検知
2. **stash**: 変更あり → `git stash push -u -m "auto-stash before /git-pull $(date +%s)"`
3. **pull**: `git pull --rebase`（`--no-rebase` 時は `git pull`）
4. **pop**: stash した場合 → `git stash pop`
5. **コンフリクト処理**: pop失敗 → stashは残したまま、ユーザーに通知

## 失敗パターンと対処

| 失敗 | 対処 |
|------|------|
| `pull --rebase` 失敗 | stash残したままユーザー報告、`git rebase --abort` を提案 |
| `stash pop` でコンフリクト | stash残したまま（`git stash list` で確認可）、解消方法を提示 |
| 未tracked branch | `git branch --set-upstream-to` を提案 |

注: `--no-rebase` 時は `git pull --no-rebase --ff` を明示（git 2.27+ の `pull.rebase` 警告回避）。

## 関連コマンド

| コマンド | 関係 |
|---------|------|
| `/git-push` | pull後のpushに使用 |
