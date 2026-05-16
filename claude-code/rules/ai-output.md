---
paths:
  - "**/*.md"
  - "**/*.go"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.py"
---
# AI Output Rules (Enforced)

Brief prohibition list only. Details: `guidelines/writing/`

## PR / Commit Prohibitions

- AI footers like "Generated with Claude Code"
- Variable/file name lists (readable in diff)
- Table-format file listings (duplicates diff)
- Boilerplate like "changes in this PR"

Details: `guidelines/writing/commit-message.md` / `pr-description.md`

## Short Posts (issue/ticket/comments)

PREP 3-point structure (conclusion / reason / next action), ~400 characters / title ~80 characters.

Details: `guidelines/writing/external-post.md` / common principles: `guidelines/writing/PRINCIPLES.md`

Long-form (Notion / Design Doc / PRD / RCA) → `guidelines/writing/long-form-doc.md`

## Code Comments

Prohibit AI-generation markers (`// AI-generated`, `// TODO: AI suggested` etc).

## Reference: Pre-post Self-check

Former "self-check 4 questions" merged into `guidelines/writing/PRINCIPLES.md` **"4 questions before writing"** (who reads / what decides / data source / why) + **"6-item pre-output checklist"**. Verify both before posting.
