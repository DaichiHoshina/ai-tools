---
keep: on-demand
allowed-tools: mcp__context7__resolve-library-id, mcp__context7__query-docs
name: context7
description: Fetch latest docs via Context7 MCP. Required before library API writes.
---

# context7 - Library Documentation Search

## Overview

Context7 MCP server 経由で library の最新 docs を取得する skill。training cutoff より新しい API 変更に追従するため、library method 直書き前に発火する。

MCP server は user scope に登録済み。登録 command: `claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp` (server 実体は `@upstash/context7-mcp`, stdio)。

Hook 連携: `hooks/lib/write-checkers.sh` の `_LIVE_DOC_KEYWORDS` (25 keyword: `useState` / `axios.create` / `FastAPI(` / `prisma.*.findMany` / `createClient(` / `OpenAI(` 等) が write-type tool 前に warn-only で検出する。warn が出たら本 skill を起動して最新 docs を取得してから書く。

## Workflow

### Step 1: Resolve the library ID

MCP tool `mcp__context7__resolve-library-id` を呼ぶ。

**Parameters:**
- `libraryName` (required): 検索対象 library 名 (例: `"react"`, `"nextjs"`, `"fastapi"`, `"axios"`)
- `query` (required): user の質問 / topic (relevance ranking に使う)

**返却**: library 候補 list。各候補に `id` (例: `/websites/react_dev_reference`, `/mongodb/docs`, `/vercel/next.js`) と `title` / `description` / `totalSnippets` を含む。先頭が最も relevance が高い。

### Step 2: Fetch documentation

MCP tool `mcp__context7__query-docs` を呼ぶ。

**Parameters:**
- `libraryId` (required): Step 1 で得た exact library ID (例: `/websites/react_dev_reference`)
- `query` (required): 具体的な topic (例: `"useState"`, `"middleware"`)

**返却**: library docs snippet。読み込んで API method の実 signature を確認してから write に進む。

## Example

### React hooks documentation

1. `mcp__context7__resolve-library-id` を `libraryName="react"`, `query="hooks"` で呼ぶ。先頭候補 `id: /websites/react_dev_reference` を得る
2. `mcp__context7__query-docs` を `libraryId="/websites/react_dev_reference"`, `query="useState"` で呼ぶ。useState の最新 signature と使用例が返る
3. 返却内容を読んで実装に使う

## Tips

- Step 1 の先頭候補が正しくないと感じたら 2 番目 / 3 番目の候補も検討する (Failure Behavior 参照)
- `query` は具体的に書くほど relevance が上がる (「hooks」より「useState」の方が有効)
- 特定 version の spec が要るなら `libraryName` にそれを含める (例: `"next.js 15"`)
- API key は不要 (rate-limited、後述の Failure Behavior 参照)

## Failure Behavior

MCP tool が失敗 or 期待外れの返却をした場合、skill 使用者が下記の手順で対処する。MCP 側で自動処理される保証はないため skill 使用者が判定する。

| Situation | Action |
|------|------|
| MCP connect fail (`Not connected` / timeout) | `claude mcp list` で context7 が Connected か確認する。切れていたら `claude mcp restart context7` を試し、駄目なら `claude mcp remove context7` の後に `claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp` で入れ直す。復旧不能なら knowledge cutoff で書き、その旨を明示する |
| 429 Rate Limit エラー | 1 秒待って再試行する。それでも 429 が続くなら knowledge cutoff で書く |
| Zero search results | `libraryName` の綴りを変えて再試行する。例えば `react-hooks` を `react hooks` に、`nextjs` を `next.js` に変える。それでも空なら library 未対応と判断する |
| Context fetch fail post-libraryId | Step 1 の 2 番目 / 3 番目の候補 ID で再試行する。max 3 候補まで |
