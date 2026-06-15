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
- **Body = Why only**: commit WHAT → subject line only. Body (if written): Why (motivation / constraint / problem) in 1-3 lines. No WHAT supplement bullets / file lists / function enumerations. Details: `guidelines/writing/commit-message.md` **"原則"** + **"Why を本文 1 行目に書く"** section (canonical source)
- **Reviewer assign**: do not use `--reviewer` flag in `gh pr create` / `gh pr edit`. Do not proactively suggest "assign reviewer". Do not edit auto-assign workflows (`.github/CODEOWNERS` etc). Leave reviewer field empty when PR template includes one (team allocation depends on availability / domain / rotation — AI assignment misfires).

Details: `guidelines/writing/commit-message.md` / `pr-description.md`

## Short Posts (issue/ticket/comments)

PREP 3-point structure (conclusion / reason / next action), ~400 characters / title ~80 characters.

Details: `guidelines/writing/external-post.md` / common principles: `guidelines/writing/PRINCIPLES.md`

Long-form (Notion / Design Doc / PRD / RCA) → `guidelines/writing/long-form-doc.md`

## URL / Issue & PR Number Validation

Before embedding issue/PR/discussion URLs in outward text (PR body / commit / Issue / comment / Slack / Notion), verify number existence and title match via `gh issue view <N>` or `gh pr view <N>` (or `gh api`).

- Never construct numbers from guesses or memory. Reuse only URLs confirmed in current conversation; always verify new numbers via gh.
- Cross-repo references (work-repo / docs etc.) risk repo-part mix-ups — include `owner/repo` in validation scope.
- When gh is unavailable (not installed / no permission), do not assert URLs; prompt user to confirm.

**Why**: Number mix-ups are invisible in diff and missed in review, causing churn on every PR (detected retrospective 2026-05-31).

## Code Comments

Prohibit AI-generation markers (`// AI-generated`, `// TODO: AI suggested` etc).

Details: `guidelines/writing/code-comment.md` (WHY / important memo / 7 deletion categories / fail-safe template)

## Reference: Pre-post Self-check

Verify `guidelines/writing/PRINCIPLES.md` **"4 questions before writing"** (who reads / what decides / data source / why) + **"6-item pre-output checklist"** before posting.
