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

**Must-read**: When posting to Notion, follow these guidelines:
- `guidelines/common/notion-writing.md` — structure, headings, tone, notation rules (core)
- `guidelines/writing/long-form-doc.md` — user tone guide + interactive check dict
- `guidelines/common/notion-design.md` — design patterns
- `guidelines/common/notion-database.md` — DB design, templates
- `guidelines/common/notion-operations.md` — AI use, permissions, external integration

## Document types & linked resources

| Type | Keywords | Guideline/skill |
|------|----------|-----------------|
| API spec | api, endpoint | Skill(`api-design`) |
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
- **API spec**: Follow api-design skill endpoint notation rules

### Step 3: Analyze code

```
git log / git diff → understand changes
Grep / Read → read related code
```

Extract:
- **What**: what changed (diff summary)
- **Why**: why changed (commit msg, PR desc)
- **How**: how implemented (main logic)
- **Impact**: impact scope (dependents, usage)
- **Caveat**: notes, known constraints

### Step 4: Search Notion

Search existing related pages w/ `notion-search`.

- Related page found → confirm update or new
- None → create new

### Step 4.8: writing check (pre-Notion post, required)

Before `notion-create-pages` runs, AI self-checks draft body text. Target is md-form draft, not yet sent to Notion.

Check items: writing axis NG table from `skills/comprehensive-review/SKILL.md` + NG dict from `guidelines/writing/long-form-doc.md`.

- Critical ≥1, or Warning ≥4 hits → rewrite draft → re-check (max 2 loops)
- After pass, proceed to Step 5

Post-edit cost high, so **always check pre-post**.

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

Detail, dict, template: see `guidelines/writing/long-form-doc.md`.

- Pre-load: `~/.claude/projects/{project}/memory/user_vocabulary.md` (skip known terms)
- Execute 3 layers (Intent / Understanding / Expression) sequentially, ≤9 items total
- Layer 2 user response text weave as-is into draft (no AI rephrasing)
- Append responses to `user_vocabulary.md`

### Step 6: Output URL

Display created/updated Notion page URL.

## Options

| Option | Description |
|-----------|------|
| `--parent <url>` | Notion parent page URL |
| `--update <url>` | Update existing Notion page (URL) |
| `--from <md-path>` | Input local md (`/design-doc` output etc.) to Notion |
| `--dry` | Preview only, no Notion post |

## Quality guards

- **Secret-free**: API keys, passwords, real URLs → placeholders (`guidelines/writing/strategy.md` security section)
- **Code examples**: ≤5 lines (strategy.md rule)
- **Pre-post confirm**: show user preview, get approval
- **Mermaid diagrams**: Notion code block (mermaid specified)

ARGUMENTS: $ARGUMENTS
