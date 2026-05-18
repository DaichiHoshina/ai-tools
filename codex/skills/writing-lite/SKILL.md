---
name: writing-lite
description: Use when writing, rewriting, reviewing, or polishing human-facing text such as PR descriptions, issue comments, Slack messages, Notion notes, DesignDocs, PRDs, ADRs, commit messages, or Japanese reviewer-facing prose. This is a thin Codex bridge to Claude Code writing guidelines.
---

# Writing Lite

Use this skill when the task is primarily about words that another person will read.

This skill intentionally stays small. It keeps `~/.codex/skills` Codex-native while reusing the Claude Code writing guidelines exposed through `~/.codex/guidelines/writing`.

## Load Order

1. Read `~/.codex/guidelines/writing/README.md` to choose the right writing guide.
2. Read `~/.codex/guidelines/writing/PRINCIPLES.md` for the shared baseline.
3. Read only the target-specific file when needed:
   - commit message: `commit-message.md`
   - PR description or review response: `pr-description.md`
   - issue, PR comment, Slack, or Notion comment: `external-post.md`
   - DesignDoc, PRD, ADR, RCA, or long Notion page: `long-form-doc.md`
   - DesignDoc review workflow: `design-doc-protocol.md`
   - document placement or strategy: `strategy.md`

## Operating Rules

- Start from the reader, desired decision, concrete evidence, and reason.
- Prefer short Japanese unless the user asks otherwise.
- Put the conclusion first.
- Replace abstract claims with numbers, examples, file paths, or observed facts.
- Add a reason after evaluative words such as "重要", "推奨", "必須", "改善", and "最適".
- Keep links and references sparse. Include only links that change the reader's next action.
- Do not add AI-generated footers, process narration, or decorative wording.

## Output Check

Before finalizing, check:

- The first sentence tells the reader what to decide or do.
- Each paragraph has one role: conclusion, reason, evidence, caveat, or next action.
- Repeated facts are merged.
- The tone matches the destination: chat can be brief; documents should be complete sentences.
- The answer does not invent tickets, TODOs, or history that the user did not ask for.
