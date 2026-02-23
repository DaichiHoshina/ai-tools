---
allowed-tools: Bash, Read, Grep, Glob, mcp__serena__*
description: Git統合コマンド - commit → push → PR/MR作成を1コマンドで。モード自動判定。
---

# /git-push - Git統合コマンド

commit → push → PR/MR作成を1コマンドで実行。旧 `/commit-push-main`, `/commit-push-pr`, `/branch-push-mr` を統合。

## モード判定

| モード | 条件 | 動作 |
|--------|------|------|
| **main** | mainブランチ or `--main` 指定 | commit → main push |
| **pr** | featureブランチ or `--pr` 指定 | commit → push → PR作成 |
| **branch** | `--branch <name>` 指定 | main最新化 → ブランチ作成 → commit → push → MR/PR作成 |

**自動判定**: 引数なしの場合、現在のブランチで判定。mainなら`main`モード、それ以外なら`pr`モード。

## オプション

| オプション | 説明 | 例 |
|-----------|------|-----|
| `--main` | mainに直push | `/git-push --main` |
| `--pr` | PR作成 | `/git-push --pr` |
| `--branch <name>` | ブランチ作成→push→MR/PR | `/git-push --branch feat/auth` |
| `--draft` | ドラフトPR/MR | `/git-push --draft` |
| `-m "msg"` | コミットメッセージ指定 | `/git-push -m "fix: typo"` |

## フロー

### 共通ステップ（全モード）

1. **状態確認**
   ```bash
   git status --short
   git branch --show-current
   git diff --stat
   git log --oneline -5
   ```
2. **未コミット変更の処理**
   - 変更あり → 差分分析 → Conventional Commitsメッセージ生成 → ユーザー確認 → コミット
   - 変更なし → pushへ進む

### mainモード

3. `git push origin main`
4. **ai-toolsリポジトリの場合のみ**: `./claude-code/sync.sh to-local` を自動実行（`echo y |`で確認スキップ）
5. 結果表示

### prモード

3. `git push -u origin <branch>`
4. `gh pr create` / `glab mr create`（リモート自動判定）
5. PR/MR URL表示

### branchモード

3. main最新化 → ブランチ作成
   ```bash
   git stash          # 未コミット変更を退避（あれば）
   git checkout main && git pull origin main
   git checkout -b <branch-name>
   git stash pop      # 復元（あれば）
   ```
4. prモードのステップ3-5と同じ

## リモート判定

```bash
# GitLab → glab mr create
# GitHub → gh pr create
git remote get-url origin | grep -q "gitlab"
```

## コミットメッセージ

Conventional Commits形式で自動生成:
```
<type>(<scope>): <subject>
```

## 注意

- force pushは**絶対禁止**
- コミット前にユーザー確認必須
- リモートより遅れている場合はpull提案

## エラーハンドリング

| エラー | 対処 |
|--------|------|
| 変更なし & pushなし | 「Already up to date」で終了 |
| reject（競合） | `git pull --rebase` を提案 |
| 認証エラー | SSH鍵/トークン確認を提案 |
| PR/MR作成失敗 | push済みのブランチURLを表示 |

ARGUMENTS: $ARGUMENTS
