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

**When creating new HTML under local-docs (`projects/` / `domain-specs/` / `tool-guides/` / `operations/`),
always follow this skill's procedure regardless of whether the command was explicit.**
Applies if any of the following match:

- User utterance includes「local-docs」「ナレッジ」「runbook」「RCA」「postmortem」「spec」「調査ログ」「監視結果」「post-release」「dashboard 確認」「5xx 分析」「インシデント記録」「試験結果」「session 跨ぎ」「試行錯誤メモ」
- Output path is under `local-docs/` (`projects/` / `domain-specs/` / `tool-guides/` / `operations/`)
- Extension is `.html` under any of the above paths

Writing HTML from scratch with `Write` without invoking this skill is a **rule violation**.
Past incident: wrote `<style>` inline without reading `_templates/`,
breaking shared CSS / decorate / `_index/` build entirely.

## Invocation

```
/local-docs new {type} {topic}        # create new
/local-docs update {path}             # update existing doc
/local-docs update {path} --reformat  # reformat to template compliance
```

When subcommand is omitted, infer `new` / `update` from context.

## Prerequisites (read every time)

1. Identify the local-docs repo root (current `cd` target or the repo root derived from the argument path).
2. Read `CLAUDE.md` section "Templates" and `STRUCTURE.md` sections "html format", "type enum", and "placement flow".
3. Obtain canonical types and aggregation mappings from those files — do not substitute cached knowledge from this skill.

## `new {type} {topic}` — create new

### 1. Generate
1. **Type determination**: determine type from topic; normalize variant names to canonical type via `CLAUDE.md` mapping.
2. **Placement determination**: follow `STRUCTURE.md` placement flow to decide the target directory.
3. **Template copy (Bash `cp` required)**: `cp _templates/{type}.html {dir}/{name}.html`.
   **Do not write HTML from scratch with `Write`.** Transcribing or copying the template text is also forbidden
   (prevents style/script drift). Copy with `cp`, then modify only content via `Edit`.
4. **Fill content (Edit only)**: keep the skeleton h2, `<style id="local-docs-style">`,
   and `<script id="local-docs-script">` intact. Replace `{...}` placeholders via `Edit` and append body
   with `Edit`. Overwriting with `Write` destroys script/style. Keep skeleton h2 (additional doc-specific h2 is allowed).
5. **Metadata**: fix the leading comment `<!-- type: ... -->` `<!-- status: ... -->` to canonical values. Do not write `last-updated` (deprecated).
6. **Title**: follow `STRUCTURE.md` Title Rules — keep short, avoid repeating parent context.

### 1.5. Self-check (run immediately after generation)
- First 2 lines contain `<!-- type: ... -->` and `<!-- status: ... -->`
- Contains `<style id="local-docs-style">` (required for decorate v4.2)
- Contains `<script id="local-docs-script">` (required for TOC / hero / num badge auto-generation)
- If any of the above is missing → failure. Re-copy from `_templates/{type}.html`.

### 2. Polish
Run a `/jp-writing`-equivalent self-check on the HTML body. Remove AI-like phrasing and verbose expressions. Improve Japanese readability of the HTML body.

### 3. Verify
- Run textlint against the body text (extract body first if HTML pre-processing is needed).
- Run `node _index/build.mjs` and confirm exit 0. A non-zero exit means the index is broken; fix before proceeding.
- Instruct the user to open the doc in a browser and confirm no style or layout breakage.

## `update {path}` — update existing

Determine the mode before starting: if `--reformat` is explicit, or if a legacy structure is detected (manual toc / tldr section / missing `local-docs-decorate` / old inline style), propose reformat to the user. Otherwise use the default content-update path.

### Default: content update
1. Read the existing doc; append or rewrite body content.
2. Do not touch skeleton / style / script (preserve template compliance if intact).
3. Polish → verify (same as above).

### `--reformat`: template compliance
1. Determine doc type (from leading metadata or content). Normalize variants to canonical type.
2. Align skeleton h2, `<style>`, and `<script>` (decorate v4.1) to the latest `_templates/{type}.html`.
3. Remove legacy structure (manual toc / tldr / old style). **Preserve body content.**
4. Fix metadata to required set (`type` / `status`). Delete `last-updated` if present.
5. Verify (same as above).

## Constraints

- **public-repo**: this skill is publicly managed. Do not embed proprietary names (internal service names /
  identifiers) in this skill file itself. Reference proprietary information via local-docs `CLAUDE.md` instead.
- **No new `.md` files**. All new docs must be `.html` derived from `_templates/{type}.html`.
  Leave existing root meta 5 files and existing `.md` files untouched.
- **Do not modify template style / script**. The `<style>` and `<script>` blocks in templates are
  shared infrastructure; only fill the doc body.
- **No `Write` direct creation (new `.html` under local-docs)**. Always run
  `Bash cp _templates/{type}.html ...` first, then fill body with `Edit`.
  Writing new `.html` from scratch with `Write` breaks shared CSS, decorate,
  and `_index/` build pipeline (confirmed past damage).

## Related

- local-docs `CLAUDE.md` — canonical type / aggregation mapping (primary source)
- local-docs `STRUCTURE.md` — placement flow / type enum / Title Rules
- local-docs `_templates/README.html` — template list and usage
