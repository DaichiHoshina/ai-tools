---
allowed-tools: Bash, Read, Grep, Glob, mcp__serena__*
description: Git統合ヘルパー - commit → push → PR作成を1コマンドで実行（Boris流）
---

## /commit-push-pr - Git統合ヘルパー

Boris が毎日何十回も使用する統合コマンド。変更をコミット・プッシュしてPR作成まで一気に実行。

## フロー

1. **状態確認** - インライン bash で事前計算
   ```bash
   git status --short
   git diff --stat
   git branch --show-current
   ```
2. **変更分析** - Serena MCP でシンボルレベルの変更を確認
3. **コミット**
   - メッセージ生成（Conventional Commits形式）
   - ユーザー確認（必須）
   - `git commit` 実行
4. **プッシュ**
   - リモートブランチ確認
   - `git push -u origin <branch>` 実行
5. **PR作成**
   - `gh pr create` でPR作成
   - タイトル・説明を自動生成

## オプション

| オプション | 説明 | 例 |
|-----------|------|-----|
| `-m "message"` | コミットメッセージ指定 | `/commit-push-pr -m "feat: 認証機能追加"` |
| `--draft` | ドラフトPR作成 | `/commit-push-pr --draft` |

## Commit Types

| Type | 説明 |
|------|------|
| feat | 新機能 |
| fix | バグ修正 |
| docs | ドキュメント |
| refactor | リファクタリング |
| test | テスト |
| chore | ビルド・ツール |

## コミットメッセージフォーマット

```
<type>(<scope>): <subject>

<body>

<footer>
```

**例:**
```
feat(auth): JWT認証機能を実装

- トークン生成・検証ロジック追加
- ミドルウェアで認証チェック実装

Closes #123
```

## PRタイトル・説明フォーマット

**タイトル:** コミットメッセージの subject

**説明:**
```markdown
## Summary
- [変更内容の箇条書き]

## Test plan
- [ ] ローカル動作確認
- [ ] lint/test 通過

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## インライン Bash 事前計算

```bash
# 変更ファイル一覧
git status --short

# 変更統計
git diff --stat

# 現在ブランチ
git branch --show-current

# リモート追跡状態
git rev-parse --abbrev-ref @{u} 2>/dev/null || echo "no-upstream"
```

## 実行例

### 基本使用
```bash
/commit-push-pr
# → 変更分析 → commit → push → PR作成
```

### メッセージ指定
```bash
/commit-push-pr -m "fix: ログイン画面のバリデーション修正"
# → 指定メッセージでコミット → push → PR作成
```

### ドラフトPR
```bash
/commit-push-pr --draft
# → commit → push → ドラフトPR作成
```

## 注意

- **必ずユーザー承認後にコミット・プッシュ**
- mainブランチへの直接pushは警告
- force pushは絶対禁止
- リモートより進んでいる場合は push 前に pull 提案
- PR作成失敗時はコミット・プッシュは保持される

## エラーハンドリング

| エラー | 対処 |
|--------|------|
| 変更なし | 「コミット対象がありません」と終了 |
| リモート未設定 | `git push -u origin <branch>` を提案 |
| PR作成失敗 | `gh auth status` 確認を提案 |
| コンフリクト | pull → 解決 → 再実行を提案 |

## Scope

機能名/コンポーネント名/サービス名（例: auth, user, api, button）

## 内部処理

1. `git status --short` で変更確認
2. staged がない場合は `git add -A` 提案
3. コミットメッセージ生成
4. ユーザー承認
5. `git commit -m "<message>"`
6. リモート追跡状態確認
7. `git push` または `git push -u origin <branch>`
8. PR作成:
   - `--draft` あり: `gh pr create --draft --title "<title>" --body "<body>"`
   - `--draft` なし: `gh pr create --title "<title>" --body "<body>"`
9. PR URL表示
