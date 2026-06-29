---
allowed-tools: Bash, Read, Edit
name: local-docs
description: local-docs 配下に HTML doc を作成・更新し、type 別 (postmortem / report / rca 等) の本文品質ルールを適用する。「postmortem」「報告資料」「検証レポート」「RCA」「調査ログ」等で起動する。Use when creating or updating HTML docs in the local-docs knowledge base.
---

# local-docs

Create or update docs in local-docs (AI-assisted local knowledge base).
**Template compliance is required.**
Read the local-docs `CLAUDE.md` and `STRUCTURE.md` as the primary source for canonical types,
aggregation mappings, and placement rules. Do not duplicate type lists in this skill (No Derived Literals).

## Activation criteria

Fire when creating new HTML under local-docs (`projects/` / `domain-specs/` / `tool-guides/` / `operations/`), regardless of whether invoked explicitly. Triggers:

- User utterance includes「local-docs」「ナレッジ」「runbook」「RCA」「postmortem」「報告資料」「検証レポート」「spec」「調査ログ」「監視結果」「post-release」「dashboard 確認」「5xx 分析」「インシデント記録」「試験結果」「session 跨ぎ」「試行錯誤メモ」
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
4. **Load writing guideline (required, before filling)**: 本文を書く前に `guidelines/writing/long-form-doc.md` を 1 本だけ Read する (canonical: `guidelines/writing/README.md`)。これを読まずに本文 prose を書くのは禁止。読みづらい文の主因は「guideline 未読で書き出す」こと。
5. **Fill content (Edit only)**: keep skeleton h2, `<style id="local-docs-style">`, `<script id="local-docs-script">` intact. Replace `{...}` placeholders via `Edit`. Overwriting with `Write` destroys script/style. 本文は **1 文 100 字以内 / 結論先行 / 段落 3-4 行上限 / 指示語禁止 (「これ」「上記」→ 具体名) / NG 語回避** を書き出し時点で守る (後段 retry を減らす)。
6. **Metadata**: fix `<!-- type: ... -->` `<!-- status: ... -->` to canonical values. Do not write `last-updated` (deprecated).
7. **Title**: follow `STRUCTURE.md` Title Rules — short, no repeating parent context.

### Self-check (immediately after generation)
- First 2 lines: `<!-- type: ... -->` and `<!-- status: ... -->`
- Contains `<style id="local-docs-style">` (required for decorate v4.2)
- Contains `<script id="local-docs-script">` (required for TOC / hero / num badge)
- Any missing → failure. Re-copy from `_templates/{type}.html`.

### Polish & Verify (writing quality は必須、skip 禁止)
1. §Type-specific authoring の type 別品質チェックを本文に適用 (時系列粒度 / 影響定量化 / 結論先行 / action 検証可能性)。
2. **`jp-writing` skill を実行**して本文 prose を検査する (`-equivalent` の自己判断で済ませない、skill 本体を起動)。対象は HTML body の本文テキストのみ (h2 骨格 / style / script 除外)。
3. **書き直し loop**: Critical 1 件以上 or Warning 4 件以上で `Edit` 書き直し (最大 2 loop)。3 loop 残存はユーザー報告。合格ライン canonical は `guidelines/writing/long-form-doc.md` §品質検証タイミング。
4. Run textlint against body text。
5. Run `node _index/build.mjs` and confirm exit 0. Non-zero → fix before proceeding。
6. Instruct user to open doc in browser and confirm no layout breakage。

## `update {path}` — update existing

Determine mode first: if `--reformat` is explicit, or legacy structure detected (manual toc / tldr / missing `local-docs-decorate` / old inline style), propose reformat. Otherwise use default content-update path.

**Default**: read existing doc; append or rewrite body. Do not touch skeleton/style/script. 追記 / 書き直しした本文にも §Polish & Verify の writing quality (guideline 適用 + `jp-writing` skill + 書き直し loop) を必ず通す。

**`--reformat`**: align skeleton h2, `<style>`, `<script>` to latest `_templates/{type}.html`. Remove legacy structure. Preserve body content. Fix metadata (`type` / `status`). Delete `last-updated` if present. Verify.

## Type-specific authoring (content quality)

Template が骨格 h2 を与える。各 h2 を**何の粒度で埋めるか**が doc の価値を決める。
type enum / 集約呼称 / h2 の列挙は local-docs `CLAUDE.md` / `_templates/{type}.html` が canonical (No Derived Literals)。ここでは埋め方の質のみ規定する。

共通: 各 doc 冒頭リードは**結論先行**で 1-3 文。読者が「何が起きたか / 何が分かったか」を最初の段落で把握できること。

- **postmortem / rca** (障害系)
  - 時系列は**絶対時刻 (HH:MM) + 主語 + 観測事実**で書く。「しばらくして」「その後」等の相対表現を避ける
  - 影響範囲は**定量化** (影響ユーザ数 / 期間 / 失敗率 / 金額)。「一部に影響」だけで終えない
  - 原因は symptom と root cause を分離する。rca は 5 Why で構造要因まで掘る (`/root-cause` skill 連携)
  - 再発防止は**検証可能な action** (担当 / 期限 / 完了条件) にする。「注意する」「気をつける」は不可
  - `event-date` metadata 必須 (障害発生日)
- **report** (報告 / 検証資料)
  - 結論を §1 か冒頭リードに先出しし、根拠を後続 §で支える (PREP)
  - 数値は必ず**出典 + 計測条件**を添える (clickable link / query / 期間)。`data-window` metadata 必須
  - 解釈 (§4) と事実 (§3) を混ぜない。推測には「推定」「仮説」と明示する
  - 次アクション (§5) は誰が読んで次に何を判断できるかを 1 行で書く
- **plan**: 作業フェーズは依存順 + 完了条件付き。リスクは発生確率と影響、回避策をセットで
- **decision**: 比較軸 (§3) は選択肢間で同一軸。採用 / 不採用は trade-off を明示し「何を捨てたか」を残す

外向き共有用に切り出す前提の doc (postmortem / report) は `guidelines/writing/` canonical の文体規範 (1 文 100 字 / NG 語回避 / 指示語禁止) を本文にも適用する。

## Constraints

- **public-repo**: no proprietary names in this skill file. Use local-docs `CLAUDE.md` for proprietary info.
- **No new `.md` files**. All new docs must be `.html` from `_templates/{type}.html`.
- **Do not modify template style/script**. `<style>` and `<script>` blocks are shared infrastructure.
- **No `Write` direct creation**. Always `Bash cp _templates/{type}.html ...` first, then fill with `Edit`.

## Related

- local-docs `CLAUDE.md` — canonical type / aggregation mapping (primary source)
- local-docs `STRUCTURE.md` — placement flow / type enum / Title Rules
- local-docs `_templates/README.html` — template list and usage
