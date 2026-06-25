---
allowed-tools: Bash, Read, Edit
name: local-docs
description: local-docs 配下に HTML doc を作成・更新する。「runbook」「RCA」「postmortem」「調査ログ」「監視結果」「インシデント記録」「session 跨ぎメモ」等の永続知識を local-docs に残す指示全般で起動する。Use when creating or updating HTML docs in the local-docs knowledge base.
---

# local-docs

Create or update docs in local-docs (AI-assisted local knowledge base).
**Template compliance is required.**
Read the local-docs `CLAUDE.md` and `STRUCTURE.md` as the primary source for canonical types,
aggregation mappings, and placement rules. Do not duplicate type lists in this skill (No Derived Literals).

## Activation criteria

Fire when creating new HTML under local-docs (`projects/` / `domain-specs/` / `tool-guides/` / `operations/`), regardless of whether invoked explicitly. Triggers:

- User utterance includes「local-docs」「ナレッジ」「runbook」「RCA」「postmortem」「spec」「調査ログ」「監視結果」「post-release」「dashboard 確認」「5xx 分析」「インシデント記録」「試験結果」「session 跨ぎ」「試行錯誤メモ」
- Output path is under `local-docs/` (`projects/` / `domain-specs/` / `tool-guides/` / `operations/`)
- Extension is `.html` under any of the above paths

Writing HTML from scratch with `Write` without invoking this skill is a **rule violation**.
Past incident: wrote `<style>` inline without reading `_templates/`, breaking shared CSS / decorate / `_index/` build.

## Invocation

```
/local-docs new {type} {topic}        # create new
/local-docs update {path}             # update existing
/local-docs update {path} --reformat  # reformat to template compliance
```

Omit subcommand → infer `new` / `update` from context.

## Prerequisites (read every time)

1. Identify local-docs repo root from `cd` target or argument path.
2. Read `CLAUDE.md` §Templates and `STRUCTURE.md` §html-format, §type-enum, §placement-flow.
3. Obtain canonical types and aggregation mappings from those files — do not use cached knowledge.

## `new {type} {topic}` — create

1. **Type**: determine from topic; normalize variants to canonical type via `CLAUDE.md` mapping.
2. **Placement**: follow `STRUCTURE.md` placement flow.
3. **Template copy (required)**: `cp _templates/{type}.html {dir}/{name}.html`. Never write HTML from scratch with `Write` — copy with `cp`, then fill via `Edit` only.
4. **Fill content (Edit only)**: keep skeleton h2, `<style id="local-docs-style">`, `<script id="local-docs-script">` intact. Replace `{...}` placeholders via `Edit`. Overwriting with `Write` destroys script/style.
5. **Metadata**: fix `<!-- type: ... -->` `<!-- status: ... -->` to canonical values. Do not write `last-updated` (deprecated).
6. **Title**: follow `STRUCTURE.md` Title Rules — short, no repeating parent context.

### Self-check (immediately after generation)
- First 2 lines: `<!-- type: ... -->` and `<!-- status: ... -->`
- Contains `<style id="local-docs-style">` (required for decorate v4.2)
- Contains `<script id="local-docs-script">` (required for TOC / hero / num badge)
- Any missing → failure. Re-copy from `_templates/{type}.html`.

### Polish & Verify
- `/jp-writing`-equivalent self-check on HTML body.
- Run textlint against body text.
- Run `node _index/build.mjs` and confirm exit 0. Non-zero → fix before proceeding.
- Instruct user to open doc in browser and confirm no layout breakage.

## `update {path}` — update existing

Determine mode first: if `--reformat` is explicit, or legacy structure detected (manual toc / tldr / missing `local-docs-decorate` / old inline style), propose reformat. Otherwise use default content-update path.

**Default**: read existing doc; append or rewrite body. Do not touch skeleton/style/script. Polish → verify.

**`--reformat`**: align skeleton h2, `<style>`, `<script>` to latest `_templates/{type}.html`. Remove legacy structure. Preserve body content. Fix metadata (`type` / `status`). Delete `last-updated` if present. Verify.

## Constraints

- **public-repo**: no proprietary names in this skill file. Use local-docs `CLAUDE.md` for proprietary info.
- **No new `.md` files**. All new docs must be `.html` from `_templates/{type}.html`.
- **Do not modify template style/script**. `<style>` and `<script>` blocks are shared infrastructure.
- **No `Write` direct creation**. Always `Bash cp _templates/{type}.html ...` first, then fill with `Edit`.

## Related

- local-docs `CLAUDE.md` — canonical type / aggregation mapping (primary source)
- local-docs `STRUCTURE.md` — placement flow / type enum / Title Rules
- local-docs `_templates/README.html` — template list and usage
