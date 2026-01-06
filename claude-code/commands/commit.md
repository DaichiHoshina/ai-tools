---
allowed-tools: Bash, Read, Grep, Glob, mcp__serena__find_symbol, mcp__serena__get_symbols_overview, mcp__serena__search_for_pattern, mcp__serena__read_memory
description: Git コミットヘルパー - 差分を分析して適切なコミットメッセージを提案
---

## /commit - Git コミットヘルパー

## フロー

1. **状態確認** - `git status`, `git diff --cached` or `git diff`, `git log -5 --oneline`
2. **変更分析** - Serena MCP でシンボルレベルの変更を確認
3. **メッセージ生成** - Conventional Commits 形式
4. **ユーザー確認**（必須）
5. **コミット実行**

## Commit Types

| Type | 説明 |
|------|------|
| feat | 新機能 |
| fix | バグ修正 |
| docs | ドキュメント |
| refactor | リファクタリング |
| test | テスト |
| chore | ビルド・ツール |

## フォーマット

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

## Scope

機能名/コンポーネント名/サービス名（例: auth, user, api, button）

## 注意

- 1コミット = 1つの論理的な変更
- 大きな変更は複数コミットに分割
- **必ずユーザー承認後にコミット**
