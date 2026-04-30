---
allowed-tools: Bash, Read, Grep, Glob, mcp__serena__*
description: Git統合コマンド - commit → push → PR/MR作成を1コマンドで。モード自動判定。
---

# /git-push - Git統合コマンド

commit → push → PR/MR作成を1コマンドで実行。

## 現在のGit状態

!`git status --short`
!`git branch --show-current`
!`git diff --stat`
!`git log --oneline -5`

## モード判定

| モード | 条件 | 動作 |
|--------|------|------|
| **main** | mainブランチ or `--main` | commit → main push |
| **pr** | featureブランチ or `--pr` | commit → push → PR作成 |
| **branch** | `--branch <name>` | main最新化 → ブランチ作成 → commit → push → MR/PR |

**自動判定**: 引数なしの場合、現在のブランチで判定。main→`main`、それ以外→`pr`。

## オプション

| オプション | 説明 |
|-----------|------|
| `--main` | mainに直push |
| `--pr` | PR作成 |
| `--branch <name>` | ブランチ作成→push→MR/PR |
| `--draft` | ドラフトPR/MR |
| `-m "msg"` | コミットメッセージ指定 |
| `--auto-review` | PR作成後に `/code-review:code-review` + `coderabbit:code-review` を並列自動起動（**opt-in、prモード時のみ**）。CodeRabbit は外部API呼び出し・課金影響あり |

## フロー

### 共通

1. 状態確認（`git status --short` / `branch --show-current` / `diff --stat` / `log --oneline -5`）
2. 未コミット変更あり → 差分分析 → Conventional Commits メッセージ生成 → ユーザー確認 → commit

### mainモード

3. `git push origin main`
4. **ai-toolsリポのみ**: `./claude-code/sync.sh to-local`（`echo y |` で確認スキップ）
5. 結果表示

### prモード

3. `git push -u origin <branch>`
4. `gh pr create` / `glab mr create`（リモート自動判定）
5. PR/MR URL表示
6. **自動レビュー**（`--auto-review` 指定時のみ。デフォルト OFF、PR成功時、`gh` 利用可、GitHub限定）:
   - `/code-review:code-review <PR番号>` を `Bash run_in_background:true` で起動 → bash_id_A 取得
   - `coderabbit:code-review` を `Bash run_in_background:true` で起動 → bash_id_B 取得
   - 完了監視: `BashOutput` で bash_id_A / bash_id_B を順次取得
   - 成功時: PR にコメント投稿された旨をユーザーに表示
   - 失敗時: ツール名・exit code・stderr 末尾10行 を表示（PR作成自体は成功扱い）
   - GitLab/`glab` 環境では `--auto-review` 指定があっても skip（plugin 未対応、warn 表示）

### branchモード

3. main最新化 → ブランチ作成（`git stash` → `checkout main && pull` → `checkout -b` → `stash pop`）
4. prモードの 3-5 と同じ

## リモート判定

```bash
git remote get-url origin | grep -q "gitlab"   # GitLab → glab、そうでなければ gh
```

**判定不能時** (`git remote get-url` 失敗 / origin 未設定): push 段階で停止し、「remote 未設定 — `git remote add origin <url>` を実行してください」と案内。PR/MR 作成スキップ。

## コミットメッセージ

Conventional Commits 形式: `<type>(<scope>): <subject>`

## PR description テンプレート

`guidelines/common/user-voice.md` の 4 問に対応した 4 セクション。

```markdown
## Why
<なぜ必要か。根拠となる数字・要件を1-2文で>

## What changed
<何を変えたか。具体名で>

## Testing
<実行した検証。未検証なら正直に明記>

## Review focus
<レビュワーに見てほしい箇所 or 意思決定を求める選択肢>
```

**短文 PR description（H3 3個未満 or 400字以下）の場合は `~/.claude/rules/ai-output.md` の PREP 3点ルール + self-check 4問を通過させる**。長文 PR description（Design Doc 級）は user-voice.md の 4問+5原則。判定基準は H3 数 / 文字数 / スクロール 1 画面に収まるか。

**Testing の書き方**:

検証済 → 実行コマンド・環境・結果を具体的に（例: `go test ./... pass、staging p99: 320ms`）。

未検証 → 捏造せず明記: `Not run — docs-only` / `Not run — WIP` / `Manual only — ...` / `N/A — build設定のみ`。

避ける: 「〜を実装しました」「改善しました」（数字なし）、未実行テストの虚偽記載。

## Jiraチケットリンク

push/MR 作成後、コミットメッセージやブランチ名に Jira チケット ID が含まれる場合、該当チケットに MR/PR URL を `mcp__jira__jira_post` で自動コメント追加。ID 未検出時は警告のみ表示し、push/MR 作成自体は成功扱い（Jira 連携は補助機能、本流を止めない）。

**自動コメント本文も `~/.claude/rules/ai-output.md` の PREP 3点 + self-check 4問通過必須**。デフォルト template 例: 「結論: PR 作成完了 → レビュー依頼 / 理由: <ブランチ名+変更概要> / 次アクション: <レビュワー指定 or 不明>」。

## 注意

- force push 禁止
- コミット前にユーザー確認必須
- リモートより遅れている → pull 提案

## エラー対処

| エラー | 対処 |
|--------|------|
| 変更なし | "Already up to date" で終了 |
| reject（競合） | `git pull --rebase` を提案 |
| stash pop 失敗 | コンフリクト表示、手動解消案内 |
| 認証エラー | SSH鍵/トークン確認案内 |
| PR/MR作成失敗 | push済みブランチURL表示 |
| 自動レビュー失敗 | PR作成は成功扱い。レビューエラーのみ警告表示（PR URL は出力済） |

ARGUMENTS: $ARGUMENTS
