---
allowed-tools: Bash
name: context7
description: Fetch latest docs via Context7 API. Required before library API writes, new library adoption, or 6+ month old specs.
---

# context7 - Library Documentation Search

## Overview

This skill enables retrieval of current documentation for software libraries and components by querying the Context7 API via curl. Use it instead of relying on potentially outdated training data.

Hook 連携: `hooks/lib/write-checkers.sh` の `_LIVE_DOC_KEYWORDS` (25 keyword: `useState` / `axios.create` / `FastAPI(` / `prisma.*.findMany` / `createClient(` / `OpenAI(` 等) が write-type tool 前に warn-only で検出する。warn が出たら本 skill を起動して最新 docs を取得してから書く。

## Workflow

### Step 1: Search for the Library

To find the Context7 library ID, query the search endpoint:

```bash
curl -s "https://context7.com/api/v2/libs/search?libraryName=LIBRARY_NAME&query=TOPIC" | jq '.results[0]'
```

**Parameters:**
- `libraryName` (required): The library name to search for (e.g., "react", "nextjs", "fastapi", "axios")
- `query` (required): A description of the topic for relevance ranking

**Response fields:**
- `id`: Library identifier for the context endpoint (e.g., `/websites/react_dev_reference`)
- `title`: Human-readable library name
- `description`: Brief description of the library
- `totalSnippets`: Number of documentation snippets available

### Step 2: Fetch Documentation

To retrieve documentation, use the library ID from step 1:

```bash
curl -s "https://context7.com/api/v2/context?libraryId=LIBRARY_ID&query=TOPIC&type=txt"
```

**Parameters:**
- `libraryId` (required): The library ID from search results
- `query` (required): The specific topic to retrieve documentation for
- `type` (optional): Response format - `json` (default) or `txt` (plain text, more readable)

## Example

### React hooks documentation

```bash
# Find React library ID
curl -s "https://context7.com/api/v2/libs/search?libraryName=react&query=hooks" | jq '.results[0].id'
# Returns: "/websites/react_dev_reference"

# Fetch useState documentation
curl -s "https://context7.com/api/v2/context?libraryId=/websites/react_dev_reference&query=useState&type=txt"
```

## Tips

- Use `type=txt` for more readable output
- Use `jq` to filter and format JSON responses
- Be specific with the `query` parameter to improve relevance ranking
- If the first search result is not correct, check additional results in the array
- URL-encode query parameters containing spaces (use `+` or `%20`)
- No API key is required for basic usage (rate-limited)

## Failure Behavior

| Situation | Action |
|------|------|
| API connect fail (timeout / DNS) | Fallback to knowledge cutoff, warning log |
| 429 Rate Limit | Exponential backoff 1 try (1s → 4s), else fallback to knowledge |
| Zero search results | Suggest alternative keywords (e.g. `react-hooks` → `react hooks`), if still zero show not found |
| Context fetch fail post-libraryId | Retry with alternate libraryId (results[1], results[2]), max 3 candidates |
