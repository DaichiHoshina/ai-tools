---
allowed-tools: Read, Glob, Grep, Bash, mcp__serena__*, mcp__claude_ai_Notion__*
description: Knowledge archival — code analysis → create/update Notion pages
argument-hint: "[topic]"
---

## /docs - Knowledge archival

Archive completed work knowledge in Notion. Project-agnostic.

> **Responsibility split**: Design-phase Design Doc → `/design-doc` (md, team-shared). Post-completion knowledge → `/docs` (Notion). ADR / architecture-decision design-phase docs also use `/design-doc`.
>
> Full flow: `references/design-phase-flow.md`

**Must-read before Notion post (全 type 共通)**: `guidelines/common/notion-writing.md` (core: structure / headings / tone / notation) / `guidelines/writing/long-form-doc.md` (tone + interactive dict) / `guidelines/common/notion-design.md` (patterns).

**追加 Must-read (DB 操作を伴う投稿のみ)**: `guidelines/common/notion-database.md` (DB / templates) / `guidelines/common/notion-operations.md` (AI use / permissions / integration)。DB 操作を伴わない freeform / recipe / changelog 投稿では skip する。

## Document types & linked resources

| Type | Keywords | Guideline/skill |
|------|----------|-----------------|
| Incident | incident, outage | Skill(`incident-response`), Skill(`root-cause`) |
| Recipe | recipe, pattern, tips | `guidelines/writing/strategy.md` (❌/✅ format required) |
| Runbook | runbook, procedure | `guidelines/common/development-process.md` |
| Changelog | changelog, changes | auto-extract from git log/diff |
| Freeform | (other) | follow user instructions |

> Design decisions (ADR) & architecture design: create md w/ `/design-doc`, then use this command to intake to Notion on completion.

## Flow

### Step 1: Identify target

- Arg present → analyze that topic
- No arg → present recent changes from `git log --oneline -10` + `git diff --stat`, user selects
- `--from <md-path>` → input existing md (`/design-doc` output etc.) to Notion

### Step 2: Load guidelines

Load type-matched coordinating guidelines/skills.

- **Incident**: Follow incident-response skill format (classify→impact→cause→prevent-recurrence)
- **Recipe**: **Must use** ❌/✅ format from strategy.md. Code examples ≤5 lines, tables preferred

### Step 3: Analyze code

`git log` / `git diff` for changes, `Grep` / `Read` for related code. Extract 5 axes: **What** (diff summary) / **Why** (commit msg, PR desc) / **How** (main logic) / **Impact** (dependents, usage) / **Caveat** (notes, constraints).

### Step 4: Search Notion

`notion-search` 既存関連 page を検索する。見つかれば update / new を確認し、無ければ新規作成する。

### Step 4.8: writing check (pre-Notion post, required)

writing check: `references/writing-check-protocol.md` 参照 (対象: Notion doc md draft)。Post-edit cost が高いので `notion-create-pages` 発火前に必ず走らせる。

### Step 5: Create/update Notion page

Post w/ `notion-create-pages` or `notion-update-page`.

Type-specific templates:

**Incident**:
```
## Summary: 1-line summary
## Timeline: occur→detect→respond→recover
## Root cause: 5 Whys analysis
## Impact scope: user/system impact
## Prevent recurrence: specific actions
```

**Recipe**:
```
## Pattern name
| ❌ avoid | ✅ use | reason |
|----------|---------|------|
| bad example | good example | 1 line |
**Why**: background (1 line)
```

**Common footer** (all types):
```
## References
- Repository: {repo}
- Commit: {hash}
- PR: {url} (if any)
- Created: {date}
```

### Step 5.5: Interactive rewrite (required)

Detail / dict / template: `guidelines/writing/long-form-doc.md`。Pre-load `~/ai-tools/memory/user_vocabulary.md` (既知語 skip、projects/memory への Write は hook block 対象のため `~/ai-tools/memory/` 固定)。3 layer (Intent / Understanding / Expression) を順次実行、合計 ≤9 item。Layer 2 の user 応答 text は AI 換言せず draft にそのまま織込み、`user_vocabulary.md` へ追記する。

### Step 6: Output URL

created/updated Notion page URL を表示する。

## Options

| Option | Description |
|-----------|------|
| `--update <url>` | Update existing Notion page (URL) |
| `--from <md-path>` | Input local md (`/design-doc` output etc.) to Notion |
| `--dry` | Preview only, no Notion post |

## Quality guards

**Secret-free** (API keys / passwords / real URL → placeholder、`guidelines/writing/strategy.md` security 節) / **Code examples** ≤5 行 (strategy.md) / **Pre-post confirm** (preview を user に出して承認を取る) / **Mermaid** は Notion code block (mermaid 指定)。

ARGUMENTS: $ARGUMENTS
