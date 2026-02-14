---
allowed-tools: Bash, Read, Grep, Glob
description: mainからブランチ切り → commit → push → MR/PR作成を1コマンドで実行
---

# /branch-push-mr - ブランチ作成からMR/PR作成まで

「mainからブランチ切ってpushしてMR作成」を1コマンドで実行。
GitLab(glab)とGitHub(gh)を自動判定。

## フロー

1. **状態確認**
   ```bash
   git status --short
   git branch --show-current
   git remote get-url origin
   ```

2. **ブランチ作成**
   - 現在mainにいる場合 → `git checkout -b <branch-name>`
   - 既にfeature branchにいる場合 → そのまま使用
   - ブランチ名: 変更内容からConventional Branch名を自動生成
     - 例: `feat/add-auth`, `fix/login-error`, `refactor/cleanup-api`
   - 引数でブランチ名指定も可

3. **コミット**
   - 変更あり → 差分分析 → Conventional Commitsメッセージ生成 → ユーザー確認 → コミット
   - 変更なし（既にコミット済み） → pushへ進む

4. **push**
   ```bash
   git push -u origin <branch-name>
   ```

5. **MR/PR作成（リモート自動判定）**
   ```bash
   # GitLab判定
   if git remote get-url origin | grep -q "gitlab"; then
     glab mr create --fill --target-branch main
   # GitHub判定
   else
     gh pr create --fill --base main
   fi
   ```

6. **結果表示**
   - MR/PR URLを表示

## オプション

| 引数 | 説明 | 例 |
|------|------|-----|
| (なし) | ブランチ名を自動生成 | `/branch-push-mr` |
| `<branch>` | ブランチ名を指定 | `/branch-push-mr feat/auth` |
| `--draft` | ドラフトMR/PR | `/branch-push-mr --draft` |
| `-m "msg"` | コミットメッセージ指定 | `/branch-push-mr -m "feat: 認証追加"` |

## ブランチ命名規則

```
<type>/<short-description>

type: feat, fix, refactor, docs, test, chore
```

変更内容から自動推測。ユーザー確認後に作成。

## 注意

- mainブランチ上で直接コミットしない（必ずブランチを切る）
- 既にfeature branchにいる場合は新規ブランチ作成をスキップ
- force pushは禁止

## エラーハンドリング

| エラー | 対処 |
|--------|------|
| ブランチ名重複 | サフィックス追加（`-2`等） |
| push reject | `git pull --rebase origin main` を提案 |
| glab/gh未認証 | `glab auth login` / `gh auth login` を案内 |
| MR/PR作成失敗 | push済みのブランチURLを表示して手動作成を案内 |

ARGUMENTS: $ARGUMENTS
