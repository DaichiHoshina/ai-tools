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
- **Reviewer assign**: `gh pr create` / `gh pr edit` で `--reviewer` flag を使わない。「reviewer assign しますか」「reviewer 提案」もこちらから持ち出さない (user が依頼した場合のみ対応)。auto-assign workflow (`.github/CODEOWNERS` 等) も勝手に編集しない。PR テンプレに reviewer 欄があれば空のまま push する

**Why (reviewer)**: チームのレビュー分担はメンバー稼働 / 専門領域 / 直近の担当者ローテーション等を user が把握しており、AI が勝手に決めると不適切なアサインが発生する。

Details: `guidelines/writing/commit-message.md` / `pr-description.md`

## Short Posts (issue/ticket/comments)

PREP 3-point structure (conclusion / reason / next action), ~400 characters / title ~80 characters.

Details: `guidelines/writing/external-post.md` / common principles: `guidelines/writing/PRINCIPLES.md`

Long-form (Notion / Design Doc / PRD / RCA) → `guidelines/writing/long-form-doc.md`

## URL / Issue・PR 番号検証

外向き text (PR body / commit / Issue / comment / Slack / Notion) に issue/PR/discussion の URL を貼る前に、`gh issue view <N>` または `gh pr view <N>` (または `gh api`) で番号の実在と title の一致を検証する。

- 番号を推測や記憶から組み立てない。直前の会話で確定した URL のみ literal で再利用し、新規番号を出力する場合は必ず gh で確認する。
- repo 跨ぎ (work-repo / docs 等) では URL の repo 部分も取り違えやすいため、`owner/repo#N` の repo 名も検証対象に含める。
- 検証できない環境 (gh 不在 / 権限なし) では URL を断定せず、user に番号確認を促す。

**Why**: 番号取り違えは diff に出ず review でも見逃され、user が毎回手で訂正する churn 源 (retrospective 2026-05-31 検出)。

## Code Comments

Prohibit AI-generation markers (`// AI-generated`, `// TODO: AI suggested` etc).

詳細: `guidelines/writing/code-comment.md` (WHY / 重要 memo / 削除 7 カテゴリ / fail-safe テンプレ)

## Reference: Pre-post Self-check

Former "self-check 4 questions" merged into `guidelines/writing/PRINCIPLES.md` **"4 questions before writing"** (who reads / what decides / data source / why) + **"6-item pre-output checklist"**. Verify both before posting.
