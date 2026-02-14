---
allowed-tools: Bash
description: Git push ヘルパー - 「pushして」「main push」「push」を統一する簡易コマンド
---

# /push - Git Push ヘルパー

Boris流の簡易pushコマンド。「pushして」「main push」等の表記揺れを解消。

## フロー

1. **状態確認**
   ```bash
   git status --short
   git branch --show-current
   git rev-parse --abbrev-ref @{u} 2>/dev/null || echo "no-upstream"
   git log @{u}..HEAD --oneline 2>/dev/null || echo "no-upstream"
   ```

2. **未コミット変更の検出**
   - 変更あり → 「未コミットの変更があります。先にコミットしますか？」と確認
   - コミット提案 → Conventional Commits形式でメッセージ生成 → コミット実行
   - 変更なし → push へ進む

3. **push実行**
   - upstream あり → `git push`
   - upstream なし → `git push -u origin <current-branch>`

4. **結果表示**
   - push成功 → ブランチ名とコミット範囲を表示
   - push失敗 → エラー原因と対処法を表示

## オプション

| 引数 | 説明 | 例 |
|------|------|-----|
| (なし) | 現在ブランチをpush | `/push` |
| `main` | mainブランチに切替後push | `/push main` |
| `--force` | force push（確認必須） | `/push --force` |

## 注意

- mainブランチへのforce pushは**絶対禁止**（警告して拒否）
- リモートより遅れている場合はpull提案
- 未コミット変更がある場合は自動でコミット提案

## エラーハンドリング

| エラー | 対処 |
|--------|------|
| リモート未設定 | `git push -u origin <branch>` を自動実行 |
| reject（競合） | `git pull --rebase` を提案 |
| 認証エラー | SSH鍵/トークン確認を提案 |
| pushするものなし | 「Already up to date」と表示して終了 |

ARGUMENTS: $ARGUMENTS
