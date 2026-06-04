---
description: Fetch unresolved PR review comments via gh GraphQL and summarize action items per file.
allowed-tools: Bash, Read
---

# /pr-comments - PR 未対応コメント取得

PR の未対応 review コメントを構造化取得して、file 単位でアクション要約を出力する。read-only。

## 引数

```
/pr-comments [PR URL | PR番号] [--all]
```

| 引数 | 説明 |
|------|------|
| PR URL | `https://github.com/{owner}/{repo}/pull/{n}` — owner/repo/番号を自動抽出 |
| PR 番号のみ | `gh repo view --json owner,name` で現在 repo を補完 |
| `--all` | resolved 含む全スレッドを取得 (default: unresolved のみ) |

## 取得ロジック

### unresolved inline コメント (GraphQL)

```bash
gh api graphql -f query='
query($owner:String!, $repo:String!, $pr:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$pr) {
      reviewThreads(first:100) {
        nodes {
          isResolved
          path
          line
          comments(first:10) {
            nodes {
              author { login }
              body
              createdAt
            }
          }
        }
      }
    }
  }
}' -f owner="$OWNER" -f repo="$REPO" -F pr="$PR_NUM" \
| jq '[.data.repository.pullRequest.reviewThreads.nodes[]
       | select(.isResolved == false)]'
```

`--all` 指定時は `select(.isResolved == false)` を除去する。

### issue-level コメント (REST)

```bash
gh api repos/"$OWNER"/"$REPO"/issues/"$PR_NUM"/comments \
  --jq '[.[] | {author: .user.login, body, created_at}]'
```

## 出力形式

```
## 未対応コメント: {owner}/{repo}#{n}

### {file path}:{line}
- **作者**: @{author}
- **コメント**: {body の冒頭 200 字}
- **対応アクション**: {何を直すべきか 1 行で要約}
- **返信**: {あり/なし}

---
### Issue-level コメント
- **作者**: @{author} — {body 冒頭 200 字} / **対応**: {1 行要約}
```

スレッド数 0 の場合は「未対応コメントなし」と出力して終了。

## 制約

- このコマンドはコメント取得・表示のみ (read-only)
- 返信投稿 → `/post-comment` / コミット・push → `/git-push --pr`
