---
allowed-tools: Bash, Read, Grep, Glob, Skill, mcp__serena__*
description: GitLab MR / GitHub PR のURLを貼るだけでレビュー実行
---

# /mr-review - MR/PR URLレビュー

MR/PRのURLを貼るだけで差分を取得してレビュー。GitLab(glab)/GitHub(gh)を自動判定。

## フロー

1. **URL解析とプラットフォーム判定**
   ```bash
   # GitLab MR
   # https://gitlab.example.com/group/project/-/merge_requests/123
   glab mr diff 123

   # GitHub PR
   # https://github.com/owner/repo/pull/123
   gh pr diff 123
   ```

2. **差分取得**
   - MR/PR番号を抽出
   - `glab mr view`/`gh pr view` で概要取得
   - `glab mr diff`/`gh pr diff` で差分取得

3. **comprehensive-reviewスキルでレビュー実行**
   ```
   Skill("comprehensive-review")
   ```
   5観点で統合レビュー（設計・品質・可読性・セキュリティ・ドキュメント）

4. **結果表示**
   - Critical/Warning を一覧表示
   - 修正提案を含む

## 使い方

```bash
# GitLab MR URL
/mr-review https://gitlab.example.com/group/project/-/merge_requests/123

# GitHub PR URL
/mr-review https://github.com/owner/repo/pull/456

# 番号のみ（現在リポジトリのMR/PR）
/mr-review 123
```

## オプション

| 引数 | 説明 | 例 |
|------|------|-----|
| `<url>` | MR/PR URL | `/mr-review https://...` |
| `<number>` | MR/PR番号（現在リポジトリ） | `/mr-review 123` |
| `--focus=<観点>` | レビュー観点を絞る | `/mr-review 123 --focus=security` |

## 注意

- `glab auth login` / `gh auth login` が事前に必要
- 大きなMR（100ファイル超）はファイル単位で分割レビュー

ARGUMENTS: $ARGUMENTS
